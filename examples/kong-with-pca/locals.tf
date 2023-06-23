locals {
  name   = basename(path.cwd)
  region = "us-west-2"
  kong_namespace = "kong-ns"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  acm_pca_cert_secretname = join("-", [var.certificate_name, "clusterissuer"])

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints-addons"
  }
}

