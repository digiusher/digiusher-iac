#!/usr/bin/env python3
"""
Verify FOCUS export status and list available months in storage.

Uses service principal authentication - no Azure CLI required.

Usage:
  # Using terraform output
  python3 verify_exports.py --from-terraform

  # Using explicit credentials
  python3 verify_exports.py \
    --tenant-id <tenant> \
    --client-id <client> \
    --client-secret <secret> \
    --subscription <sub> \
    --storage-account <account> \
    --container <container>
"""

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta
import requests


class AzureAuthenticator:
    """Authenticate with Azure using service principal."""

    def __init__(self, tenant_id: str, client_id: str, client_secret: str):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self._tokens = {}

    def get_token(self, resource: str = "https://management.azure.com/") -> str:
        """Get access token for a specific resource."""
        cache_key = resource
        cached = self._tokens.get(cache_key)
        if cached and cached["expires"] > datetime.now():
            return cached["token"]

        url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"

        # Determine scope based on resource
        if "blob.core.windows.net" in resource or "storage.azure.com" in resource:
            scope = "https://storage.azure.com/.default"
        else:
            scope = f"{resource}.default"

        data = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scope": scope,
        }

        response = requests.post(url, data=data)
        response.raise_for_status()

        token_data = response.json()
        self._tokens[cache_key] = {
            "token": token_data["access_token"],
            "expires": datetime.now() + timedelta(seconds=token_data["expires_in"] - 300)
        }

        return token_data["access_token"]


def list_blobs_rest(auth: AzureAuthenticator, storage_account: str, container: str, prefix: str = None) -> list:
    """List blobs using Azure Storage REST API."""
    token = auth.get_token("https://storage.azure.com/")

    url = f"https://{storage_account}.blob.core.windows.net/{container}"
    headers = {
        "Authorization": f"Bearer {token}",
        "x-ms-version": "2020-10-02",
    }
    params = {"restype": "container", "comp": "list"}
    if prefix:
        params["prefix"] = prefix

    blobs = []
    marker = None

    while True:
        if marker:
            params["marker"] = marker

        response = requests.get(url, headers=headers, params=params)

        if response.status_code == 404:
            print(f"   ❌ Container '{container}' not found")
            return []
        elif response.status_code == 403:
            print(f"   ❌ Access denied - check service principal permissions")
            return []
        elif not response.ok:
            print(f"   ❌ Error: {response.status_code} - {response.text[:200]}")
            return []

        # Parse XML response
        import xml.etree.ElementTree as ET
        root = ET.fromstring(response.content)

        for blob in root.findall(".//Blob"):
            name = blob.find("Name").text
            props = blob.find("Properties")
            size = int(props.find("Content-Length").text) if props.find("Content-Length") is not None else 0
            modified = props.find("Last-Modified").text if props.find("Last-Modified") is not None else ""

            blobs.append({
                "name": name,
                "size": size,
                "modified": modified
            })

        # Check for continuation
        next_marker = root.find("NextMarker")
        if next_marker is not None and next_marker.text:
            marker = next_marker.text
        else:
            break

    return blobs


def list_export_months(auth: AzureAuthenticator, storage_account: str, container: str, export_root_path: str = None) -> dict:
    """List all months available in the export container."""
    path_display = f"{storage_account}/{container}"
    if export_root_path:
        path_display += f"/{export_root_path}"
    print(f"\n📦 Scanning storage: {path_display}")

    blobs = list_blobs_rest(auth, storage_account, container, prefix=export_root_path)

    if not blobs:
        return {}

    print(f"   Found {len(blobs)} blobs")

    # Parse blob paths to extract months
    # Expected path: {export_root_path}/{export_name}/YYYYMMDD-YYYYMMDD/...
    months = defaultdict(lambda: {"files": 0, "size_mb": 0, "latest": None})
    date_pattern = re.compile(r"/(\d{8})-(\d{8})/")

    for blob in blobs:
        name = blob.get("name", "")
        size = blob.get("size", 0)
        modified = blob.get("modified", "")

        match = date_pattern.search(name)
        if match:
            start_date = match.group(1)
            # Extract YYYY-MM from start date
            month_key = f"{start_date[:4]}-{start_date[4:6]}"
            months[month_key]["files"] += 1
            months[month_key]["size_mb"] += size / (1024 * 1024)

            if not months[month_key]["latest"] or modified > months[month_key]["latest"]:
                months[month_key]["latest"] = modified

    return dict(months)


def print_month_summary(months: dict):
    """Print a summary of available months."""
    if not months:
        print("\n   No export data found in storage")
        return

    print(f"\n📅 Available months ({len(months)} total):\n")
    print(f"   {'Month':<10} {'Files':<8} {'Size (MB)':<12} {'Last Updated'}")
    print(f"   {'-'*10} {'-'*8} {'-'*12} {'-'*20}")

    for month in sorted(months.keys(), reverse=True):
        data = months[month]
        latest = data["latest"][:16] if data["latest"] else "Unknown"
        print(f"   {month:<10} {data['files']:<8} {data['size_mb']:<12.2f} {latest}")

    # Summary stats
    total_files = sum(m["files"] for m in months.values())
    total_size = sum(m["size_mb"] for m in months.values())
    print(f"\n   Total: {total_files} files, {total_size:.2f} MB")

    # Check for gaps
    if len(months) > 1:
        sorted_months = sorted(months.keys())
        first = datetime.strptime(sorted_months[0], "%Y-%m")
        last = datetime.strptime(sorted_months[-1], "%Y-%m")
        expected = (last.year - first.year) * 12 + (last.month - first.month) + 1
        if expected > len(months):
            print(f"\n   ⚠️  Warning: {expected - len(months)} month(s) may be missing")


def get_terraform_outputs() -> dict:
    """Get onboarding values from terraform output."""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json", "digiusher_onboarding"],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get terraform output: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError:
        print("❌ Failed to parse terraform output")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Verify FOCUS export status and list available months",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Using terraform output (easiest)
  python3 verify_exports.py --from-terraform

  # Using explicit credentials
  python3 verify_exports.py \\
    --tenant-id abc123 \\
    --client-id def456 \\
    --client-secret secret \\
    --storage-account mystorageacct \\
    --container focus-exports
        """
    )
    parser.add_argument(
        "--from-terraform", action="store_true",
        help="Read credentials from terraform output (digiusher_onboarding)"
    )
    parser.add_argument("--tenant-id", help="Azure Tenant ID")
    parser.add_argument("--client-id", help="Service Principal Client ID")
    parser.add_argument("--client-secret", help="Service Principal Client Secret")
    parser.add_argument("--storage-account", help="Storage account name")
    parser.add_argument("--container", help="Container name")
    parser.add_argument("--export-root-path", help="Root folder path for exports (default: focus)")

    args = parser.parse_args()

    # Get credentials
    if args.from_terraform:
        print("📥 Reading credentials from terraform output...")
        outputs = get_terraform_outputs()
        tenant_id = outputs["tenant_id"]
        client_id = outputs["application_id"]
        client_secret = outputs["client_secret"]
        storage_account = outputs["storage_account_name"]
        container = outputs["storage_container_name"]
        export_root_path = outputs.get("export_root_path")
    else:
        if not all([args.tenant_id, args.client_id, args.client_secret,
                    args.storage_account, args.container]):
            parser.error("Either --from-terraform or all credential arguments are required")
        tenant_id = args.tenant_id
        client_id = args.client_id
        client_secret = args.client_secret
        storage_account = args.storage_account
        container = args.container
        export_root_path = args.export_root_path

    print("=" * 60)
    print("FOCUS Export Verification")
    print("=" * 60)

    # Authenticate
    print("\n🔐 Authenticating with service principal...")
    try:
        auth = AzureAuthenticator(tenant_id, client_id, client_secret)
        auth.get_token()  # Test auth
        print("   ✅ Authentication successful")
    except Exception as e:
        print(f"   ❌ Authentication failed: {e}")
        sys.exit(1)

    # List available months
    months = list_export_months(auth, storage_account, container, export_root_path)
    print_month_summary(months)

    print("\n" + "=" * 60)

    # Exit with error if no data found
    sys.exit(0 if months else 1)


if __name__ == "__main__":
    main()
