output "digiusher_onboarding" {
  description = "Values to provide to DigiUsher. After generating an API key for the service user, enter these along with the fingerprint and private key in the DigiUsher UI."
  value = {
    tenancy_ocid = var.tenancy_ocid
    user_ocid    = oci_identity_user.digiusher.id
    region       = var.region
  }
}

output "next_steps" {
  description = "Instructions to complete onboarding."
  value       = <<-EOT
    Deployment complete. To finish onboarding:

    1. Generate an API key for the '${var.user_name}' user:
       - Go to OCI Console > Identity & Security > Users
       - Click on '${var.user_name}'
       - Under Resources, click 'API Keys' > 'Add API Key'
       - Select 'Generate API Key Pair'
       - Download the private key file and click 'Add'
       - Copy the fingerprint shown

    2. Provide the following to DigiUsher:
       - Tenancy OCID: ${var.tenancy_ocid}
       - User OCID: ${oci_identity_user.digiusher.id}
       - Region: ${var.region}
       - API Key Fingerprint: (from step 1)
       - Private Key: (contents of the downloaded PEM file)
  EOT
}
