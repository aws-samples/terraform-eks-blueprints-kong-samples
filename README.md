# Terraform EKS Blueprint Examples for Kong AddOn 

## Examples

[Konnect with graviton](./examples/konnect-dataplane-graviton)

[Konnect with pca](./examples/konnect-with-pca)

[Konnect with fargate](./examples/konnect-fargate)

[Konnect with Kong Ingress Controller](./examples/konnect-kic)

## High Level Overview

![](./images/Kong-EKS-Terraform-Blueprints.png)

## Checkov

```
terraform plan -out tf.plan && terraform show -json tf.plan | jq '.' > tf.json && checkov -f tf.json
```