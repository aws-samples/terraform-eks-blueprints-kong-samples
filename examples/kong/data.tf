data "aws_availability_zones" "available" {}




###############Additional Policy############


data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "additional_kong_iam_policy_document" {
  statement {
    effect = "Allow"
    resources = ["arn:aws:lambda:${local.region}:${data.aws_caller_identity.current.account_id}:function:hello-world"]
    actions = [
      "lambda:InvokeFunction",
    ]
  }

}

# --------------------------------------------------------------
# Additional IAM Policy for Kong
# --------------------------------------------------------------
resource "aws_iam_policy" "kong_additional_policy" {
  name_prefix = "kong_additional_policy"
  policy      = data.aws_iam_policy_document.additional_kong_iam_policy_document.json
}
