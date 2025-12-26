# DigiUsher Azure Integration Setup

This guide provides complete instructions for setting up DigiUsher's Azure cost monitoring integration. The Terraform configuration supports all Azure billing types and automatically creates the required service principal, permissions, and FOCUS cost exports.

## Overview

Our solution creates a single Azure AD application with a service principal that provides:

- **Reader access** across target subscriptions
- **FOCUS cost exports** at the appropriate billing scope
- **Reservations & Savings Plans** visibility
- **Optional VM power management** capabilities (start/stop)

### What Gets Created

1. **Azure AD Application** and Service Principal
2. **Role Assignments:**
   - Reader (subscription level)
   - Cost Management Reader (billing scope level)
   - Reservations Reader (tenant level)
   - Savings Plan Reader (tenant level)
   - Optional: Power Scheduler (VM start/stop)
3. **Storage Account** for cost exports
4. **FOCUS Cost Export** with daily schedule

### Benefits

- **Supports all Azure billing types** (EA, MCA, MPA)
- **Multi-tenant ready** with proper scope isolation
- **Simplifies credential management** - one service principal for all subscriptions
- **Automatically discovers** accessible subscriptions
- **FOCUS-compliant exports** - standard format across clouds
- **Secure by default** - minimal required permissions

## Prerequisites

- Azure CLI installed and logged in
- Terraform installed
- Billing account information

---

## Identify Your Scenario

Run this to determine configuration:

```bash
python3 check_billing_type.py
```

You'll have one of these scenarios:

| Scenario | Setup | Config Level |
|----------|-------|--------------|
| **1** | EA - no enrollment account | `billing_account` |
| **2** | EA - has enrollment account | `enrollment_account` |
| **3** | MCA (like DigiUsher) | `invoice_section` |
| **4** | Pay-as-you-go only | Not supported |

---

## Configuration Examples

### Scenario 1: EA Billing Account Level

**When to use:** EA enrollment, no dedicated enrollment account

```hcl
# Subscription and tenant
subscription_id = "sub-12345"
tenant_id       = "tenant-67890"

# EA configuration
billing_scope_level = "billing_account"
billing_account_id  = "123456"       # EA enrollment number

# Storage
storage_account_name   = ""          # Leave empty for auto-generated name
storage_container_name = "focus-exports"

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
subscription_id = "sub-12345"
tenant_id       = "tenant-67890"

# EA configuration
billing_scope_level    = "enrollment_account"
billing_account_id     = "123456"    # EA enrollment number
enrollment_account_id  = "67890"     # Specific enrollment account

# Storage
storage_account_name   = ""
storage_container_name = "focus-exports"

enable_cost_exports = true
```

**Export scope:** Contains only subscriptions in this enrollment account.

**How to find enrollment_account_id:**
```bash
# First get billing_account_id (enrollment number)
az billing account list --query "[?agreementType=='EnterpriseAgreement'].{Name:displayName, ID:name}"

# Then list enrollment accounts
az billing account enrollment-account list --account-name "123456"
```

---

### Scenario 3: MCA Invoice Section

**When to use:** Microsoft Customer Agreement (like DigiUsher's own account)

```hcl
# Subscription and tenant
subscription_id = "9b0d9bab-a3e5-4ea1-9607-4dbf244206b9"
tenant_id       = "f55d3be9-ebb2-4375-9366-bac926f020ba"

# MCA configuration
billing_scope_level = "invoice_section"
billing_account_id  = "da605be5-d7ac-56ab-895b-38988e5b8ddf:a04cc649-5078-4640-aa6b-c3001660c18e_2019-05-31"
billing_profile_id  = "6LHK-5HLH-BG7-PGB"
invoice_section_id  = "XPN2-IUAW-PJA-PGB"

# Storage
storage_account_name   = "digiushercostexport"
storage_container_name = "terraform-exports"

enable_cost_exports = true
```

**Export scope:** Contains only subscriptions in this invoice section.

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

**Status:** FOCUS exports not supported for pay-as-you-go subscriptions.

**Options:**
1. Upgrade to EA or MCA
2. Use alternative integration (ActualCost + AmortizedCost exports)

---

## Deployment Steps

### 1. Create terraform.tfvars

Copy the appropriate example above into `terraform.tfvars`

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

### 5. Save credentials

```bash
# Save client secret securely
terraform output -raw client_secret > client_secret.txt

# Note these values for DigiUsher configuration
terraform output application_id
terraform output tenant_id
terraform output storage_account_name
terraform output export_container_name
```

---

## What Gets Created

- Azure AD Application (Service Principal)
- Reader role assignment on subscriptions
- Reservations Reader and Savings Plan Reader roles
- FOCUS export configuration
- Storage account and container (if needed)
- Cost Management Reader role at billing scope

---

## DigiUsher Configuration

After deployment, configure DigiUsher with these values:

```bash
Application ID:     $(terraform output application_id)
Tenant ID:          $(terraform output tenant_id)
Client Secret:      $(cat client_secret.txt)
Storage Account:    $(terraform output storage_account_name)
Container:          $(terraform output export_container_name)
```

---

## Common Questions

**How do I know which scenario applies?**
- Run `check_billing_type.py`
- Or ask: "Do you have Enterprise Agreement?" and "Is there a dedicated enrollment account?"

**What if there's no enrollment account?**
- Use Scenario 1 (billing_account level)
- Export will contain all subscriptions
- Provide list of target subscription IDs to DigiUsher for filtering

**Can I test locally?**
- Only if you have EA or MCA
- Pay-as-you-go subscriptions don't support FOCUS exports

**What's the difference between Scenario 1 and 2?**
- Scenario 1: Export contains ALL subscriptions, filter in app
- Scenario 2: Export contains ONLY subscriptions in enrollment account, Azure enforces boundary

---

## Troubleshooting

**"FOCUS exports not supported"**
- Subscription is pay-as-you-go (MOSP)
- Solution: Upgrade to EA or MCA

**"Cannot find billing account"**
- Check permissions: Need Billing Reader role
- Or get IDs from Azure Portal: Cost Management + Billing

**"Permission denied on storage account"**
- Need Owner role during initial setup
- After setup, only Cost Management Reader needed

---

## Files Reference

- `check_billing_type.py` - Automatic billing type detection
- `terraform.tfvars` - Your configuration (create from examples above)
- `azure_configuration.tf` - Main Terraform configuration (don't modify)

---

## Next Steps

1. Identify scenario (1-4)
2. Create `terraform.tfvars` from appropriate example
3. Run `terraform apply`
4. Save credentials
5. Configure DigiUsher with output values
