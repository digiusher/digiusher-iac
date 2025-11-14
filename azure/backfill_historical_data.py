#!/usr/bin/env python3
"""
DigiUsher Azure FOCUS Export Historical Backfill Script

This script backfills historical cost data by triggering export runs for past months.
Can backfill up to 7 years (84 months) of historical data.
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

        response = requests.post(url, data=data)
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
        self.api_version = "2023-07-01-preview"

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

        response = requests.post(
            url, headers=headers, json=payload, params={"api-version": self.api_version}
        )

        return {
            "year": year,
            "month": month,
            "status_code": response.status_code,
            "success": response.status_code in [200, 202],
            "response": response.text if not response.ok else "Success",
        }

    def backfill_months(self, num_months: int, start_from: str = None) -> list:
        """Backfill specified number of months."""
        results = []

        if start_from:
            current_date = datetime.strptime(start_from, "%Y-%m")
        else:
            # Start from N months ago
            current_date = datetime.now() - relativedelta(months=num_months)

        end_date = datetime.now()

        print(
            f"\n🚀 Starting backfill from {current_date.strftime('%Y-%m')} to {end_date.strftime('%Y-%m')}"
        )
        print(f"📊 Billing Scope: {self.billing_scope}")
        print(f"📦 Export Name: {self.export_name}\n")

        month_count = 0
        while current_date < end_date:
            month_count += 1
            year = current_date.year
            month = current_date.month

            print(
                f"[{month_count}] Processing {year}-{month:02d}...", end=" ", flush=True
            )

            try:
                result = self.execute_export_for_month(year, month)
                results.append(result)

                if result["success"]:
                    print(f"✅ Success (HTTP {result['status_code']})")
                else:
                    print(
                        f"❌ Failed (HTTP {result['status_code']}): {result['response']}"
                    )

                # Rate limiting - wait 2 seconds between requests
                time.sleep(2)

            except Exception as e:
                print(f"❌ Error: {str(e)}")
                results.append(
                    {"year": year, "month": month, "success": False, "error": str(e)}
                )

            current_date += relativedelta(months=1)

        return results


def main():
    parser = argparse.ArgumentParser(
        description="Backfill historical FOCUS cost export data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Backfill last 13 months
  python3 backfill_historical_data.py --months 13

  # Backfill from specific date
  python3 backfill_historical_data.py --start-from 2023-01 --months 24

  # Backfill maximum (7 years)
  python3 backfill_historical_data.py --months 84
        """,
    )

    parser.add_argument("--tenant-id", required=True, help="Azure Tenant ID")
    parser.add_argument(
        "--client-id", required=True, help="Service Principal Client ID"
    )
    parser.add_argument(
        "--client-secret",
        help="Service Principal Client Secret (will prompt if not provided)",
    )
    parser.add_argument(
        "--billing-scope",
        required=True,
        help="Billing scope (e.g., /providers/Microsoft.Billing/billingAccounts/123456)",
    )
    parser.add_argument("--export-name", required=True, help="Name of the export")
    parser.add_argument(
        "--months",
        type=int,
        default=13,
        help="Number of months to backfill (max 84 for 7 years)",
    )
    parser.add_argument(
        "--start-from",
        help="Start month in YYYY-MM format (default: N months ago from today)",
    )
    parser.add_argument("--output", help="Output file for results (JSON format)")

    args = parser.parse_args()

    # Validate months
    if args.months < 1 or args.months > 84:
        print("❌ Error: --months must be between 1 and 84 (7 years)")
        sys.exit(1)

    # Get client secret
    client_secret = args.client_secret
    if not client_secret:
        import getpass

        client_secret = getpass.getpass("Enter Client Secret: ")

    # Authenticate
    print("🔐 Authenticating with Azure...")
    auth = AzureAuthenticator(args.tenant_id, args.client_id, client_secret)

    try:
        auth.get_token()
        print("✅ Authentication successful\n")
    except Exception as e:
        print(f"❌ Authentication failed: {str(e)}")
        sys.exit(1)

    # Execute backfill
    backfill = FocusExportBackfill(auth, args.billing_scope, args.export_name)
    results = backfill.backfill_months(args.months, args.start_from)

    # Summary
    success_count = sum(1 for r in results if r.get("success"))
    failed_count = len(results) - success_count

    print(f"\n" + "=" * 60)
    print(f"📊 BACKFILL SUMMARY")
    print(f"=" * 60)
    print(f"✅ Successful: {success_count}")
    print(f"❌ Failed: {failed_count}")
    print(f"📝 Total: {len(results)}")
    print(f"=" * 60)

    # Save results if requested
    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Results saved to {args.output}")

    # Exit with error code if any failed
    sys.exit(0 if failed_count == 0 else 1)


if __name__ == "__main__":
    main()
