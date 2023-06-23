################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                   = local.name
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  eks_managed_node_groups = {
    initial = {
      instance_types = ["c7g.large"]
      ami_type     = "AL2_ARM_64"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  tags = local.tags
}


module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "1.0.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # EKS Add-on
  eks_addons = {
    coredns    = {}
    vpc-cni    = {}
    kube-proxy = {}
  }

  # Add-ons 
  
  enable_external_secrets = true
    
  depends_on = [ 
    module.eks
   ]
}

################################################################################
# Kong Add-on
################################################################################


module "eks_blueprints_kubernetes_addon_kong" {

  source = "git@ssh.gitlab.aws.dev:anshrma/temporary-kong-terraform-blueprint.git?ref=v5"
  
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_kong_konnect = true
  tags = local.tags

  kong_config = {
    cluster_dns      = var.cluster_dns
    telemetry_dns    = var.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values = [templatefile("${path.module}/kong_values.yaml", {})] 
  }
  depends_on = [
    module.eks_blueprints_addons
  ]
}


################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0"

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

  tags = local.tags
}
