################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                   = local.name
  cluster_version                = "1.26"
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

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
    
  enable_cert_manager         = true
  enable_aws_privateca_issuer = true
  aws_privateca_issuer = {
    acmca_arn        = aws_acmpca_certificate_authority.this.arn
    namespace        = "aws-privateca-issuer"
    create_namespace = true
  }

  helm_releases = {
    cert-manager-csi-driver = {
      description   = "Cert Manager CSI Driver Add-on"
      chart         = "cert-manager-csi-driver"
      namespace     = "cert-manager"
      create_namespace = true
      chart_version = "v0.5.0"
      repository    = "https://charts.jetstack.io"
    }
  }

  depends_on = [ 
    module.eks
   ]
}

#-------------------------------
# Associates a certificate with an AWS Certificate Manager Private Certificate Authority (ACM PCA Certificate Authority).
# An ACM PCA Certificate Authority is unable to issue certificates until it has a certificate associated with it.
# A root level ACM PCA Certificate Authority is able to self-sign its own root certificate.
#-------------------------------

resource "aws_acmpca_certificate_authority" "this" {
  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name = var.certificate_dns
    }
  }

  tags = local.tags
}

resource "aws_acmpca_certificate" "this" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.this.arn
  certificate_signing_request = aws_acmpca_certificate_authority.this.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

resource "aws_acmpca_certificate_authority_certificate" "this" {
  certificate_authority_arn = aws_acmpca_certificate_authority.this.arn

  certificate       = aws_acmpca_certificate.this.certificate
  certificate_chain = aws_acmpca_certificate.this.certificate_chain
}

#-------------------------------
#  This resource creates a CRD of AWSPCAClusterIssuer Kind, which then represents the ACM PCA in K8
#-------------------------------

# Using kubectl to workaround kubernetes provider issue https://github.com/hashicorp/terraform-provider-kubernetes/issues/1453
resource "kubectl_manifest" "cluster_pca_issuer" {
  yaml_body = yamlencode({
    apiVersion = "awspca.cert-manager.io/v1beta1"
    kind       = "AWSPCAClusterIssuer"

    metadata = {
      name = module.eks.cluster_name
    }

    spec = {
      arn = aws_acmpca_certificate_authority.this.arn
      region : local.region
    }
  })

  depends_on = [
    module.eks_blueprints_addons
  ]
}

#-------------------------------
# This resource creates a CRD of Certificate Kind, which then represents certificate issued from ACM PCA,
# mounted as K8 secret
#-------------------------------

# Using kubectl to workaround kubernetes provider issue https://github.com/hashicorp/terraform-provider-kubernetes/issues/1453
resource "kubectl_manifest" "pca_certificate" {
  count = var.enable_kong_konnect ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"

    metadata = {
      name      = var.certificate_name
      namespace = module.eks_blueprints_kubernetes_addon_kong.namespace
    }

    spec = {
      commonName = var.certificate_dns
      duration   = "2160h0m0s"
      issuerRef = {
        group = "awspca.cert-manager.io"
        kind  = "AWSPCAClusterIssuer"
        name : module.eks.cluster_name
      }
      renewBefore = "360h0m0s"
      secretName  = local.pca_cert_secretname # This is the name with which the K8 Secret will be available
      usages = [
        "server auth",
        "client auth"
      ]
      privateKey = {
        algorithm : "RSA"
        size : 2048
      }
    }
  })

  depends_on = [
    kubectl_manifest.cluster_pca_issuer,
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
    values = [templatefile("${path.module}/kong_values.yaml", {
      pca_cert_secretname = local.pca_cert_secretname
    })]
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
