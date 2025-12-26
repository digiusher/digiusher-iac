#!/usr/bin/env python3
"""
DigiUsher Azure FOCUS Export Historical Backfill Script

Triggers FOCUS cost export runs for specific months. Use --month YYYY-MM to export
a single month, or --status to check current export status.
"""

import argparse
import sys
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import requests
import time
import json


class AzureAuthenticator:
    def __init__(self, tenant_id: str, client_id: str, client_secret: str):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.token = None
        self.token_expires = None

    def get_token(self) -> str:
        """Get or refresh Azure access token."""
        if self.token and self.token_expires and datetime.now() < self.token_expires:
            return self.token

        url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"
        data = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scope": "https://management.azure.com/.default",
        }

        response = requests.post(url, data=data, timeout=30)
        response.raise_for_status()

        token_data = response.json()
        self.token = token_data["access_token"]
        self.token_expires = datetime.now() + timedelta(
            seconds=token_data["expires_in"] - 300
        )

        return self.token


class FocusExportBackfill:
    def __init__(
        self, authenticator: AzureAuthenticator, billing_scope: str, export_name: str
    ):
        self.auth = authenticator
        self.billing_scope = billing_scope
        self.export_name = export_name
        self.base_url = "https://management.azure.com"
        self.api_version = "2025-03-01"

    def get_latest_run_status(self) -> dict:
        """Get the most recent export run status."""
        url = f"{self.base_url}{self.billing_scope}/providers/Microsoft.CostManagement/exports/{self.export_name}/runHistory"

        headers = {
            "Authorization": f"Bearer {self.auth.get_token()}",
            "Content-Type": "application/json",
        }

        try:
            response = requests.get(
                url, headers=headers, params={"api-version": self.api_version}, timeout=30
            )
        except requests.RequestException as e:
            print(f"   ⚠️  Network error checking status: {e}")
            return {"status": "Error", "error": str(e)}

        if not response.ok:
            error_msg = response.text[:200] if response.text else "No details"
            print(f"   ⚠️  Failed to get export status (HTTP {response.status_code}): {error_msg}")
            return {"status": "Error", "error": f"HTTP {response.status_code}"}

        try:
            data = response.json()
        except json.JSONDecodeError:
            print("   ⚠️  Invalid JSON response from Azure API")
            return {"status": "Error", "error": "Invalid JSON"}

        runs = data.get("value", [])
        if not runs:
            return {"status": "NoHistory"}

        # Get most recent run - data is nested under 'properties'
        latest = sorted(
            runs,
            key=lambda x: x.get("properties", {}).get("submittedTime", ""),
            reverse=True
        )[0]
        props = latest.get("properties", {})
        return {
            "status": props.get("status", "Unknown"),
            "submitted": props.get("submittedTime", ""),
            "processing_start": props.get("processingStartTime", ""),
            "processing_end": props.get("processingEndTime", ""),
            "file_name": props.get("fileName", ""),
            "start_date": props.get("startDate", ""),
            "end_date": props.get("endDate", ""),
            "execution_type": props.get("executionType", ""),
        }

    def is_export_in_progress(self) -> tuple[bool, dict]:
        """Check if an export is currently running."""
        run_info = self.get_latest_run_status()
        in_progress = run_info.get("status") in ["Queued", "InProgress"]
        return in_progress, run_info

    def execute_export_for_month(self, year: int, month: int) -> dict:
        """Execute export for a specific month."""
        # Calculate first and last day of month
        first_day = datetime(year, month, 1)
        if month == 12:
            last_day = datetime(year + 1, 1, 1) - timedelta(days=1)
        else:
            last_day = datetime(year, month + 1, 1) - timedelta(days=1)

        url = f"{self.base_url}{self.billing_scope}/providers/Microsoft.CostManagement/exports/{self.export_name}/run"

        headers = {
            "Authorization": f"Bearer {self.auth.get_token()}",
            "Content-Type": "application/json",
        }

        payload = {
            "timePeriod": {
                "from": first_day.strftime("%Y-%m-%dT00:00:00.000Z"),
                "to": last_day.strftime("%Y-%m-%dT23:59:59.999Z"),
            }
        }

        try:
            response = requests.post(
                url, headers=headers, json=payload, params={"api-version": self.api_version}, timeout=60
            )
        except requests.RequestException as e:
            return {
                "year": year,
                "month": month,
                "status_code": 0,
                "success": False,
                "response": f"Network error: {e}",
            }

        return {
            "year": year,
            "month": month,
            "status_code": response.status_code,
            "success": response.ok,
            "response": response.text if not response.ok else "Success",
        }

    def run_single_month(self, month_str: str) -> dict:
        """Run export for a single month (format: YYYY-MM)."""
        # Check if export is in progress
        in_progress, run_info = self.is_export_in_progress()

        if in_progress:
            print(f"\n⏳ An export is already in progress:")
            print(f"   Status: {run_info.get('status')}")
            print(f"   Started: {run_info.get('submitted', 'Unknown')}")
            print(f"\n   Please wait for it to complete and try again.")
            return {"success": False, "reason": "export_in_progress", "run_info": run_info}

        # Parse month
        try:
            date = datetime.strptime(month_str, "%Y-%m")
        except ValueError:
            print(f"\n❌ Invalid month format: {month_str}")
            print("   Expected format: YYYY-MM (e.g., 2024-06)")
            return {"success": False, "reason": "invalid_format"}

        year, month = date.year, date.month
        print(f"\n🚀 Triggering export for {year}-{month:02d}")
        print(f"   Billing Scope: {self.billing_scope}")
        print(f"   Export Name: {self.export_name}\n")

        result = self.execute_export_for_month(year, month)

        if result["success"]:
            print(f"✅ Export triggered successfully (HTTP {result['status_code']})")
            print(f"\n   The export is now running in the background.")
            print(f"   Check status with: python3 verify_exports.py --storage-account <name> --container <name>")
        else:
            print(f"❌ Failed (HTTP {result['status_code']}): {result['response']}")

        return result


def get_terraform_outputs() -> dict:
    """Get values from terraform outputs."""
    import subprocess

    outputs = {}

    # Get onboarding values
    try:
        result = subprocess.run(
            ["terraform", "output", "-json", "digiusher_onboarding"],
            capture_output=True,
            text=True,
            check=True
        )
        outputs.update(json.loads(result.stdout))
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get terraform output: {e.stderr}")
        sys.exit(1)

    # Get billing_scope and export_name separately
    for key in ["billing_scope", "export_name"]:
        try:
            result = subprocess.run(
                ["terraform", "output", "-raw", key],
                capture_output=True,
                text=True,
                check=True
            )
            outputs[key] = result.stdout.strip()
        except subprocess.CalledProcessError:
            print(f"❌ Failed to get terraform output: {key}")
            sys.exit(1)

    return outputs


def main():
    parser = argparse.ArgumentParser(
        description="Trigger FOCUS cost export for a specific month",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Using terraform output (easiest)
  python3 backfill_historical_data.py --from-terraform --month 2024-06
  python3 backfill_historical_data.py --from-terraform --status

  # Using explicit credentials
  python3 backfill_historical_data.py --month 2024-06 \\
    --tenant-id <tenant> --client-id <client> --client-secret <secret> \\
    --billing-scope <scope> --export-name <name>

  # For multiple months, run once per month:
  for m in 2024-{01..06}; do
    python3 backfill_historical_data.py --from-terraform --month $m
    sleep 300  # Wait 5 minutes between exports
  done
        """,
    )

    parser.add_argument(
        "--from-terraform", action="store_true",
        help="Read credentials from terraform output"
    )
    parser.add_argument("--tenant-id", help="Azure Tenant ID")
    parser.add_argument("--client-id", help="Service Principal Client ID")
    parser.add_argument("--client-secret", help="Service Principal Client Secret")
    parser.add_argument(
        "--billing-scope",
        help="Billing scope (e.g., /providers/Microsoft.Billing/billingAccounts/123456)",
    )
    parser.add_argument("--export-name", help="Name of the export")
    parser.add_argument(
        "--month",
        help="Month to export in YYYY-MM format (e.g., 2024-06)",
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Check current export status only (no export triggered)",
    )

    args = parser.parse_args()

    if not args.month and not args.status:
        parser.error("Either --month or --status is required")

    # Get credentials
    if args.from_terraform:
        print("📥 Reading credentials from terraform output...")
        outputs = get_terraform_outputs()

        required_keys = ["tenant_id", "application_id", "client_secret", "billing_scope", "export_name"]
        missing = [k for k in required_keys if k not in outputs or not outputs[k]]
        if missing:
            print(f"❌ Missing required terraform outputs: {', '.join(missing)}")
            print("   Run 'terraform apply' first to create the export configuration.")
            sys.exit(1)

        tenant_id = outputs["tenant_id"]
        client_id = outputs["application_id"]
        client_secret = outputs["client_secret"]
        billing_scope = outputs["billing_scope"]
        export_name = outputs["export_name"]
    else:
        if not all([args.tenant_id, args.client_id, args.billing_scope, args.export_name]):
            parser.error("Either --from-terraform or all credential arguments are required")
        tenant_id = args.tenant_id
        client_id = args.client_id
        billing_scope = args.billing_scope
        export_name = args.export_name

        # Get client secret
        client_secret = args.client_secret
        if not client_secret:
            import getpass
            client_secret = getpass.getpass("Enter Client Secret: ")

    # Authenticate
    print("🔐 Authenticating with Azure...")
    auth = AzureAuthenticator(tenant_id, client_id, client_secret)

    try:
        auth.get_token()
        print("✅ Authentication successful")
    except Exception as e:
        print(f"❌ Authentication failed: {str(e)}")
        sys.exit(1)

    backfill = FocusExportBackfill(auth, billing_scope, export_name)

    # Status check only
    if args.status:
        in_progress, run_info = backfill.is_export_in_progress()
        status = run_info.get('status', 'Unknown')

        print(f"\n📊 Export Status: {status}")

        if status != "Unknown":
            # Format dates nicely
            submitted = run_info.get('submitted', '')
            if submitted:
                submitted = submitted[:19].replace('T', ' ')  # Trim to readable format

            start_date = run_info.get('start_date', '')[:10] if run_info.get('start_date') else ''
            end_date = run_info.get('end_date', '')[:10] if run_info.get('end_date') else ''
            period = f"{start_date} to {end_date}" if start_date and end_date else "N/A"

            exec_type = run_info.get('execution_type', 'N/A')

            print(f"   Period: {period}")
            print(f"   Type: {exec_type}")
            print(f"   Submitted: {submitted}")

            # Only show processing times if they're real values
            proc_start = run_info.get('processing_start', '')
            proc_end = run_info.get('processing_end', '')
            if proc_start and not proc_start.startswith('0001'):
                print(f"   Processing Start: {proc_start[:19].replace('T', ' ')}")
            if proc_end and not proc_end.startswith('0001'):
                print(f"   Processing End: {proc_end[:19].replace('T', ' ')}")

            file_name = run_info.get('file_name', '')
            if file_name:
                print(f"   Output: {file_name}")

        if in_progress:
            print(f"\n   ⏳ Export is in progress. Wait before triggering another.")
        else:
            print(f"\n   ✅ No export in progress. Ready for new export.")
        sys.exit(0)

    # Run export for single month
    result = backfill.run_single_month(args.month)
    sys.exit(0 if result.get("success") else 1)


if __name__ == "__main__":
    main()
