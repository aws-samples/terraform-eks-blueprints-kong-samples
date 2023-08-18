output "vpc_id" {
  value =  module.vpc.vpc_id
}

output "private_subnets" {
  value =  module.vpc.private_subnets
}

output "key_arn" {
  value =  module.kms.key_arn
}

output "tags" {
  value =  local.tags
}

output "region" {
  value =  local.region
}