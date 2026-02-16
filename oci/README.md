# DigiUsher OCI Integration Setup

This guide provides complete instructions for setting up DigiUsher's OCI cost monitoring integration. The Terraform configuration creates a read-only service user with the minimum permissions needed for cost analytics and optimization recommendations.

## Overview

Our solution creates an OCI IAM user with policies that provide:

- **FOCUS cost report access** via Oracle's cross-tenancy Object Storage bucket
- **Resource inventory** across the entire tenancy via Resource Search API
- **Monitoring metrics** (CPU, network, disk) for optimization recommendations

### What Gets Created

1. **IAM Group**: `digiusher-finops-group`
2. **IAM User**: `digiusher-service-user` (added to the group)
3. **IAM Policies**:
   - Cost and usage report access (cross-tenancy endorse to Oracle's billing bucket)
   - Resource discovery (read all resources in tenancy)
   - Metrics access (read monitoring data in tenancy)

### Benefits

- **Native FOCUS format** - OCI generates FOCUS cost reports automatically, no export configuration needed
- **No storage setup required** - cost reports are stored in Oracle's bucket, not yours
- **Read-only by default** - all policies grant read/inspect access only
- **One-click deploy** via OCI Resource Manager

## Prerequisites

- OCI tenancy with administrator access (to create IAM users and policies)
- Your tenancy OCID (find it under Administration > Tenancy Details in the OCI Console)

---

## Quick Start

### Option A: One-Click Deploy via OCI Resource Manager

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/digiusher/digiusher-iac/releases/latest/download/oci-stack.zip)

1. Click the button above (you'll be redirected to the OCI Console)
2. Log in to your OCI tenancy
3. Review the pre-filled configuration and adjust if needed
4. Click **Create** to deploy the stack
5. Wait for the stack to complete (~2 minutes)
6. Continue to [Post-Deployment: Generate API Key](#post-deployment-generate-api-key)

### Option B: Local Terraform

```bash
cd oci/

# Initialize Terraform
terraform init

# Review what will be created
terraform plan \
  -var="tenancy_ocid=ocid1.tenancy.oc1..your-tenancy-ocid" \
  -var="region=us-ashburn-1"

# Deploy
terraform apply \
  -var="tenancy_ocid=ocid1.tenancy.oc1..your-tenancy-ocid" \
  -var="region=us-ashburn-1"
```

> **Note**: When running Terraform locally, you must be authenticated to OCI. See [OCI Terraform Provider Authentication](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformproviderconfiguration.htm) for options.

---

## Post-Deployment: Generate API Key

After deploying the stack, you need to generate an API key for the service user. This step cannot be automated and must be done manually in the OCI Console.

### Steps

1. Go to **OCI Console** > **Identity & Security** > **Users**
2. Click on **digiusher-service-user** (or the name you configured)
3. Under **Resources** (left sidebar), click **API Keys**
4. Click **Add API Key**
5. Select **Generate API Key Pair**
6. Click **Download Private Key** and save the `.pem` file securely
7. Click **Add**
8. Note the **Fingerprint** displayed (e.g. `ab:cd:ef:12:34:...`)

> **Important**: The private key is only shown once. Store it securely - you will need to provide it to DigiUsher.

---

## Provide Credentials to DigiUsher

After generating the API key, provide these 5 values in the DigiUsher UI:

| Value | Where to Find |
|-------|---------------|
| **Tenancy OCID** | Terraform output or OCI Console > Administration > Tenancy Details |
| **User OCID** | Terraform output or OCI Console > Identity > Users > digiusher-service-user |
| **Region** | Your tenancy's home region (e.g. `us-ashburn-1`) |
| **API Key Fingerprint** | Displayed after adding the API key (step 8 above) |
| **Private Key (PEM)** | Contents of the downloaded `.pem` file |

---

## Verification

To confirm the setup is working, you can verify in the OCI Console:

1. **User exists**: Identity & Security > Users > `digiusher-service-user`
2. **Group exists**: Identity & Security > Groups > `digiusher-finops-group`
3. **Policies exist**: Identity & Security > Policies > look for `digiusher-*`
4. **API key is active**: Click on the user > API Keys > verify fingerprint is listed

DigiUsher will also verify connectivity when you enter the credentials.

---

## Permissions Reference

### Cost and Usage Reports

```
define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq
endorse group digiusher-finops-group to read objects in tenancy usage-report
Allow group digiusher-finops-group to read usage-report in tenancy
Allow group digiusher-finops-group to read usage-budgets in tenancy
```

**What this allows**: Read-only access to your FOCUS cost and usage reports stored in Oracle's billing bucket. Also provides access to budget data. This is the standard cross-tenancy access pattern required by Oracle for cost report access.

### Resource Discovery

```
Allow group digiusher-finops-group to read all-resources in tenancy
```

**What this allows**: Read-only access to resource metadata across all compartments. DigiUsher uses this to build a complete resource inventory for optimization recommendations. No data or configuration can be modified.

### Metrics Access

```
Allow group digiusher-finops-group to read metrics in tenancy
```

**What this allows**: Read-only access to OCI Monitoring metrics such as CPU utilization, network throughput, and disk I/O. DigiUsher uses these metrics to identify underutilized resources.

> **Note on memory metrics**: Memory metrics require the Oracle Cloud Agent with the **Compute Instance Monitoring** plugin enabled on your compute instances. This is enabled by default on most platform images but may need manual activation on custom images. See [Enabling Monitoring](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/enablingmonitoring.htm).

---

## Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `tenancy_ocid` | Yes | - | Your OCI tenancy OCID (auto-populated in ORM) |
| `region` | Yes | - | OCI home region (auto-populated in ORM) |
| `user_name` | No | `digiusher-service-user` | IAM user name |
| `group_name` | No | `digiusher-finops-group` | IAM group name |
| `enable_resource_discovery` | No | `true` | Resource inventory access |
| `enable_metrics_access` | No | `true` | Monitoring metrics access |

---

## Cleanup

To remove all DigiUsher resources from your tenancy:

### If deployed via Resource Manager

1. Go to **OCI Console** > **Developer Services** > **Resource Manager** > **Stacks**
2. Click on the DigiUsher stack
3. Click **Destroy** to remove all resources
4. Optionally click **Delete Stack** to remove the stack definition

### If deployed via local Terraform

```bash
terraform destroy \
  -var="tenancy_ocid=ocid1.tenancy.oc1..your-tenancy-ocid" \
  -var="region=us-ashburn-1"
```

> **Note**: You should also delete the API key from the user before destroying, or the destroy will handle it as part of user deletion.

---

## Troubleshooting

### "Authorization failed" during deployment

You need administrator access to create IAM users and policies. Ensure you are logged in as a tenancy administrator or a user with the `manage` verb on `users`, `groups`, and `policies` resources.

### "Policy statement is invalid"

The cross-tenancy `endorse` statement for cost reports uses a fixed Oracle tenancy OCID. If you see this error, ensure the policy statements are not being modified. The OCID `ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq` is Oracle's cost reporting tenancy and is the same for all customers.

### "User already exists"

If a user named `digiusher-service-user` already exists, either:
- Import it into Terraform state: `terraform import oci_identity_user.digiusher <user-ocid>`
- Or change the `user_name` variable to a different name

### DigiUsher reports "Unable to access cost reports"

1. Verify the `endorse` policy exists: Identity & Security > Policies > `digiusher-cost-report-access`
2. Ensure the API key fingerprint matches what's configured in DigiUsher
3. Confirm the private key PEM content was copied completely (including the `-----BEGIN` and `-----END` lines)
4. Cost reports may take up to 24 hours to appear for new tenancies

### Memory metrics not available

Memory metrics require the Oracle Cloud Agent with the Compute Instance Monitoring plugin. See [Enabling Monitoring](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/enablingmonitoring.htm) to enable it on your instances.
