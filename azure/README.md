# DigiUsher Azure Integration Setup

This guide provides complete instructions for setting up DigiUsher's Azure cost monitoring integration. The Terraform configuration supports all Azure billing types and automatically grants DigiUsher access to your cost data.

## Overview

This setup grants DigiUsher's service principal access to your Azure resources. **No secrets are created or shared** - DigiUsher authenticates with its own credentials and accesses resources through role assignments you control.

### What This Does

- Grants **Reader access** across target subscriptions
- Creates **FOCUS cost exports** at the appropriate billing scope
- Grants **Reservations & Savings Plans** visibility (recommended)
- Optionally enables **VM power management** capabilities

### What Gets Created

1. **Service Principal** - DigiUsher's app registered in your tenant
2. **Role Assignments:**
   - Reader (subscription level)
   - Cost Management Contributor (EA) or Billing Account Contributor (MCA)
   - Reservations Reader (tenant level) - recommended
   - Savings Plan Reader (tenant level) - recommended
   - Power Scheduler (VM start/stop) - optional
3. **Storage Account** for cost exports
4. **FOCUS Cost Export** with daily schedule

### Benefits

- **No secrets to manage** - DigiUsher uses its own credentials
- **You control access** - Remove the service principal to revoke access
- **Supports all Azure billing types** (EA, MCA, MPA)
- **FOCUS-compliant exports** - standard format across clouds
- **Secure by default** - minimal required permissions

## Prerequisites

- Azure CLI installed and logged in
- Terraform installed
- Billing account information

---

## Elevated Access for Reservations & Savings Plans

The Reservations Reader and Savings Plan Reader roles are assigned at the **tenant level** (on `/providers/Microsoft.Capacity` and `/providers/Microsoft.BillingBenefits`). By default, even tenant administrators cannot assign roles at these scopes.

### Option 1: Temporarily Enable Elevated Access (Recommended)

To assign these roles, **temporarily** enable elevated access in Azure:

1. Go to **Azure Portal** → **Microsoft Entra ID**
2. Navigate to **Properties** (in the left menu)
3. Scroll to **Access management for Azure resources**
4. Set to **Yes** and click **Save**
5. Run `terraform apply`
6. **After successful deployment**, set it back to **No** for security

This temporarily grants your account the **User Access Administrator** role at root scope (`/`), allowing the one-time tenant-level role assignments.

### Option 2: Skip These Roles

If you cannot enable elevated access or don't need reservations/savings plan visibility, set in your `terraform.tfvars`:

```hcl
enable_reservations_access = false
```

This will skip the Reservations Reader and Savings Plan Reader role assignments. The FOCUS cost export and other functionality will work normally.

---

## Identify Your Scenario

Run this to determine configuration:

```bash
python3 check_billing_type.py
```

| Scenario | Setup | Config Level |
|----------|-------|--------------|
| **1** | EA - no enrollment account | `billing_account` |
| **2** | EA - has enrollment account | `enrollment_account` |
| **3** | MCA | `billing_account` or `invoice_section` |
| **4** | MOSP/Pay-as-you-go only | Not supported |

---

## Configuration Examples

### Scenario 1: EA Billing Account Level

**When to use:** EA enrollment, no dedicated enrollment account

```hcl
# Subscription and tenant
subscription_id = "REPLACE_WITH_SUBSCRIPTION_ID"
tenant_id       = "REPLACE_WITH_TENANT_ID"

# EA configuration
billing_scope_level = "billing_account"
billing_account_id  = "123456"  # EA enrollment number

# Storage
storage_account_name   = ""     # Leave empty for auto-generated name
storage_container_name = "digiusher-focus-exports"

enable_cost_exports = true
```

**Export scope:** Contains all subscriptions in the billing account. DigiUsher filters to target subscriptions.

**How to find billing_account_id:**
```bash
az billing account list --query "[?agreementType=='EnterpriseAgreement'].{Name:displayName, ID:name}"
```

---

### Scenario 2: EA With Enrollment Account

**When to use:** EA enrollment with dedicated enrollment account

```hcl
# Subscription and tenant
subscription_id = "REPLACE_WITH_SUBSCRIPTION_ID"
tenant_id       = "REPLACE_WITH_TENANT_ID"

# EA configuration
billing_scope_level    = "enrollment_account"
billing_account_id     = "123456"  # EA enrollment number
enrollment_account_id  = "67890"   # Specific enrollment account

# Storage
storage_account_name   = ""
storage_container_name = "digiusher-focus-exports"

enable_cost_exports = true
```

**Export scope:** Contains only subscriptions in this enrollment account.

**How to find IDs:**
```bash
# First get billing_account_id (enrollment number)
az billing account list --query "[?agreementType=='EnterpriseAgreement'].{Name:displayName, ID:name}"

# Then list enrollment accounts
az billing enrollment-account list
```

---

### Scenario 3: MCA

**When to use:** Microsoft Customer Agreement (not EA)

```hcl
# Subscription and tenant
subscription_id = "REPLACE_WITH_SUBSCRIPTION_ID"
tenant_id       = "REPLACE_WITH_TENANT_ID"

# MCA configuration
billing_scope_level = "billing_account"
billing_account_id  = "da605be5-...:a04cc649-..._2019-05-31"

# Or use invoice section for finer control:
# billing_scope_level = "invoice_section"
# billing_profile_id  = "XXXX-XXXX-XXX-XXX"
# invoice_section_id  = "XXXX-XXXX-XXX-XXX"

# Storage
storage_account_name   = ""
storage_container_name = "digiusher-focus-exports"

enable_cost_exports = true
```

**Export scope:** Contains subscriptions in the billing account or invoice section, depending on configuration.

**How to find IDs:**
```bash
# Get billing account
az billing account list --query "[?agreementType=='MicrosoftCustomerAgreement'].{Name:displayName, ID:name}"

# Get billing profiles
az billing profile list --account-name "BILLING_ACCOUNT_ID"

# Get invoice sections
az billing invoice section list --account-name "BILLING_ACCOUNT_ID" --profile-name "PROFILE_ID"
```

---

### Scenario 4: Pay-as-you-go (MOSP)

**Status:** FOCUS exports are not supported for pay-as-you-go subscriptions.

**Options:**
1. Upgrade to EA or MCA
2. Contact support@digiusher.com for alternative integration options

---

## Deployment Steps

### 1. Create terraform.tfvars

Copy the appropriate example above into `terraform.tfvars` and fill in your values.

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review changes

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Share onboarding information with DigiUsher

```bash
terraform output -json digiusher_onboarding
```

This provides DigiUsher with:
- `tenant_id` - Your Azure tenant
- `storage_account_name` - Where exports are stored
- `storage_container_name` - Container name
- `export_root_path` - Path within container
- `billing_scope` - Billing scope for backfills
- `export_name` - Export name for backfills

**Note:** No secrets are shared. DigiUsher authenticates with its own credentials.

---

## Revoking Access

To revoke DigiUsher's access:

1. Remove the service principal:
   ```bash
   terraform destroy
   ```

2. Or manually in Azure Portal:
   - Go to **Microsoft Entra ID** → **Enterprise Applications**
   - Find "DigiUsher" and delete it

---

## Common Questions

**How do I know which scenario applies?**
- Run `check_billing_type.py`
- Or ask: "Do you have Enterprise Agreement?" and "Is there a dedicated enrollment account?"
- Contact support@digiusher.com

**What if there's no enrollment account?**
- Use Scenario 1 (billing_account level)
- Export contains all subscriptions
- Provide list of target subscription IDs to DigiUsher for filtering

**What's the difference between Scenario 1 and 2?**
- Scenario 1: Export contains ALL subscriptions, filter in app
- Scenario 2: Export contains ONLY subscriptions in enrollment account

**How does DigiUsher access my data?**
- DigiUsher has a multi-tenant Azure AD application
- This terraform creates a service principal for that app in your tenant
- You grant roles to that service principal
- DigiUsher authenticates with its own credentials and uses the roles you granted

---

## Troubleshooting

**"FOCUS exports not supported"**
- Subscription is pay-as-you-go (MOSP)
- Solution: Upgrade to EA or MCA

**"Cannot find billing account"**
- Check permissions: Need Billing Reader role
- Or get IDs from Azure Portal: Cost Management + Billing

**"Permission denied on role assignment"**
- Need Owner or User Access Administrator role
- For tenant-level roles, enable elevated access (see above)

---

## Files Reference

- `azure_configuration.tf` - Main Terraform configuration
- `terraform.tfvars` - Your configuration (create from examples)
- `check_billing_type.py` - Automatic billing type detection

---

## Next Steps

1. Identify scenario (1-3) using `check_billing_type.py`
2. Create `terraform.tfvars` from appropriate example
3. Run `terraform apply`
4. Share `digiusher_onboarding` output with DigiUsher
