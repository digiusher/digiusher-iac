###############################################################################
# Billing Account IAM
#
# Grants read-only access to billing data: costs, pricing, budgets,
# anomalies, and spend-based committed use discounts.
###############################################################################

resource "google_billing_account_iam_member" "viewer" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = local.sa_member
}
