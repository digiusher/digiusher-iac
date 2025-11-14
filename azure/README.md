# DigiUsher Azure AD Application Creation

This README provides step-by-step instructions on how to create a single Azure AD application that can access multiple Azure subscriptions using our provided Terraform template.

## Overview

Our solution creates a single Azure AD application with a service principal that has Reader access across all subscriptions in your Azure tenant. This approach:
- Simplifies credential management
- Automatically discovers all accessible subscriptions
- Provides consistent access levels across subscriptions
- Reduces maintenance overhead
- Optional VM power management capabilities (start/stop)

## Prerequisites

Before you begin, ensure you have:

- Azure CLI installed and authenticated
- Terraform installed on your local machine (version 1.0.0 or higher)
- Global Administrator or Application Administrator role in Azure AD
- Owner or User Access Administrator role in the target subscriptions
- Global Administrator access for Reservations Reader and Savings Plan Reader role assignments
  - Note: You need to temporarily elevate access for assigning both the Reservation Reader and Savings Plan Reader permissions. The process is [documented here](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)

## Permissions Overview

The service principal will be granted:
1. Reader role on all target subscriptions
2. Reservations Reader role at the tenant level
3. Savings Plan Reader role at the tenant level

## Instructions

1. **Configure Azure Variables**:

Create a `terraform.tfvars` file with your Azure details:

```hcl
subscription_id = "your-primary-subscription-id"
tenant_id       = "your-tenant-id"

# Optional: Enable VM power management permissions
enable_power_scheduler = true

# Optional: Specify target subscriptions (if [], all subscriptions will be used)
target_subscription_ids = [
  "subscription-id-1",
  "subscription-id-2"
]
```

2. **Initialize Terraform**:

```bash
terraform init
```

3. **Review the Planned Changes**:

```bash
terraform plan
```

4. **Apply the Changes**:

```bash
terraform apply
```

5. **Retrieve Application Credentials**:

After successful application, you can retrieve the credentials using the following commands:

```bash
# Get Application (Client) ID
terraform output application_id

# Get Tenant ID
terraform output tenant_id

# Get Client Secret (sensitive)
terraform output -json client_secret

## Error Scenarios
```

**Authorization Error**
If you encounter:

```
Error: loading Role Definition List: unexpected status 403 (403 Forbidden) with error: AuthorizationFailed:
```

This usually means:
1. Your Azure CLI session has expired - run `az login` again
2. You lack sufficient permissions in the target subscription
3. The subscription is not accessible to your account

Make sure you have appropriate permissions in both Azure AD and the target subscriptions.

## Finding Your Billing Scope Information

### Step 1: Determine Your Billing Account Type
```bash
# Check your billing accounts
az billing account list -o table
```

**Result interpretation:**
- If you see accounts with `agreementType: Enterprise` → You have **EA**
- If you see accounts with `agreementType: MicrosoftCustomerAgreement` → You have **MCA**
- If the command returns empty or errors → You likely have **MOSP** (pay-as-you-go) → ⚠️ **FOCUS exports not supported**

### Step 2: Get Your Billing IDs

**For Enterprise Agreement (EA):**
```bash
# Get your enrollment number (this is your billing_account_id)
az billing account list --query "[?agreementType=='Enterprise'].{Name:displayName, EnrollmentID:name}" -o table
```

In your `terraform.tfvars`:
```hcl
billing_account_id = "123456"  # Your enrollment number
billing_profile_id = ""        # Leave empty for EA
```

**For Microsoft Customer Agreement (MCA):**
```bash
# Get billing account ID
az billing account list --query "[?agreementType=='MicrosoftCustomerAgreement'].{Name:displayName, ID:name}" -o table

# Get billing profile ID for that account
az billing profile list --account-name "YOUR-BILLING-ACCOUNT-ID" --query "[].{Name:displayName, ID:name}" -o table
```

In your `terraform.tfvars`:
```hcl
billing_account_id = "abcd-efgh-ijkl"  # Your billing account ID
billing_profile_id = "XXXX-XXXX-XXX"   # Your billing profile ID
```

**For Pay-As-You-Go (MOSP):**
⚠️ FOCUS exports are NOT supported for MOSP subscriptions. Contact DigiUsher for alternative integration options.

## Running the Setup

1. **Configure your `terraform.tfvars`** with the values from above

2. **Initialize and apply Terraform:**
```bash
terraform init
terraform apply
```

3. **Save your credentials:**
```bash
# Save these for the backfill script
terraform output -raw client_secret > client_secret.txt
terraform output application_id
terraform output tenant_id
```

4. **Backfill historical data (recommended):**
```bash
# Install Python dependencies
pip install requests python-dateutil

# Run backfill for last 13 months
python3 backfill_historical_data.py \
  --tenant-id $(terraform output -raw tenant_id) \
  --client-id $(terraform output -raw application_id) \
  --client-secret $(cat client_secret.txt) \
  --billing-scope $(terraform output -raw billing_scope) \
  --export-name $(terraform output -raw export_name) \
  --months 13

# Or for maximum history (7 years = 84 months)
python3 backfill_historical_data.py ... --months 84
```

5. **Verify exports in Azure Storage:**
```bash
az storage blob list \
  --account-name $(terraform output -raw storage_account_name) \
  --container-name $(terraform output -raw storage_container_name) \
  --auth-mode login
```

## Data Location

Your FOCUS exports will be available at:
- **Storage Account:** Check `terraform output storage_account_name`
- **Container:** `focus-exports` (or your custom name)
- **Path:** `focus/digiusher-focus-export/YYYYMMDD-YYYYMMDD/[RunID]/`

Each export includes:
- CSV files (gzip compressed) with FOCUS-formatted cost data
- `manifest.json` file describing the export contents
