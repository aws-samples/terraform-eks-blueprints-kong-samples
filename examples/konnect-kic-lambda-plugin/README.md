# Kong Konnect - Kong Ingress Controller (KIC)

This example shows how to deploy Kong Konnect Kong Ingress Controller and Kong Gateway on Amazon EKS

* Creates a new sample VPC, 3 Private Subnets and 3 Public Subnets
* Amazon EKS Cluster and Amazon EKS managed node groups
* Deploys Kong EKS Blueprints AddOn.
* Creates a sample AWS Lambda function
* Deploys [AWS Lambda Plugin]() for Kong and associates it with `/hello` route

The Kong Konnect KIC EKS Blueprint Addon will configure the following on  AWS EKS:
* Create the namespace
* External Secrets Manager Operator via EKS Blueprint Addon framework and related configurations to use AWS Secrets Manager
* Kong Konnect KIC and Kong Gateway dataplanes via the EKS Blueprint Addon framework


## How to Deploy

### Prerequisites:

1) Install Terraform. For more details see the [Terraform Installation doc](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
2) Install AWS CLI . For more details see the [AWS Cli installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) Authenticate against AWS by either setting environment variables or STS or any of your preferred mechanism
3) You will need a Konnect subscription. You can [sign up](https://konghq.com/products/kong-konnect/register?utm_medium=partner&utm_source=aws&utm_campaign=aws-devops-workshop-webinar) for a 14-day free trial of Konnect Plus subscription. After 14 days, you can choose to downgrade to the free version, or continue with a paid Plus subscription. Also, post signing up for Kong Konnect, generate a personal access token (PAT) for a user account in Konnect by selecting your user icon to open the context menu and clicking Personal access tokens, then clicking Generate token.

### Deployment Steps

1) The KIC dataplanes connects with Konnect control plane using mTLS. The **kong-konnect** CLI makes Kong Konnect API calls to see if the runtime group that you provided as input exists or not. If it does not, then it creates one, generates self signed certificate and pins it down with the specific runtime group, makes AWS API calls to store the certificate and key in AWS Secrets Manager that you can further mount to your Kubernetes pods or ECS environment variable.

***Note: The `kong-konnect` utility is used to get started quickly. For production-ready scenarios, it is recommended to push a production-ready certificate to Konnect.***

To install the tool


```
curl -LJO https://github.com/aws-samples/kong-konnect-runtime-cert-generator/releases/download/v0.1.11/kong-konnect-runtime-cert-generator_Darwin_x86_64.tar.gz
tar xvf kong-konnect-runtime-cert-generator_Darwin_x86_64.tar.gz
mv kong-konnect-runtime-cert-generator kong-konnect
```


**Note** : Choose the asset from the list to download, depending on the operating system from where you are executing the above command.

2) Create self signed certificates, pin the public key against the specific runtime group or the newly created runtime group and upsert the certificate and private key in AWS Secrets manager as two separate secrets.

```
./kong-konnect gateway-manager upsert-control-plane --cluster-type="CLUSTER_TYPE_K8S_INGRESS_CONTROLLER" --name="<REPLACE-ME>" --personal-access-token="<REPLACE-ME>"
```

Output will be similar to following. Your specific outputs will differ.

```
Runtime Group ID:  e9205a44-01f4-46b7-b2f4-5c34679c2cc1
{
    "cluster_dns": "https://6fae8e8f10.us.cp0.konghq.com",
    "telemetry_dns": "https://6fae8e8f10.us.tp0.konghq.com",
    "runtime_name": "default",
    "cert_secret_name": "e9205a44-01f4-46b7-b2f4-5c34679c2cc1-cert",
    "key_secret_name": "e9205a44-01f4-46b7-b2f4-5c34679c2cc1-key",
    "personal_access_token": "e9205a44-01f4-46b7-b2f4-5c34679c2cc1-pat-token"
}
```

3) In `/examples/konnect-kic-lambda-plugin` folder create terraform.tfvars and note the output from step(2) above in this file. Save the file.

```
cert_secret_name  = "REPLACE ME - Corresponds to Secrets Manager Name with certificate from step(2)"
key_secret_name   = "REPLACE ME - Corresponds to Secrets Manager Name with private key from step(2)"
konnect_region    = "REPLACE ME - Equate it to `us` or `eu` as appropriate for your Konnect region"
runtimeGroupID    = "REPLACE ME - Correponds to the Runtime Group ID"
personal_access_token = "REPLACE ME - Corresponds to your personal access token from the pre-requisite (3)"
```

4) Next , initiate Terraform, Plan and Apply

```
terraform init
terraform plan
terraform apply
```

Enter yes to apply. It may take 10-15 minutes for setup to be provisioned, after which you’ll be presented with the Kubectl command to access the cluster.

5) Finally, validate the deployment

Execute following

```
kubectl get all -n kong 
```

In few minutes, you should now notice Kong pods to be in `Running` status. At this point, if you login to cloud.konghq.com you should see the data-plane instances connected under the specified runtime group.

View the Network Load Balancer created by running

```
kubectl get svc -n kong
```

Now, you can curl (or in browser) open `/hello` route created in this sample to see the response from AWS Lambda


