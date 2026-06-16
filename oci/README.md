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
4. **API signing key**: an RSA key pair generated for the service user, with the public half
   registered as an API key. The private key is exposed as a Terraform output.

### Benefits

- **Native FOCUS format** - OCI generates FOCUS cost reports automatically, no export configuration needed
- **No storage setup required** - cost reports are stored in Oracle's bucket, not yours
- **Read-only by default** - all policies grant read/inspect access only
- **No manual key step** - the API signing key is generated as part of the deployment
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
6. Open the stack's **Application information** / **Outputs** tab and copy the values from
   `digiusher_onboarding` and `digiusher_private_key` (click to reveal the masked private key)
7. Continue to [Provide Credentials to DigiUsher](#provide-credentials-to-digiusher)

### Option B: Scripted Deploy via ORM (`onboard.sh`)

Prefer the command line? With the [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
configured (plus `jq` and `zip`), `onboard.sh` runs the same Resource Manager deployment from
your terminal — no Terraform install needed, and state stays managed by Oracle.

```bash
cd oci/
./onboard.sh
```

The script prompts for your tenancy OCID, region, and service-user email (auto-filling the
first two from `~/.oci/config`), runs the ORM apply job, then prints the five credential values
and writes the private key to `digiusher-oci-private-key.pem`.

Using a named CLI profile? Pass `--profile <name>` (or set `OCI_CLI_PROFILE`). To tear down:
`./onboard.sh --destroy`.

> Both options deploy through OCI Resource Manager, so Terraform state — including the
> generated private key — is stored in Oracle's managed backend, never on your machine.

---

## Provide Credentials to DigiUsher

The API signing key is created automatically by the deployment — there are no manual Console
steps. Provide these 5 values in the DigiUsher UI:

| Value | Where to Find |
|-------|---------------|
| **Tenancy OCID** | `digiusher_onboarding.tenancy_ocid` output |
| **User OCID** | `digiusher_onboarding.user_ocid` output |
| **Region** | `digiusher_onboarding.region` output |
| **API Key Fingerprint** | `digiusher_onboarding.key_fingerprint` output |
| **Private Key (PEM)** | `digiusher_private_key` output — the ORM stack **Outputs** tab, or the file written by `onboard.sh` |

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
| `user_email` | Yes | - | Email for the service user (e.g. `digiusher-svc@yourcompany.com`) |
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

### If deployed via `onboard.sh`

```bash
./onboard.sh --destroy
```

Destroying removes the user, group, policies, and the API key together.

---

## Key Management

The API signing key pair is generated as part of the deployment, so the private key is stored
in the Resource Manager stack's Terraform state — in Oracle's managed backend, not on your
machine. Restrict who can access the stack and its state.

To rotate the key, run `./onboard.sh --destroy` followed by `./onboard.sh` (or destroy and
recreate the stack in the Console). This issues a fresh key pair; supply the new private key
and fingerprint to DigiUsher.

---

## Troubleshooting

### "Authorization failed" during deployment

You need administrator access to create IAM users and policies. Ensure you are logged in as a tenancy administrator or a user with the `manage` verb on `users`, `groups`, and `policies` resources.

### "Policy statement is invalid"

The cross-tenancy `endorse` statement for cost reports uses a fixed Oracle tenancy OCID. If you see this error, ensure the policy statements are not being modified. The OCID `ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq` is Oracle's cost reporting tenancy and is the same for all customers.

### "User already exists"

If a user named `digiusher-service-user` already exists, set the **Service User Name** variable
(`user_name`) to a different value when deploying the stack.

### DigiUsher reports "Unable to access cost reports"

1. Verify the `endorse` policy exists: Identity & Security > Policies > `digiusher-cost-report-access`
2. Ensure the API key fingerprint matches what's configured in DigiUsher
3. Confirm the private key PEM content was copied completely (including the `-----BEGIN` and `-----END` lines)
4. Cost reports may take up to 24 hours to appear for new tenancies

### Memory metrics not available

Memory metrics require the Oracle Cloud Agent with the Compute Instance Monitoring plugin. See [Enabling Monitoring](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/enablingmonitoring.htm) to enable it on your instances.
