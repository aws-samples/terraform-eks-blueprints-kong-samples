data "aws_availability_zones" "available" {}

data "http" "konnect_runtime_group_api" {
  url = "https://${local.apiHostname}/v2/runtime-groups/${var.runtimeGroupID}"

  method = "GET"

  request_headers = {
    Accept        = "application/json"
    Authorization = "Bearer ${var.personal_access_token}"
  }
  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "konnect status code invalid: ${self.status_code} ${self.response_body}"
    }
  }
}