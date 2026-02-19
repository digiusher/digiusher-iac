# DigiUsher GCP Integration Setup

This guide provides complete instructions for setting up DigiUsher's GCP cost monitoring integration. The Terraform configuration creates the required service account, IAM permissions, and BigQuery dataset for billing data access.

## Overview

Our solution creates a GCP service account with read-only access that provides:

- **Billing data** via BigQuery export (Detailed usage cost + Pricing)
- **Resource inventory** across the organization via Cloud Asset API
- **Utilization metrics** (CPU, memory, network, disk) via Cloud Monitoring
- **Optimization recommendations** (rightsizing, idle resources, CUDs) via Recommender API
- **Committed Use Discount (CUD)** and reservation visibility

### What Gets Created

1. **Service Account** (`digiusher-finops`) with JSON key
2. **IAM Role Assignments:**
   - Billing Viewer (billing account level) - cost data, pricing, budgets
   - BigQuery Data Viewer (dataset level) - read billing export tables
   - BigQuery Job User (project level) - run queries
   - Cloud Asset Viewer (org level) - resource inventory
   - Recommender Viewer (org level) - optimization recommendations
   - Compute Viewer (org level) - CUDs and reservations
   - Cloud SQL Viewer (org level) - Cloud SQL commitments
   - Monitoring Viewer (org level) - utilization metrics
   - Browser (org level) - org/folder/project hierarchy
   - Tag Viewer (org level) - tags for chargeback/showback
3. **BigQuery Dataset** for billing export (optional - can use existing)
4. **API Enablement** for required GCP services

### Key Differences from AWS/Azure

| Aspect | AWS | Azure | GCP |
|--------|-----|-------|-----|
| Auth | IAM Role + ExternalId | Service Principal + Secret | Service Account + Key |
| Billing data | CUR to S3 (automated) | FOCUS export to Storage (automated) | BigQuery export (**manual step**) |
| IaC tool | CloudFormation | Terraform | Terraform |

> **Important:** Unlike AWS and Azure, GCP billing export to BigQuery cannot be automated via Terraform or API. After running Terraform, you must [enable billing export manually](#step-2-enable-billing-export) in the GCP Console. See [GCP_BILLING_EXPORT_GUIDE.md](GCP_BILLING_EXPORT_GUIDE.md) for detailed instructions.

## GCP Hierarchy Primer

If you are new to GCP's resource hierarchy, here is how it maps to AWS and Azure:

| GCP Concept | AWS Equivalent | Azure Equivalent | How to Find |
|-------------|---------------|-----------------|-------------|
| **Organization** | AWS Organization | Azure Tenant | `gcloud organizations list` or Console: IAM & Admin > Settings |
| **Folder** | Organizational Unit (OU) | Management Group | `gcloud resource-manager folders list --organization=ORG_ID` |
| **Project** | AWS Account | Subscription | `gcloud projects list` |
| **Billing Account** | Payer Account | Billing Account | `gcloud billing accounts list` |

**Key difference:** In GCP, the Billing Account is a **separate entity** from the Organization. A single billing account can fund projects across multiple organizations, and one organization can have projects linked to different billing accounts.

**Organization:** Your GCP Organization exists automatically if you have Google Workspace or Cloud Identity. It is the top-level container for all your folders and projects. When DigiUsher is granted access at the organization level, it covers all current and future projects.

## Prerequisites

1. **GCP Project** - A project to host the service account and BigQuery dataset
2. **Organization Administrator** access - to grant org-level IAM roles (or Project Owner for limited/POC setup)
3. **Billing Account Administrator** access - to grant billing viewer role
4. **Terraform** installed (v1.3+)
5. **gcloud CLI** installed and authenticated: `gcloud auth application-default login`

---

## Quick Start

### Step 1: Deploy Terraform

Choose your scenario and copy the appropriate configuration:

#### Scenario 1: Full Organization Onboarding (Recommended)

```bash
# Find your IDs
gcloud organizations list                  # → Organization ID
gcloud billing accounts list               # → Billing Account ID
gcloud projects list                       # → Project ID

# Create your terraform.tfvars
cp terraform.tfvars.org-level.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

#### Scenario 2: Limited / POC (Specific Projects Only)

```bash
cp terraform.tfvars.limited.example terraform.tfvars
# Edit terraform.tfvars - set target_project_ids to your project list

terraform init && terraform plan && terraform apply
```

To later expand to full org access, remove the `target_project_ids` line and re-run `terraform apply`.

#### Scenario 3: Existing Billing Export

```bash
cp terraform.tfvars.existing-export.example terraform.tfvars
# Edit terraform.tfvars - set billing_export_dataset_id to your existing dataset

terraform init && terraform plan && terraform apply
```

### Step 2: Enable Billing Export

> **This step cannot be automated.** You must do it manually in the GCP Console.

See [GCP_BILLING_EXPORT_GUIDE.md](GCP_BILLING_EXPORT_GUIDE.md) for detailed step-by-step instructions.

Quick summary:
1. Go to [GCP Console > Billing > Billing export](https://console.cloud.google.com/billing/export)
2. Under **BigQuery export**, click **Edit settings**
3. Select the project and dataset created by Terraform (or your existing dataset)
4. Enable **Detailed usage cost** export
5. Enable **Pricing** export
6. Click **Save**

Data will begin flowing within 24-48 hours. Multi-region datasets (US/EU) automatically backfill the previous month.

### Step 3: Extract Service Account Key

```bash
# Decode the service account key
terraform output -raw service_account_key | base64 -d > digiusher-key.json

# Verify it works
gcloud auth activate-service-account --key-file=digiusher-key.json
gcloud asset search-all-resources --scope=organizations/YOUR_ORG_ID --limit=5
```

### Step 4: Configure DigiUsher

Provide the following to the DigiUsher platform:
1. The `digiusher-key.json` file (service account credentials)
2. Project ID: `terraform output project_id`
3. Organization ID: `terraform output organization_id`
4. BigQuery Dataset ID: `terraform output bigquery_dataset_id`

---

## Parameters Reference

### Required

| Parameter | Description | Example |
|-----------|-------------|---------|
| `project_id` | GCP project for service account and BigQuery dataset | `"my-billing-project"` |
| `organization_id` | GCP Organization ID | `"123456789012"` |
| `billing_account_id` | GCP Billing Account ID | `"ABCDEF-123456-ABCDEF"` |

### Scope Limiting

| Parameter | Default | Description |
|-----------|---------|-------------|
| `target_project_ids` | `[]` (org-wide) | Specific project IDs to limit access to. Empty = org-wide (recommended). |

### BigQuery

| Parameter | Default | Description |
|-----------|---------|-------------|
| `create_bigquery_dataset` | `true` | Create a new BigQuery dataset. Set `false` if you already have one. |
| `billing_export_dataset_id` | `"digiusher_billing_export"` | Dataset ID for billing export data. |
| `bigquery_location` | `"US"` | Must be `US` or `EU` multi-region for billing data backfill. |

### Feature Flags

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enable_resource_inventory` | `true` | Cloud Asset API access for resource discovery. |
| `enable_recommendations` | `true` | Recommender API for optimization insights. |
| `enable_monitoring` | `true` | Cloud Monitoring for utilization metrics. |

---

## What Permissions Are Granted and Why

All permissions are **read-only**. DigiUsher cannot create, modify, or delete any of your GCP resources.

### Billing Account Level

| Role | Why We Need It |
|------|---------------|
| `roles/billing.viewer` | Read cost data, pricing, budgets, anomalies, and spend-based CUD information from the Cloud Billing API. |

### Organization Level (or per-project if `target_project_ids` is set)

| Role | Why We Need It |
|------|---------------|
| `roles/browser` | Browse the organization, folder, and project hierarchy for accurate cost attribution. |
| `roles/cloudasset.viewer` | List and search all resources across projects using the Cloud Asset API. Used for resource inventory and tag-based chargeback. |
| `roles/recommender.viewer` | Access optimization recommendations: VM rightsizing, idle resource detection, CUD purchase recommendations. |
| `roles/compute.viewer` | View Compute Engine resource details, Committed Use Discounts (CUDs), and reservations. |
| `roles/cloudsql.viewer` | View Cloud SQL instance details and committed use pricing for optimization recommendations. |
| `roles/monitoring.viewer` | Read utilization metrics (CPU, memory, network, disk) from Cloud Monitoring for rightsizing analysis. |
| `roles/resourcemanager.tagViewer` | Read organization tags and tag bindings for chargeback/showback cost allocation. |

### Project Level (billing export project)

| Role | Why We Need It |
|------|---------------|
| `roles/bigquery.jobUser` | Execute BigQuery queries against the billing export dataset. |
| `roles/serviceusage.serviceUsageConsumer` | Required for making Cloud Asset API calls from this project. |

### BigQuery Dataset Level

| Role | Why We Need It |
|------|---------------|
| `roles/bigquery.dataViewer` | Read data from the billing export tables. Scoped to the billing dataset only. |

---

## Verification

After deployment, verify that everything is working:

```bash
# 1. Check Terraform outputs
terraform output

# 2. Verify org-level IAM bindings
gcloud organizations get-iam-policy YOUR_ORG_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:digiusher-finops@*" \
  --format="table(bindings.role)"

# 3. Verify billing account IAM
gcloud billing accounts get-iam-policy YOUR_BILLING_ACCOUNT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:digiusher-finops@*" \
  --format="table(bindings.role)"

# 4. Test service account authentication
terraform output -raw service_account_key | base64 -d > /tmp/digiusher-key.json
gcloud auth activate-service-account --key-file=/tmp/digiusher-key.json

# 5. Test resource inventory (if enabled)
gcloud asset search-all-resources --scope=organizations/YOUR_ORG_ID --limit=5

# 6. Test BigQuery access (after billing export data is available)
bq query --use_legacy_sql=false \
  "SELECT table_id FROM \`YOUR_PROJECT.YOUR_DATASET.__TABLES__\`"

# 7. Clean up test key
rm /tmp/digiusher-key.json
gcloud auth revoke digiusher-finops@YOUR_PROJECT.iam.gserviceaccount.com 2>/dev/null
```

**Note:** BigQuery billing export tables appear 24-48 hours after enabling billing export in the Console. If step 6 shows no tables, wait and retry.

---

## Troubleshooting

### "Permission denied" when running Terraform

You need Organization Administrator and Billing Account Administrator roles. Check with:
```bash
gcloud organizations get-iam-policy YOUR_ORG_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL" \
  --format="table(bindings.role)"
```

### "API not enabled" errors

Terraform enables APIs automatically, but propagation can take a minute. Re-run `terraform apply` if this occurs.

### Cannot find Organization ID

```bash
gcloud organizations list
```
If this returns empty, your GCP account may not have an organization. Organizations are tied to Google Workspace or Cloud Identity domains. Contact your GCP admin or [set up Cloud Identity](https://cloud.google.com/identity/docs/set-up-cloud-identity-admin).

### Cannot find Billing Account ID

```bash
gcloud billing accounts list
```
You must have at least Billing Account Viewer access to see billing accounts.

### BigQuery dataset already exists

If you see `Error: googleapi: Error 409: Already Exists`:
- Set `create_bigquery_dataset = false` in your tfvars
- Set `billing_export_dataset_id` to the name of your existing dataset

### No billing data after 48 hours

1. Verify billing export is enabled: Console > Billing > Billing export
2. Confirm the dataset location is multi-region (US or EU)
3. Check that the correct billing account is selected
4. Ensure **Detailed usage cost** export is enabled (not just Standard)

---

## Security

### What DigiUsher CAN access (read-only)

- Billing data and cost information via BigQuery
- Resource metadata (names, types, regions, labels, tags)
- Utilization metrics (CPU, memory, network, disk)
- Optimization recommendations from Google's Recommender API
- CUD and reservation information
- Organization, folder, and project structure

### What DigiUsher CANNOT do

- Create, modify, or delete any GCP resources
- Access application data, databases, or storage contents
- Modify IAM policies or permissions
- Read secrets, credentials, or encryption keys
- Access network traffic or logs content
- Make purchases or modify billing settings

### Credential Security

The service account key is a sensitive credential. Handle it like a password:
- Do not commit it to version control
- Transfer it to DigiUsher through their secure onboarding portal
- The key does not expire by default - rotate it periodically if your security policy requires it
- To rotate: `terraform taint google_service_account_key.digiusher && terraform apply`

### Revoking Access

To completely remove DigiUsher's access:
```bash
terraform destroy
```
This removes the service account, all IAM bindings, and invalidates the key.
