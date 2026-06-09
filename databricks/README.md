# DigiUsher Databricks Integration Setup

This guide covers setting up DigiUsher's Databricks cost monitoring integration.
The Terraform configuration creates a dedicated service principal with read-only
access to Databricks system billing tables via Unity Catalog.

---

## Overview

The setup creates a service principal that provides:

- Access to `system.billing.usage` and `system.billing.list_prices`
- Access to `system.compute` tables (clusters, warehouses)
- Access to `system.access` and `system.lakeflow` tables
- `CAN_USE` permission on the target SQL warehouse

All access is read-only. Nothing is created or modified in your Databricks
environment beyond the service principal and its grants.

---

## What Gets Created

| Resource | Purpose |
|---|---|
| Service principal | Identity used by DigiUsher to query billing data |
| OAuth client secret | Credential for the service principal |
| Warehouse permission (`CAN_USE`) | Allows the SP to run queries |
| Unity Catalog grants | Read access to system billing, compute, access, lakeflow schemas |

---

## Prerequisites

- **Terraform** — version 1.3 or higher
- **Python 3** with `databricks-sql-connector`, `databricks-sdk`, `pandas`, `pyarrow`
- A Databricks **personal access token** with `all APIs` scope (see below)
- **Account admin and Workspace admin** rights (needed to create service principals and assign grants)

### Create a Personal Access Token

This token is used once by Terraform to bootstrap the setup. It is not stored
after `terraform apply` completes.

1. Go to your workspace → top-right user icon → **Settings** → **Developer** → **Access tokens**
2. Click **Generate new token**
3. Set a name (e.g. `terraform-setup-digiusher`) and lifetime
4. Under **Scope**, select **All APIs**
5. Copy the token immediately — it won't be shown again

---

## Find Your Configuration Values

You need four values before running Terraform:

| Variable | Where to find it |
|---|---|
| `workspace_host` | Your workspace URL, e.g. `abc-123.cloud.databricks.com` (no `https://`) |
| `databricks_account_id` | [accounts.cloud.databricks.com](https://accounts.cloud.databricks.com) → top-right corner |
| `warehouse_id` | SQL warehouse → **Connection details** → last segment of the HTTP path |

**Finding your values from the workspace URL:**

```
https://abcdef123456.cloud.databricks.com/?o=7474643746181715&account_id=2188c8e7-...
                                            └─────────────── not needed  └─ account_id
└─ workspace_host ───────────────────────┘
```

**Finding your warehouse ID:**

The HTTP path in Connection details looks like `/sql/1.0/warehouses/abc123def456`.
The `warehouse_id` is the last segment: `abc123def456`.

---

## Deployment

### 1. Create `terraform.tfvars`

```hcl
databricks_account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
workspace_host        = "your-workspace.cloud.databricks.com"
warehouse_id          = "abc123def456"
```

### 2. Export your PAT

```bash
export TF_VAR_databricks_token="XXXXXXXXXXXXXXXXXXXX"
```

### 3. Initialise Terraform

```bash
terraform init
```

### 4. Review changes

```bash
terraform plan
```

Confirm it will create: 1 service principal, 1 secret, 1 warehouse permission,
and 11 Unity Catalog grants. Nothing else.

### 5. Apply

```bash
terraform apply
```

### 6. Save the credentials

```bash
terraform output client_id
terraform output -raw client_secret
terraform output http_path
terraform output workspace_hostname
```

These four values are what DigiUsher needs. You can also capture them together:

```bash
echo "DATABRICKS_HOST=$(terraform output -raw workspace_hostname)"
echo "DATABRICKS_HTTP_PATH=$(terraform output -raw http_path)"
echo "DATABRICKS_CLIENT_ID=$(terraform output -raw client_id)"
echo "DATABRICKS_CLIENT_SECRET=$(terraform output -raw client_secret)"
```

### 7. Verify the integration

```bash
export DATABRICKS_HOST="$(terraform output -raw workspace_hostname)"
export DATABRICKS_HTTP_PATH="$(terraform output -raw http_path)"
export DATABRICKS_CLIENT_ID="$(terraform output -raw client_id)"
export DATABRICKS_CLIENT_SECRET="$(terraform output -raw client_secret)"

python3 verify_exports.py
```

A successful run looks like:

```
═══════════════════════════════════════════════════════
  Databricks Billing Integration — Verification
═══════════════════════════════════════════════════════

  Host:       your-workspace.cloud.databricks.com
  Warehouse:  /sql/1.0/warehouses/abc123def456
  Client ID:  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

───────────────────────────────────────────────────────
  1 / 4  —  Authentication
───────────────────────────────────────────────────────
   ✅  Connected to warehouse with service principal OAuth

───────────────────────────────────────────────────────
  2 / 4  —  System catalog access
───────────────────────────────────────────────────────
   ✅  system.billing visible
   ✅  system.compute visible
   ✅  system.access visible
   ✅  system.lakeflow visible

───────────────────────────────────────────────────────
  3 / 4  —  Billing tables
───────────────────────────────────────────────────────
   ✅  system.billing.usage  (1,234,567 rows)
   ✅  system.billing.list_prices  (4,321 rows)

───────────────────────────────────────────────────────
  4 / 4  —  Data availability by month
───────────────────────────────────────────────────────

   Month         Records          Units
   ────────────  ──────────  ──────────────
   2026-06         123,456       9,876.5
   2026-05         234,567      18,432.1
   ...

   ✅  Data is current (latest month: 2026-06)

═══════════════════════════════════════════════════════
  ✅  All checks passed (4/4) — integration is ready.
═══════════════════════════════════════════════════════
```

---

## DigiUsher Configuration

After deployment, provide DigiUsher with these four values:

| Key | Source |
|---|---|
| `DATABRICKS_HOST` | `terraform output -raw workspace_hostname` |
| `DATABRICKS_HTTP_PATH` | `terraform output -raw http_path` |
| `DATABRICKS_CLIENT_ID` | `terraform output -raw client_id` |
| `DATABRICKS_CLIENT_SECRET` | `terraform output -raw client_secret` |

---

## Files

| File | Purpose |
|---|---|
| `main.tf` | Provider, service principal, secret, warehouse permission |
| `terraform.tfvars` | Account specific variables |
| `verify_setup.py` | Verify connectivity and billing data availability |

---

## Troubleshooting

**`Provided access token does not have required scopes`**
Your PAT was created with specific scopes. Regenerate it with **All APIs** selected.

**`cannot create service principal`**
Your PAT may not have admin privileges. Confirm your user account is a
account and workspace admin under Settings → Users.

**`system.billing not visible` in verification**
The Unity Catalog grants may not have propagated yet. Wait a few minutes and re-run
`verify_exports.py`. If it persists, run `terraform apply` again to confirm all
grants were applied successfully.

**`No billing records found`**
System tables can take 24–48 hours to populate on a newly enabled workspace.
Check [docs.databricks.com](https://docs.databricks.com/aws/en/admin/system-tables/)
to confirm system tables are enabled for your account.

---

Questions? Contact us at [support@digiusher.com](mailto:support@digiusher.com)
