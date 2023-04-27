#mandatory Variables Needed to run the script
variable "cluster_dns" {
  type        = string
  description = "Value of cluster_dns after kong script is run"
}

variable "telemetry_dns" {
  type        = string
  description = "Value of telemetry_dns after kong script is run"
}

variable "cert_secret_name" {
  type        = string
  description = "Value of cert_secret_name after kong script is run"
}

variable "key_secret_name" {
  type        = string
  description = "Value of key_secret_name after kong script is run"
}