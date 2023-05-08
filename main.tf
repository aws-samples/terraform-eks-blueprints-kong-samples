#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints"
  # source = "../../../terraform-aws-eks-blueprints"

  cluster_name    = local.name
  cluster_version = "1.23"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      min_size        = 1
      desired_size    = 1
      subnet_ids      = module.vpc.private_subnets
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {

  source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"
  # source = "../../../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  #K8s Add-ons

  enable_external_secrets = true
  tags = local.tags

}


#--------------------------------------------------------------
# Additional IAM Policy for Kong
#--------------------------------------------------------------
resource "aws_iam_policy" "kong_additional_policy" {
  name_prefix = "kong_additional_policy"
  policy      = data.aws_iam_policy_document.additional_kong_iam_policy_document.json
}

#Module for Kong
module "eks_blueprints_kubernetes_addons_kong" {

  # source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"
  source = "../terraform-eksblueprints-kong-addon"
  # source = "https://gitlab.aws.dev/terraform-eksblueprints-kong-addon/terraform-eksblueprints-kong-addon/-/tree/test-independent-module"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  tags = local.tags


  irsa_policies = [aws_iam_policy.kong_additional_policy.arn]
  helm_config = {
    version          = "2.16.5"
    namespace        = "kong"
    service_account  = "kong-sa"
    cluster_dns      = var.cluster_dns
    telemetry_dns    = var.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values = [templatefile("${path.module}/kong_values.yaml", {})]
  }
  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}



#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}
