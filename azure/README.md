# DigiUsher Azure AD Application Creation

This README provides step-by-step instructions on how to create a single Azure AD application that can access multiple Azure subscriptions using our provided Terraform template.

## Overview

Our solution creates a single Azure AD application with a service principal that has Reader access across all subscriptions in your Azure tenant. This approach:
- Simplifies credential management
- Automatically discovers all accessible subscriptions
- Provides consistent access levels across subscriptions
- Reduces maintenance overhead

## Prerequisites

Before you begin, ensure you have:

- Azure CLI installed and authenticated
- Terraform installed on your local machine (version 1.0.0 or higher)
- Permissions to create applications in Azure AD
- At least Reader access to your Azure subscriptions
- Note: If using `az cli` you might need to temporarily elevate access for assigning the Reservation Reader permission. The process is [documented here](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)

## Instructions

1. **Configure Azure Variables**:

Create a `terraform.tfvars` file with your Azure details:

```hcl
subscription_id = "your-primary-subscription-id"
tenant_id       = "your-tenant-id"
```

2. **Initialize Terraform**:

```bash
terraform init
```

3. **Review the Planned Changes**:

```bash
terraform plan -var-file="terraform.tfvars"
```

4. **Apply the Configuration**:

```bash
terraform apply -var-file="terraform.tfvars"
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

## Security Considerations

- The application is granted Reader access across all discovered subscriptions
- The application is granted Reservation Reader access at the tenant root scope for managing Azure Reservations
- Store the output.json file securely
- Consider using Azure Key Vault for secret management
- Implement regular credential rotation
- Monitor service principal activity through Azure Activity Logs

## Error Scenarios

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
