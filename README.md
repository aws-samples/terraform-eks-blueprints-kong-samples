# Terraform EKS Blueprint for Kong AddOn

## Pre-Requisites

* Sign up for [Kong Konnect](https://cloud.konghq.com/register) if not already. 
* Download the shell script 

```
curl -o https://raw.githubusercontent.com/aws-samples/sample-kong-gateway/main/konnect-secrets-manager.sh
```

* Execute

```
./konnect-secrets-manager.sh -v -api https://cloud.konghq.com -u '<KONNECT_USERNAME>' -p '<KONNECT_PASSWORD>' -c '<KONNECT_RUNTIME_SHA>'
```

* Save the output to `terraform.auto.tfvars`
* Optionally fill in `kong_values.yaml` with any additional helm values that you may want for the kong's helm chart.