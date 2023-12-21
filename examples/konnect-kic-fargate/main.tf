module "common" {
  source = "../common/"
}

provider "aws" {
  region  = module.common.region
}

################################################################################
# Cluster
################################################################################

# #tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

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

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    kube_system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
    }
    external-secrets = {
      name = "external-secrets"
      selectors = [
        { namespace = "external-secrets" }
      ]
    }
    kong = {
      name = "kong"
      selectors = [
        { namespace = "kong" }
      ]
    }
  }

  tags = module.common.tags
}


###################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.0.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn


  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]

  # EKS Add-ons
  eks_addons = {
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    vpc-cni    = {}
    kube-proxy = {}
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = module.common.vpc_id
      },
      {
        name  = "podDisruptionBudget.maxUnavailable"
        value = 1
      },
    ]
  }

  tags = module.common.tags
}

################################################################################
# Kong Add-on
################################################################################


module "eks_blueprints_kubernetes_addon_kong" {

  source = "Kong/eks-blueprint-konnect-kic/aws"
  version = "1.1.0"



  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = module.common.tags

  kong_config = {
    runtimeGroupID   = var.runtimeGroupID
    apiHostname      = local.kic_apiHostname
    telemetry_dns    = local.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values           = [templatefile("${path.module}/kong_values.yaml", {})]

    add_ons = {
      enable_external_secrets = true
    }
  }
  depends_on = [
    module.eks_blueprints_addons.aws_load_balancer_controller
  ]
}


