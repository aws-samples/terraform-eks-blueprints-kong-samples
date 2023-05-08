# Terraform EKS Blueprint for Kong AddOn

## Pre-Requisites

* Sign up for [Kong Konnect](https://cloud.konghq.com/register) if not already and generate your personal access token. 
* Download the certificate generator from `https://github.com/anshrma/kong-konnect-runtime-cert-generator/releases`
* Authenticate against AWS by either setting environment variables or STS or any of your [preferred mechanism](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html). Ensure to set the `AWS_DEFAULT_REGION` as well.

## Execute

* Run `./kong-konnect-runtime-cert-generator --help` for usage and follow instructions
* Save the output to `terraform.auto.tfvars`
* Optionally fill in `kong_values.yaml` with any additional helm values that you may want for the kong's helm chart.