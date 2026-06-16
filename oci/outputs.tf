output "digiusher_onboarding" {
  description = "Non-sensitive values to provide to DigiUsher (along with the private key from digiusher_private_key)."
  value = {
    tenancy_ocid    = var.tenancy_ocid
    user_ocid       = oci_identity_user.digiusher.id
    region          = var.region
    key_fingerprint = oci_identity_api_key.digiusher.fingerprint
  }
}

output "digiusher_private_key" {
  description = "Private API signing key (PEM) for the service user. Retrieve with: terraform output -raw digiusher_private_key"
  value       = tls_private_key.digiusher.private_key_pem
  sensitive   = true
}

output "next_steps" {
  description = "Instructions to complete onboarding."
  value       = <<-EOT
    Deployment complete. The API signing key was generated automatically -
    no manual Console steps are needed.

    Provide the following to DigiUsher:
      - Tenancy OCID:        ${var.tenancy_ocid}
      - User OCID:           ${oci_identity_user.digiusher.id}
      - Region:              ${var.region}
      - API Key Fingerprint: ${oci_identity_api_key.digiusher.fingerprint}
      - Private Key (PEM):   run 'terraform output -raw digiusher_private_key'
                             (in OCI Resource Manager, copy it from the
                             'digiusher_private_key' output on the Outputs tab)
  EOT
}
