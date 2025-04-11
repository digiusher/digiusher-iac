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
