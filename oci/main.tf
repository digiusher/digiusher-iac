# -----------------------------------------------------------------------------
# IAM Group
# -----------------------------------------------------------------------------

resource "oci_identity_group" "digiusher" {
  compartment_id = var.tenancy_ocid
  name           = var.group_name
  description    = "DigiUsher FinOps platform - read-only access for cost analytics and optimization"
}

# -----------------------------------------------------------------------------
# IAM User
# -----------------------------------------------------------------------------

resource "oci_identity_user" "digiusher" {
  compartment_id = var.tenancy_ocid
  name           = var.user_name
  description    = "Service user for DigiUsher FinOps platform"
}

resource "oci_identity_user_group_membership" "digiusher" {
  group_id = oci_identity_group.digiusher.id
  user_id  = oci_identity_user.digiusher.id
}

# -----------------------------------------------------------------------------
# Policy: Cost Report Cross-Tenancy Access
#
# OCI stores cost reports in an Oracle-owned Object Storage bucket.
# The 'endorse' statement grants cross-tenancy read access to that bucket.
# The usage-report tenancy OCID is the same for all OCI customers.
#
# define/endorse statements must be in a separate policy from Allow statements.
# -----------------------------------------------------------------------------

resource "oci_identity_policy" "digiusher_cost_report_endorse" {
  compartment_id = var.tenancy_ocid
  name           = "digiusher-cost-report-endorse"
  description    = "Cross-tenancy access to Oracle's cost report Object Storage bucket"

  statements = [
    "define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "endorse group ${var.group_name} to read objects in tenancy usage-report",
  ]
}

# -----------------------------------------------------------------------------
# Policy: Cost and Usage Data
# -----------------------------------------------------------------------------

resource "oci_identity_policy" "digiusher_cost_reports" {
  compartment_id = var.tenancy_ocid
  name           = "digiusher-cost-report-access"
  description    = "Allow DigiUsher to read cost and usage reports and budgets"

  statements = [
    "Allow group ${var.group_name} to read usage-report in tenancy",
    "Allow group ${var.group_name} to read usage-budgets in tenancy",
  ]
}

# -----------------------------------------------------------------------------
# Policy: Resource Discovery
#
# Grants read access to all resources across the tenancy via the Resource
# Search API, enabling DigiUsher to build a complete resource inventory.
# -----------------------------------------------------------------------------

resource "oci_identity_policy" "digiusher_resource_discovery" {
  count = var.enable_resource_discovery ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "digiusher-resource-discovery"
  description    = "Allow DigiUsher to read all resources for inventory and optimization"

  statements = [
    "Allow group ${var.group_name} to read all-resources in tenancy",
  ]
}

# -----------------------------------------------------------------------------
# Policy: Metrics Access
#
# Grants read access to OCI Monitoring metrics (CPU, network, disk, etc.)
# across all compartments. Memory metrics require the Oracle Cloud Agent
# with Compute Instance Monitoring plugin enabled on customer instances.
# -----------------------------------------------------------------------------

resource "oci_identity_policy" "digiusher_metrics" {
  count = var.enable_metrics_access ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "digiusher-metrics-access"
  description    = "Allow DigiUsher to read monitoring metrics for optimization recommendations"

  statements = [
    "Allow group ${var.group_name} to read metrics in tenancy",
  ]
}
