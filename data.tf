data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_eks_cluster" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

#--------------------------------------------------------------
# Additional IAM Policy
#--------------------------------------------------------------

data "aws_iam_policy_document" "additional_kong_iam_policy_document" {
  statement {
    effect = "Allow"
    resources = ["arn:aws:lambda:${local.region}:${data.aws_caller_identity.current.account_id}:function:hello-world"]
    actions = [
      "lambda:InvokeFunction",
    ]
  }

}
