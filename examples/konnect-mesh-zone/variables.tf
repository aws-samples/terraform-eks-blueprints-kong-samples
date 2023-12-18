#mandatory Variables Needed to run the script
variable "konnect_region" {
  type        = string
  description = "Value of apiHostname after kong script is run"

  validation {
    condition     = contains(["us", "eu"], var.konnect_region)
    error_message = "Valid values for Konnect Region are: (us, eu)"
  }
}

variable "konnect_region" {
  type        = string
  description = "Value of apiHostname after kong script is run"

  validation {
    condition     = contains(["us", "eu"], var.konnect_region)
    error_message = "Valid values for Konnect Region are: (us, eu)"
  }
}

variable "konnect_mesh_global_cp_id" {
  type        = string
  description = "The Konnect Mesh Global Control Plane ID"
}

variable "zone_name" {
  type        = string
  description = "The name of the mesh zone to be provisioned"
}

variable "cp_token_aws_secret_name" {
  type        = string
  description = "name of the CP Token in AWS Secrets Manager"
}
