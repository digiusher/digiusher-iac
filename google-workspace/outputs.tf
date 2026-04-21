###############################################################################
# Outputs
#
# Values needed to configure Domain-Wide Delegation and connect to DigiUsher.
# Extract key: terraform output -raw service_account_key | base64 -d > digiusher-workspace-key.json
###############################################################################

output "service_account_email" {
  value       = google_service_account.digiusher_workspace.email
  description = "Email of the DigiUsher Workspace service account."
}

output "service_account_key" {
  value       = google_service_account_key.digiusher_workspace.private_key
  sensitive   = true
  description = "Base64-encoded JSON key for the service account. Decode with: terraform output -raw service_account_key | base64 -d > digiusher-workspace-key.json"
}

output "service_account_client_id" {
  value       = google_service_account.digiusher_workspace.unique_id
  description = "Numeric Client ID of the service account. Required for Domain-Wide Delegation setup in the Google Admin Console."
}

output "project_id" {
  value       = var.project_id
  description = "GCP project hosting the service account."
}

output "dwd_scopes" {
  value       = join(",", local.dwd_scopes)
  description = "Comma-separated OAuth scopes to authorize in Domain-Wide Delegation. Copy-paste this value into the Admin Console."
}

output "dwd_admin_console_url" {
  value       = "https://admin.google.com/ac/owl/domainwidedelegation"
  description = "Direct URL to the Domain-Wide Delegation page in the Google Admin Console."
}

output "next_steps" {
  value = <<-EOT

    ============================================================
    NEXT STEPS — Complete these manually to finish setup
    ============================================================

    STEP 1: Extract the service account key
    ----------------------------------------
    terraform output -raw service_account_key | base64 -d > digiusher-workspace-key.json

    STEP 2: Configure Domain-Wide Delegation
    -----------------------------------------
    1. Go to: https://admin.google.com/ac/owl/domainwidedelegation
       (or: Admin Console > Security > Access and data control >
        API controls > Manage Domain Wide Delegation)
    2. Click "Add new"
    3. Client ID: ${google_service_account.digiusher_workspace.unique_id}
    4. OAuth scopes (copy this entire line):
       ${join(",", local.dwd_scopes)}
    5. Click "Authorize"

    STEP 3: Create a custom admin role
    ------------------------------------
    1. Go to: https://admin.google.com/ac/roles
    2. Click "Create new role"
    3. Name: "DigiUsher Read-Only"
    4. Scroll through privilege categories and enable:
       - Reports
       - License Management
       - License Management > License Read
       - Users > Read
    5. Click "Create"

    STEP 4: Assign the role to a delegated admin user
    ---------------------------------------------------
    1. Go to: https://admin.google.com/ac/roles
    2. Click "DigiUsher Read-Only" > "Admins" > "Assign members"
    3. Enter a Workspace user's email (e.g., admin@yourdomain.com)
       Typically the Super Admin running this setup. Must be a real
       user account — the service account impersonates this user via
       DWD, so this user's admin privileges control what data can
       be accessed.
    4. Click "Add" > "Assign role"

    STEP 5: Connect in DigiUsher
    ------------------------------
    Provide the following in the DigiUsher data source setup:
    1. Service account key: the digiusher-workspace-key.json file from Step 1
    2. Delegated admin email: the user email from Step 4 (NOT the
       service account email from the JSON key — these are different)

    ============================================================
    NOTE: Domain-Wide Delegation changes can take up to 24 hours
    to propagate. If connection verification fails immediately
    after setup, wait and retry.
    ============================================================
  EOT

  description = "Post-deployment instructions for Domain-Wide Delegation and custom admin role setup."
}
