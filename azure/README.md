# DigiUsher Azure AD Application Creation

This README provides step-by-step instructions on how to create a Azure AD applications across multiple Azure subscriptions using our provided templates tailored to your needs.

## Prerequisites

Before you begin, ensure you have:

- Azure CLI installed and authenticated.
- Terraform installed on your local machine. 

## Instructions

1. **Download the Templates**:

  Clone this repository or download the Terraform Script `azure_configuration.tf` to get started.

2. **Populate the `subscriptions.tfvars` file with your Azure subscription IDs**:

```
subscription_ids = [
  "your-subscription-id-1",
  "your-subscription-id-2",
  # Add more subscription IDs as needed
]
```

**Note**: Make sure to grant Contributor role to the user (you log in through az cli) for every subscription ID specified in the subscriptions.tfvars file.


3. **Initialize the Terraform working directory**:

```
terraform init
```

4. **Review the changes Terraform plans to make**:

```
terraform plan -var-file="subscriptions.tfvars"
```

5. **Apply the Terraform changes to create Azure AD applications and service principals**:

```
terraform apply -var-file="subscriptions.tfvars"
```

6. **Once the deployment is complete, retrieve the application information**:

```
terraform output -json app_info > output.json
```

## Output

The `app_info` output contains the following details for each Azure AD application deployed:

- Subscription ID
- Application ID
- Tenant ID
- Application Secret (sensitive)

## Error Scenarios

**Authorization Error**
If you encounter an error like the following:

```
Error: loading Role Definition List: unexpected status 403 (403 Forbidden) with error: AuthorizationFailed: 
```

Make sure to grant Contributor role to the user (you log in through az cli) for every subscription ID specified in the subscriptions.tfvars file.
