# DigiUsher Google Workspace Integration Setup

This guide provides complete instructions for setting up DigiUsher's Google Workspace license cost tracking integration. The Terraform configuration creates a GCP service account and enables the required APIs, then guides you through configuring Domain-Wide Delegation for read-only access to Workspace data.

## Overview

DigiUsher tracks your Google Workspace license costs and utilization:

- **License cost visibility** in FOCUS format alongside your cloud spend
- **Seat count tracking** per SKU per Organizational Unit
- **Suspended user detection** to reclaim unused licenses
- **Gemini AI adoption tracking** to evaluate add-on ROI

### What Gets Created (by Terraform)

1. **Service Account** (`digiusher-workspace`) with JSON key
2. **API Enablement:**
   - Admin SDK API (Directory + Reports)
   - Enterprise License Manager API
   - IAM API

### What You Configure Manually (after Terraform)

3. **Domain-Wide Delegation** in Google Admin Console
4. **Custom Admin Role** with read-only Workspace privileges

## How It Works

DigiUsher uses [Domain-Wide Delegation (DWD)](https://support.google.com/a/answer/162106) to access Google Workspace data. DWD allows the service account to impersonate a delegated admin user and call Workspace Admin SDK APIs on their behalf. A custom admin role ensures the service account can only read users, reports, and license data.

## Prerequisites

1. **GCP Project** — any project in your organization to host the service account
2. **Project Owner or Editor** access on that project
3. **Google Workspace Super Admin** access (for post-Terraform steps)
4. **Terraform** installed (v1.3+)
5. **gcloud CLI** installed and authenticated: `gcloud auth application-default login`

---

## Quick Start

### Step 1: Configure

```bash
cd google-workspace
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — set your GCP project ID
# Find yours with: gcloud projects list
```

### Step 2: Deploy

```bash
terraform init
terraform plan    # Review what will be created
terraform apply
```

### Step 3: Follow Post-Deployment Instructions

After `terraform apply`, the output displays step-by-step instructions. You can view them again with:

```bash
terraform output next_steps
```

The post-deployment steps are detailed below.

---

## Post-Deployment Step 1: Extract the Service Account Key

```bash
terraform output -raw service_account_key | base64 -d > digiusher-workspace-key.json
```

Keep this file secure. You will provide it to DigiUsher in the final step.

## Post-Deployment Step 2: Configure Domain-Wide Delegation

1. Go to the [Domain-Wide Delegation page](https://admin.google.com/ac/owl/domainwidedelegation) in the Google Admin Console
   - Or navigate: Admin Console > Security > Access and data control > API controls > Manage Domain Wide Delegation
2. Click **Add new**
3. **Client ID**: copy from Terraform output:
   ```bash
   terraform output service_account_client_id
   ```
4. **OAuth scopes**: copy from Terraform output:
   ```bash
   terraform output dwd_scopes
   ```
5. Click **Authorize**

> **Note:** DWD changes can take up to 24 hours to propagate. If DigiUsher's connection verification fails immediately, wait and retry.

## Post-Deployment Step 3: Create a Custom Admin Role

1. Go to [Admin roles](https://admin.google.com/ac/roles) in the Google Admin Console
2. Click **Create new role**
3. Name: **DigiUsher Read-Only**
4. Scroll through the privilege categories and enable:
   - **Reports**
   - **License Management**
   - **License Management** > **License Read**
   - **Users** > **Read**
5. Click **Create**

## Post-Deployment Step 4: Assign the Role to a Delegated Admin User

The service account uses Domain-Wide Delegation to impersonate a Workspace user. That user's admin privileges determine what data can be accessed, so they must hold the custom role.

1. Go to [Admin roles](https://admin.google.com/ac/roles) in the Google Admin Console
2. Click **DigiUsher Read-Only** > **Admins** > **Assign members**
3. Enter a Workspace user's email (e.g., `admin@yourdomain.com`) — typically the Super Admin running this setup
4. Click **Add** > **Assign role**

> **Important:** This must be a real user account, not the service account email. The service account impersonates this user via DWD.

## Post-Deployment Step 5: Connect to DigiUsher

In the DigiUsher platform, add a new Google Workspace data source and provide:

1. **Service account key**: the `digiusher-workspace-key.json` file from Step 1
2. **Delegated admin email**: the user email from Step 4 (this is NOT the service account email from the JSON key)

---

## Parameters Reference

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `project_id` | Yes | — | GCP project ID for the service account. Find with: `gcloud projects list` |

---

## Permissions Reference

### OAuth Scopes (authorized in Domain-Wide Delegation)

| Scope | Purpose |
|-------|---------|
| `admin.directory.user.readonly` | Read user list: email, last login, suspended status, Organizational Unit |
| `admin.reports.usage.readonly` | Read org-level usage reports: storage utilization |
| `admin.reports.audit.readonly` | Read activity audit logs: Gemini AI usage events |
| `apps.licensing` | Read license assignments: which users hold which SKUs, seat counts |

> **Note on `apps.licensing`:** This scope grants both read and write access at the API level — no read-only variant exists. DigiUsher only performs read operations. The custom admin role provides an additional layer of access control.

### Custom Admin Role Privileges

| Privilege | Purpose |
|-----------|---------|
| Reports | Access usage and activity reports |
| License Management | Top-level license management access |
| License Management > License Read | View license assignments per user and per SKU |
| Users > Read | List users with metadata (last login, suspended status, OU) |

---

## Security

### What DigiUsher CAN access (read-only)

- User directory: email addresses, last login timestamps, suspended status, Organizational Unit membership
- License assignments: which users hold which Workspace SKUs
- Usage reports: org-level storage utilization, Gemini AI usage events
- No access to email content, Drive files, Calendar events, or any user-generated data

### What DigiUsher CANNOT do

- Read email, documents, or any user content
- Modify users, groups, or organizational structure
- Assign, remove, or change licenses
- Access passwords, security keys, or 2FA settings
- Make purchases or modify billing/subscriptions

### Credential Security

The service account key is a sensitive credential:

- **Do not commit** `digiusher-workspace-key.json` or `terraform.tfstate` to version control
- The Terraform state file contains the private key in plaintext — treat it as sensitive. Consider using [remote state with encryption](https://developer.hashicorp.com/terraform/language/state/remote) for production use.
- Transfer the key to DigiUsher through their secure onboarding portal
- To rotate the key: `terraform apply -replace="google_service_account_key.digiusher_workspace"`

---

## Troubleshooting

### "Permission denied" when running Terraform

You need Project Owner or Editor access on the target GCP project:
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL" \
  --format="table(bindings.role)"
```

### "API not enabled" errors

Terraform enables APIs automatically, but propagation can take a minute. Re-run `terraform apply` if this occurs.

### DigiUsher connection verification fails

1. **DWD not propagated yet** — changes can take up to 24 hours. Wait and retry.
2. **Wrong scopes** — verify the scopes in the Admin Console match exactly:
   ```bash
   terraform output dwd_scopes
   ```
3. **Admin role not assigned** — ensure the "DigiUsher Read-Only" custom role is assigned to the delegated admin user (a real Workspace user, not the service account email).
4. **Wrong delegated admin email** — the email provided to DigiUsher must be the Workspace user who holds the "DigiUsher Read-Only" role, not the service account email from the JSON key.

### Cannot find GCP Project ID

```bash
gcloud projects list
```

---

## Revoking Access

To completely remove DigiUsher's access:

1. **Remove Terraform resources:**
   ```bash
   terraform destroy
   ```
   This deletes the service account and invalidates the key.

2. **Remove Domain-Wide Delegation entry:**
   Go to [Admin Console > DWD](https://admin.google.com/ac/owl/domainwidedelegation) and remove the entry for the service account's client ID.

3. **Remove the custom admin role** (optional):
   Go to [Admin Console > Roles](https://admin.google.com/ac/roles), click "DigiUsher Read-Only", and delete it.
