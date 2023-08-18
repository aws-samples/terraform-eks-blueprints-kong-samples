output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${module.common.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "nlb_endpoint" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and update your kubeconfig.Run the following command to get the NLB Endpoint"
  value       = "kubectl get svc -n ${module.eks_blueprints_kubernetes_addon_kong.namespace} | awk '{print $4}' | grep -i aws"
}