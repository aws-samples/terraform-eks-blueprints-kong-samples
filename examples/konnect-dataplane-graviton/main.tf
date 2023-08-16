
################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  enable_flow_log = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role = true
  flow_log_cloudwatch_log_group_retention_in_days = 365

  # default_security_group_ingress = []
  # default_security_group_egress = []
  tags = local.tags
}

# resource "aws_flow_log" "s3_flow_log" {
#   log_destination      = aws_s3_bucket.vpc_flow_logs.arn
#   log_destination_type = "s3"
#   traffic_type         = "ALL"
#   vpc_id               = module.vpc.vpc_id
#   destination_options {
#     file_format        = "parquet"
#     per_hour_partition = true
#   }
# }

# resource "aws_s3_bucket" "vpc_flow_logs" {
#   bucket = "${module.vpc.vpc_id}-vpc-flow-logs"
# }

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name                   = local.name
  cluster_version                = "1.27"
  #checkov:skip=CKV_AWS_39:This solution will not work if the developer machine is not within VPC
  cluster_endpoint_public_access = true
  //CKV_AWS_338
  cloudwatch_log_group_retention_in_days = 365
  //CKV_AWS_37
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  eks_managed_node_groups = {
    initial = {
      instance_types = ["c7g.large"]
      ami_type     = "AL2_ARM_64"
      min_size     = 1
      max_size     = 1
      desired_size = 1
      //CKV_AWS_341: "Ensure Launch template should not have a metadata response hop limit greater than 1"
      metadata_options = {
          http_put_response_hop_limit = 1
          http_tokens                 = "required"
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.tags
  # depends_on = [
  #   module.vpc
  # ]
}


################################################################################
# Kong Add-on
################################################################################


module "eks_blueprints_kubernetes_addon_kong" {
  count   = 1
  source = "Kong/eks-blueprint-konnect-runtime-instance/aws"
  version = "1.0.0"
  # source    = "../../../terraform-aws-eks-blueprint-konnect-runtime-instance"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = local.tags

  kong_config = {
    cluster_dns      = var.cluster_dns
    telemetry_dns    = var.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values = [templatefile("${path.module}/kong_values.yaml", {})] 
  }
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
}

