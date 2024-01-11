module "common" {
  source = "../common/"
}

provider "aws" {
  region = module.common.region
}

################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  #version = "~> 19.15"

  cluster_name                           = "konnect-alb-demo"
  cluster_version                        = "1.28"
  cluster_endpoint_public_access         = true
  cloudwatch_log_group_retention_in_days = 365
  //CKV_AWS_37
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id                          = module.common.vpc_id
  subnet_ids                      = module.common.private_subnets
  kms_key_enable_default_policy   = true
  cloudwatch_log_group_kms_key_id = module.common.key_arn


  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 2
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
}


################################################################################
# Kong Add-on
################################################################################


module "eks_blueprints_kubernetes_addon_kong" {

  count = 1
  source  = "Kong/eks-blueprint-konnect-kic/aws"
  #version = "~> 1.1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = module.common.tags

  kong_config = {
    # chart_version    = "0.3.0"
    namespace        = local.kong_namespace
    runtimeGroupID   = var.runtimeGroupID
    apiHostname      = local.kic_apiHostname
    telemetry_dns    = local.telemetry_dns
    cert_secret_name = var.cert_secret_name
    key_secret_name  = var.key_secret_name
    values = [templatefile("${path.module}/kong_values.yaml", {
      role_arn = module.iam_assumable_role_admin.iam_role_arn
      sa_name = local.kong_pod_service_account_name
    })]

    add_ons = {
      enable_external_secrets = true
    }
  }

}

################################################################################
# IAM Role for Service Account to be assumed by Kong's Pod
################################################################################
module "iam_assumable_role_admin" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  #version                       = "3.6.0"
  create_role                   = true
  role_name                     = "kong-pod-role"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.kong_pod_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.kong_namespace}:${local.kong_pod_service_account_name}"]
}

resource "aws_iam_policy" "kong_pod_policy" {
  name_prefix = "kong-pod"
  description = "Kong Pod Identity for cluster ${module.eks.cluster_name}"
  policy      = data.aws_iam_policy_document.kong_pod_policy_document.json
}

data "aws_iam_policy_document" "kong_pod_policy_document" {
  statement {
    sid    = "KongPodPolicy"
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [resource.aws_lambda_function.konnect_plugin_demo_lambda.arn]
  }
}


################################################################################
# Kubernetes Service Account for Kong Pod - Not required here as its moved to Kong module values
################################################################################

# resource "kubernetes_service_account" "kong_pod_service_account" {
#   metadata {
#     name      = local.kong_pod_service_account_name
#     namespace = module.eks_blueprints_kubernetes_addon_kong.namespace
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.iam_assumable_role_admin.iam_role_arn
#     }
#   }
# }

################################################################################
# Sample Lambda Hello World function in nodejs
################################################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }

}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "konnect-plugin-demo-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {

  type        = "zip"
  output_path = "${path.root}/.archive_files/lambda_function_payload.zip"

  # fingerprinter
  source {
    filename = "index.js"
    content  = <<CODE
      exports.handler=async t=>{let e={statusCode:200,body:JSON.stringify("Hello from Lambda!")};return e};
      CODE
  }

}

resource "aws_lambda_function" "konnect_plugin_demo_lambda" {

  filename         = "${path.root}/.archive_files/lambda_function_payload.zip"
  function_name    = "konnect-plugin-demo-lambda"
  description      = "Hello World Lambda Function"
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"
  role    = aws_iam_role.iam_for_lambda.arn

}

###############################################################################
#CRD to create Kong Lambda Plugin
###############################################################################
resource "kubernetes_manifest" "kong_lambda_plugin" {
  depends_on = [ module.eks_blueprints_kubernetes_addon_kong,module.eks ]
  manifest = {
    "apiVersion" = "configuration.konghq.com/v1"
    "kind"       = "KongPlugin"
    "metadata" = {
      "name"      = "konnect-plugin-demo-lambda"
      "namespace" = local.kong_namespace
    }
    "plugin" = "aws-lambda"
    "config" = {
      "function_name" = resource.aws_lambda_function.konnect_plugin_demo_lambda.function_name
      "forward_request_method" = true
      "forward_request_uri" = true
      "forward_request_body" = true
      "forward_request_headers" = true
    }
  }
}

###############################################################################
#Associate Ingress with the lambda plugin
###############################################################################
resource "kubernetes_manifest" "kong_ingress" {
  depends_on = [ module.eks_blueprints_kubernetes_addon_kong , module.eks]
  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind"       = "Ingress"
    "metadata" = {
      "name"      = "konnect-plugin-demo-lambda"
      "namespace" = local.kong_namespace
      "annotations" = {
        "konghq.com/plugins" = "konnect-plugin-demo-lambda"
        "konghq.com/strip-path": true
      }
    }


    "spec" = {
      "ingressClassName" = "kong"
      "rules" = [
        {
          "http" = {
            "paths" = [
              {
                "path" = "/hello"
                "pathType": "ImplementationSpecific"
                #Backend is Dummy implementation as Lambda plugin is associated.
                "backend" = {
                  "service" = {
                    "name" = "dummy",
                    "port" = {
                      "number" = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

}