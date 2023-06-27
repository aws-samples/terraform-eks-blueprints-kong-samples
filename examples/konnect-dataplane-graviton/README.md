# Kong

This example shows how to deploy kong konnect on Amazon EKS

* Creates a new sample VPC, 3 Private Subnets and 3 Public Subnets
* Amazon EKS Cluster and Amazon EKS managed node groups
* Enables external-secrets module
* Creates a namespace , service account with appropriate IRSA roles 
* Create SecretStore and ExternalSecret to fetch the AWS Secrets Manager secret as kubernetes Secrets
* Deploys Kong helm chart



## How to Deploy

### Prerequisites:

Kong data plane connects with Konnect control plane using mTLS. **kong-konnect-runtime-cert-generator** utility makes Kong Konnect API calls to see if the runtime group that you provided as input exists or not. If it does not, then it creates one, generates self signed certificate and pins it down with the specific runtime group, makes AWS API calls to store the certificate and key in AWS Secrets Manager that you can further mount to your Kubernetes pods or ECS environment variable.


* To install the utility
```
curl -L https://github.com/anshrma/kong-konnect-runtime-cert-generator/releases/download/v0.1.3/kong-konnect-runtime-cert-generator_Darwin_arm64.tar.gz —output kong-konnect-runtime-cert-generator.tgz
tar xvf kong-konnect-runtime-cert-generator.tgz
```

* Run the kong-konnect-runtime-cert-generator utility with the below inputs 
  * Runtime group name : The runtime group name
  * Pat token: The personal access token created in step 2
  * Api-endpoint: The endpoint to connect to Kong Konnect control plane
```
./kong-konnect-runtime-cert-generator -api-endpoint "https://us.api.konghq.com" -api-version "v2" -personal-access-token "<PAT>" -runtime-group-name "default"
```

* Update the terraform.auto.tfvars file with values obtained from previous step.
  * cert_secret_name = "CHANGEME-SHA-crt"
  * key_secret_name  = "CHANGEME-SHA-key"
  * clusterDns       = "CHANGEME.us.cp0.konghq.com"
  * telemetryDns     = "CHANGEME.us.tp0.konghq.com"

### Deploy

* terraform init
* terraform plan 
* terraform apply 

### Validate

Validate the deployment.
```
kubectl get all -n kong 
```

### What gets deployed in this example ?

* VPC (4 subnet, 2 public and 2 private)
* EKS Cluster
* NLB
* Managed Nodes on AL2 (Graviton)
* External Secrets Manager Operator and related configurations to use AWS Secrets Manager (used to fetch certs and keys from AWS Secrets Manager)
* Kong Data plane