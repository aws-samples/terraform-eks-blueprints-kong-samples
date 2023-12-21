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

variable "konnect_region" {
  type        = string
  description = "Value of apiHostname after kong script is run"

  validation {
    condition     = contains(["us", "eu"], var.konnect_region)
    error_message = "Valid values for Konnect Region are: (us, eu)"
  }
}

variable "runtimeGroupID" {
  type        = string
  description = "Value of runtimeGroupID after kong script is run"
}

variable "personal_access_token" {
  type        = string
  description = "Value of the personal or system access token to Konnect"
  sensitive   = true
}