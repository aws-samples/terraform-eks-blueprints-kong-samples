output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${module.common.region} update-kubeconfig --name ${module.eks.cluster_name}"
}