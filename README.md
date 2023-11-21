# kong-konnect-runtime-cert-generator

This command line interface is a high level abstraction to provide composite commands to take two or more Konnect API actions in one command, focussed from a usability standpoint.

## What is

* This utility makes Kong Konnect API calls to
  * See if the runtime group that you provided as input exists or not. If it does not, then creates one
  * Generates self signed certificate and pins it down with the specific runtime group
 * Makes AWS API calls to store the certificate and key in AWS Secrets Manager that you can futher mount to your kubernetes pods or ECS environment variable


## Usage Instructions
* Download the necessary executable based on your execution environment
* Authenticate against AWS by either setting environment variables or STS or any of your [preferred mechanism](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
* Run `./kong-konnect-runtime-cert-generator --help` for usage


## Release

* Set following

export GITHUB_TOKEN="YOUR_GH_TOKEN"

* Create a tag and push it to GitHub
  * git tag -a vMAJOR.MINOR.PATCH -m "Message for MAJOR.MINOR.PATCH"
  * git push origin --tags
* Run `goreleaser release --clean`
