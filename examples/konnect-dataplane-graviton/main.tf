

module "common" {
  source = "../common/"
}

provider "aws" {
  region  = module.common.region
}

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name                   = basename(path.cwd)
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true
  cloudwatch_log_group_retention_in_days = 365
  //CKV_AWS_37
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id     = module.common.vpc_id
  subnet_ids = module.common.private_subnets
  kms_key_enable_default_policy = true
  cloudwatch_log_group_kms_key_id = module.common.key_arn

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

  tags = module.common.tags
  # depends_on = [
  #   module.common
  # ]
}


################################################################################
# Kong Add-on
################################################################################


module "eks_blueprints_kubernetes_addon_kong" {
  count   = 1
  source = "Kong/eks-blueprint-konnect-runtime-instance/aws"
  version = "1.1.0"
  # source    = "../../../terraform-aws-eks-blueprint-konnect-runtime-instance"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = module.common.tags

  kong_config = {
    cluster_dns      = var.cluster_dns
    telemetry_dns    = var.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values = [templatefile("${path.module}/kong_values.yaml", {})]

    add_ons = {
      enable_external_secrets = true
    }
  }
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
}

