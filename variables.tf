variable "resource_group_name" {
  type     = string
  nullable = false
}

variable "location" {
  type     = string
  nullable = false
}

variable "tenant_id" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "vnet_vm_name" {
  type     = string
  nullable = false
}

variable "vnet_func_app_name" {
  type     = string
  nullable = false
}

variable "subnet_vm_name" {
  type     = string
  nullable = false
}

variable "subnet_function_app_name" {
  type     = string
  nullable = false
}

variable "user_principal_id" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "admin_username" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "admin_password" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "project_id_01" {
  type     = string
  nullable = false
}

variable "google_billing_account" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "project_id_02" {
  type     = string
  nullable = false
}

variable "region" {
  type     = string
  nullable = false
}

variable "prefix" {
  type     = string
  nullable = false
}

variable "repo_name" {
  type     = string
  nullable = false
}
variable "gcp_subnets" {
  type = list(object({
    ip_cidr_range = string
    name          = string
  }))
}

variable "project_01_apis" {
  type = list(string)
}

variable "project_02_apis" {
  type = list(string)
}

variable "gcp_access_token" {
  type     = string
  nullable = true
}

variable "artifact_registry_admin" {
  type     = string
  nullable = true
}

variable "shared_secret" {
  type      = string
  sensitive = true
}

variable "gcp_bgp_asn" {
  type = number
}

variable "azure_bgp_asn" {
  type = number
}

variable "azure_app_uri" {
  type = string
}

variable "apipa_address_0" {
  type = string
}


variable "apipa_address_1" {
  type = string
}

variable "project_parent_folder_id" {
  type = string
}

variable "cloud_run_name" {
  type = string
}

variable "workload_pool_id" {
  type = string
}

variable "function_app_name" {
  type = string
}