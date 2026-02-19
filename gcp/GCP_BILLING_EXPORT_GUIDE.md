# GCP Billing Export Setup Guide

This guide walks you through enabling BigQuery billing export in the GCP Console. **This step cannot be automated** - it must be done manually by a Billing Account Administrator.

## Why This Step Is Required

GCP billing data is accessed through BigQuery. The billing export configuration must be done manually in the GCP Console - there is no API or Terraform resource for this step.

## Prerequisites

- **Billing Account Administrator** role on your GCP billing account
- BigQuery dataset already created (Terraform creates this if `create_bigquery_dataset = true`)
- If you set `create_bigquery_dataset = false`, ensure your existing dataset uses a **multi-region location** (US or EU)

## Step-by-Step Instructions

### 1. Open Billing Export Settings

Navigate to the GCP Console:

```
https://console.cloud.google.com/billing/export
```

Or: **Console** > **Billing** > **Billing export**

If you have multiple billing accounts, select the correct one from the dropdown at the top.

> **Important:** All exports below must point to the **same project and dataset**. DigiUsher is granted read access to this one dataset, and expects all billing tables (detailed, pricing, standard) to be in it.

### 2. Enable Detailed Usage Cost Export (Required)

This is the primary data source DigiUsher uses for cost analytics.

1. Click on the **BigQuery Export** tab
2. Under **Detailed usage cost**, click **Edit settings**
3. Select the **project** where the Terraform created the BigQuery dataset (your `project_id`)
4. Select the **dataset**: `digiusher_billing_export` (or your custom `billing_export_dataset_id`)
5. Click **Save**

The table name will be: `gcp_billing_export_resource_v1_<BILLING_ACCOUNT_ID>`

### 3. Enable Pricing Data Export (Required)

This provides SKU-level pricing data needed for rate optimization.

1. Under **Pricing**, click **Edit settings**
2. Select the same **project** and **dataset** as above
3. Click **Save**

The table name will be: `cloud_pricing_export`

### 4. Enable Standard Usage Cost Export (Optional)

This provides a lighter-weight cost summary. Not required but useful as a fallback.

1. Under **Standard usage cost**, click **Edit settings**
2. Select the same **project** and **dataset** as above
3. Click **Save**

The table name will be: `gcp_billing_export_v1_<BILLING_ACCOUNT_ID>`

## Data Availability

| Dataset Location | Backfill | New Data |
|-----------------|----------|----------|
| **Multi-region (US or EU)** | Previous month + current month | Throughout the day |
| **Regional** | None - starts from enable date only | Throughout the day |

- Data begins populating within **24-48 hours** after enabling
- Billing data is loaded incrementally throughout the day (not real-time)
- Cost corrections and credits may appear retroactively
- Multi-region datasets are **strongly recommended** for historical data coverage

## Verification

After 24-48 hours, verify that data is flowing:

```bash
# Check that tables exist
bq ls YOUR_PROJECT:YOUR_DATASET

# Query the latest billing data
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as row_count, MIN(export_time) as earliest, MAX(export_time) as latest
   FROM \`YOUR_PROJECT.YOUR_DATASET.gcp_billing_export_resource_v1_*\`"

# Check pricing data
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as sku_count
   FROM \`YOUR_PROJECT.YOUR_DATASET.cloud_pricing_export\`"
```

## Troubleshooting

### "You don't have permission to access billing export settings"

You need the **Billing Account Administrator** role. Ask your billing admin to either:
- Grant you the role: `gcloud billing accounts add-iam-policy-binding BILLING_ACCOUNT_ID --member=user:YOUR_EMAIL --role=roles/billing.admin`
- Or perform this step themselves

### Dataset not showing in the dropdown

- Ensure the BigQuery API is enabled in the project
- Ensure the dataset was created in a supported location (US or EU multi-region recommended)
- Wait a few minutes after Terraform creates the dataset for it to propagate

### No data after 48 hours

1. Check that the export status shows "Enabled" (not "Pending" or "Error")
2. Verify the billing account has active projects with usage
3. Check the dataset location - regional datasets do not backfill
4. Try disabling and re-enabling the export

### Dataset location mismatch

BigQuery dataset location is **immutable** - it cannot be changed after creation. If you need a different location:
1. Set `create_bigquery_dataset = false` in Terraform
2. Create a new dataset manually in the desired location
3. Update `billing_export_dataset_id` in your tfvars
4. Run `terraform apply`
5. Re-configure billing export to point to the new dataset

## FOCUS Format

Google provides a native FOCUS (FinOps Open Cost and Usage Specification) BigQuery view that maps billing data into the standardized FOCUS schema. This requires both **Detailed usage cost** and **Pricing** exports to be enabled - which is why we require both above.

DigiUsher uses this to normalize your GCP costs into a consistent format across all your cloud providers.
