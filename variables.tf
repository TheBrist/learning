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
  type = string
  nullable = true
}