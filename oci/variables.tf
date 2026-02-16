variable "tenancy_ocid" {
  type        = string
  description = "OCID of your OCI tenancy. Find it in OCI Console under Administration > Tenancy Details."
}

variable "region" {
  type        = string
  description = "OCI home region identifier (e.g. us-ashburn-1). IAM resources are created in the home region."
}

variable "user_name" {
  type        = string
  description = "Name of the IAM user to create for DigiUsher."
  default     = "digiusher-service-user"
}

variable "group_name" {
  type        = string
  description = "Name of the IAM group to create for DigiUsher."
  default     = "digiusher-finops-group"
}

variable "enable_resource_discovery" {
  type        = bool
  description = "Grant read access to all resources in the tenancy for inventory and optimization."
  default     = true
}

variable "enable_metrics_access" {
  type        = bool
  description = "Grant read access to OCI Monitoring metrics (CPU, network, etc.) for optimization recommendations."
  default     = true
}
