# Kong

This example shows how to deploy kong konnect on Amazon EKS and mounts private certificates managed by  AWS 
ACM Certificate Manager.

* Creates a new sample VPC, 3 Private Subnets and 3 Public Subnets
* EKS Cluster
* Enables external-secrets module
* Enables cert-manager module
* Enables cert-manager CSI driver module
* Enables aws-privateca-issuer module
* Creates AWS Certificate Manager Private Certificate Authority, enables and activates it
* Creates the CRDs to fetch tls.crt, tls.key, which will be available as Kubernetes Secret. 
* Creates a namespace , service account , IRSA for Kong  
* Create SecretStore and ExternalSecret to fetch the AWS Secrets Manager secret as kubernetes Secrets
* Deploys Kong helm chart 


## How to Deploy

### Prerequisites:

Kong data plane connects with Konnect control plane using mTLS. **kong-konnect-runtime-cert-generator** utility makes Kong Konnect API calls to
See if the runtime group that you provided as input exists or not. If it does not, then creates one
Generates self signed certificate and pins it down with the specific runtime group
Makes AWS API calls to store the certificate and key in AWS Secrets Manager that you can further mount to your Kubernetes pods or ECS environment variable


* To install the tool
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

* Update the terraform.auto.tfvars file
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