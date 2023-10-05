# Kong Konnect - Kong Ingress Controller (KIC)

This example shows how to deploy Kong Konnect Kong Ingress Controller and Kong Gateway on Amazon EKS

* Creates a new sample VPC, 3 Private Subnets and 3 Public Subnets
* Amazon EKS Cluster and Amazon EKS managed node groups
* Deploys Kong EKS Blueprints AddOn.

The Kong Konnect KIC EKS Blueprint Addon will configure the following on  AWS EKS:
* Create the namespace
* External Secrets Manager Operator via EKS Blueprint Addon framework and related configurations to use AWS Secrets Manager
* Kong Konnect KIC and Kong Gateway dataplanes via the EKS Blueprint Addon framework

## How to Deploy

### Prerequisites:

The KIC dataplanes connects with Konnect controlplane using mTLS.

The **kong-konnect-runtime-cert-generator** utility makes Kong Konnect API calls to see if the runtime group that you provided as input exists or not. If it does not, then it creates one, generates self signed certificate and pins it down with the specific runtime group, makes AWS API calls to store the certificate and key in AWS Secrets Manager that you can further mount to your Kubernetes pods or ECS environment variable.

***Note: The `cert-generator` utility is used to get started quickly. For production-ready scenarios, it is recommended to push a production-ready certificate to Konnect.***

* To install the utility

```console
curl -L https://github.com/anshrma/kong-konnect-runtime-cert-generator/releases/download/v0.1.3/kong-konnect-runtime-cert-generator_Darwin_arm64.tar.gz —output kong-konnect-runtime-cert-generator.tgz
tar xvf kong-konnect-runtime-cert-generator.tgz
```

* Run the kong-konnect-runtime-cert-generator utility with the below inputs:
  * Runtime group name : The runtime group name
  * PAT token: The personal access token created in step 2
  * API-endpoint: The endpoint to connect to Kong Konnect control plane

```console
./kong-konnect-runtime-cert-generator -api-endpoint "https://us.api.konghq.com" -api-version "v2" -personal-access-token "<PAT>" -runtime-group-name "KIC"
```

* Update the terraform.auto.tfvars file with values obtained from previous step.
  * cert_secret_name = "CHANGEME-SHA-crt"
  * key_secret_name  = "CHANGEME-SHA-key"
  * konnect_region = "FILLMEIN"
  * runtimeGroupID = "FILLMEIN"
  * personal_access_token = "FILLMEIN"

### Deploy

```console
terraform init
terraform plan
terraform apply
```

### Validate

Validate the deployment:

```console
kubectl get all -n kong
```

### What gets deployed in this example ?

* VPC (4 subnet, 2 public and 2 private)
* EKS Cluster
* External Secrets Manager Operator and related configurations to use AWS Secrets Manager (used to fetch certs and keys from AWS Secrets Manager)
* Kong Konnect KIC Dataplane
* Kong Konnect Gateway Dataplane