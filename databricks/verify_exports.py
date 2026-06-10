#!/usr/bin/env python3
"""
Verify Databricks billing integration for DigiUsher.

Checks connectivity, auth, and billing data availability using
the service principal credentials created by Terraform.

Usage:
  # Credentials via env vars (recommended)
  export DATABRICKS_HOST="your-workspace.cloud.databricks.com"
  export DATABRICKS_HTTP_PATH="/sql/1.0/warehouses/your-warehouse-id"
  export DATABRICKS_CLIENT_ID="your-sp-client-id"
  export DATABRICKS_CLIENT_SECRET="your-sp-client-secret"
  python3 verify_exports.py

  # Or pass credentials directly
  python3 verify_exports.py \
    --host your-workspace.cloud.databricks.com \
    --http-path /sql/1.0/warehouses/your-warehouse-id \
    --client-id your-sp-client-id \
    --client-secret your-sp-client-secret
"""

import argparse
import os
import sys
from datetime import datetime

missing = []
try:
    from databricks import sql as dbsql
except ImportError:
    missing.append("databricks-sql-connector")
try:
    from databricks.sdk.core import Config, oauth_service_principal
except ImportError:
    missing.append("databricks-sdk")

if missing:
    print(f"\n❌ Missing packages: {', '.join(missing)}")
    print(f"   Run: pip install {' '.join(missing)}")
    sys.exit(1)


def ok(msg):
    print(f"   ✅  {msg}")


def fail(msg):
    print(f"   ❌  {msg}")


def info(msg):
    print(f"   ℹ️   {msg}")


def section(title):
    print(f"\n{'─' * 55}\n  {title}\n{'─' * 55}")


def credential_provider(host, client_id, client_secret):
    config = Config(
        host=f"https://{host}",
        client_id=client_id,
        client_secret=client_secret,
    )
    return oauth_service_principal(config)


def run_check(label, fn):
    """Run a check function, return its result or None on failure."""
    try:
        result = fn()
        return result
    except Exception as e:
        fail(f"{label}: {e}")
        return None


def check_auth(host, http_path, client_id, client_secret):
    section("1 / 4  —  Authentication")
    conn = None
    try:
        conn = dbsql.connect(
            server_hostname=host,
            http_path=http_path,
            credentials_provider=lambda: credential_provider(
                host, client_id, client_secret
            ),
        )
        ok("Connected to warehouse with service principal OAuth")
        return conn
    except Exception as e:
        fail(f"Could not connect: {e}")
        return None


def check_system_catalog(conn):
    section("2 / 4  —  System catalog access")
    with conn.cursor() as cur:
        cur.execute("SHOW SCHEMAS IN system")
        schemas = [row[0] for row in cur.fetchall()]
    accessible = [
        s for s in ["billing", "compute", "access", "lakeflow"] if s in schemas
    ]
    missing_s = [
        s for s in ["billing", "compute", "access", "lakeflow"] if s not in schemas
    ]
    for s in accessible:
        ok(f"system.{s} visible")
    for s in missing_s:
        fail(f"system.{s} not visible — check Unity Catalog grants")
    return len(missing_s) == 0


def check_billing_tables(conn):
    section("3 / 4  —  Billing tables")
    tables = {
        "system.billing.usage": "SELECT COUNT(*) FROM system.billing.usage",
        "system.billing.list_prices": "SELECT COUNT(*) FROM system.billing.list_prices",
    }
    all_ok = True
    for table, query in tables.items():
        try:
            with conn.cursor() as cur:
                cur.execute(query)
                count = cur.fetchone()[0]
            ok(f"{table}  ({count:,} rows)")
        except Exception as e:
            fail(f"{table} — {e}")
            all_ok = False
    return all_ok


def check_data_freshness(conn):
    section("4 / 4  —  Data availability by month")
    query = """
        SELECT
            date_trunc('month', usage_date) AS month,
            COUNT(*)                        AS records,
            SUM(usage_quantity)             AS total_units
        FROM system.billing.usage
        GROUP BY 1
        ORDER BY 1 DESC
        LIMIT 13
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    if not rows:
        fail("No billing records found")
        return False

    print(f"\n   {'Month':<12}  {'Records':>10}  {'Units':>14}")
    print(f"   {'─' * 12}  {'─' * 10}  {'─' * 14}")
    for row in rows:
        month = str(row[0])[:7]
        recs = f"{row[1]:,}"
        units = f"{float(row[2]):,.1f}" if row[2] else "—"
        print(f"   {month:<12}  {recs:>10}  {units:>14}")

    latest = str(rows[0][0])[:7]
    current_month = datetime.today().strftime("%Y-%m")
    if latest >= current_month:
        ok(f"Data is current (latest month: {latest})")
    else:
        info(f"Latest month in warehouse: {latest} — may lag by a few days")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Verify Databricks billing integration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Credentials can be passed as flags or set as environment variables:
  DATABRICKS_HOST, DATABRICKS_HTTP_PATH,
  DATABRICKS_CLIENT_ID, DATABRICKS_CLIENT_SECRET
        """,
    )
    parser.add_argument("--host", default=os.environ.get("DATABRICKS_HOST"))
    parser.add_argument("--http-path", default=os.environ.get("DATABRICKS_HTTP_PATH"))
    parser.add_argument("--client-id", default=os.environ.get("DATABRICKS_CLIENT_ID"))
    parser.add_argument(
        "--client-secret", default=os.environ.get("DATABRICKS_CLIENT_SECRET")
    )
    args = parser.parse_args()

    missing_args = [
        k
        for k, v in {
            "--host": args.host,
            "--http-path": args.http_path,
            "--client-id": args.client_id,
            "--client-secret": args.client_secret,
        }.items()
        if not v
    ]

    if missing_args:
        print(f"\n❌ Missing credentials: {', '.join(missing_args)}")
        print("   Set them as env vars or pass as flags. Run with --help for details.")
        sys.exit(1)

    print("\n" + "═" * 55)
    print("  Databricks Billing Integration — Verification")
    print("═" * 55)
    print(f"\n  Host:       {args.host}")
    print(f"  Warehouse:  {args.http_path}")
    print(f"  Client ID:  {args.client_id}")

    passed = 0
    total = 4

    conn = check_auth(args.host, args.http_path, args.client_id, args.client_secret)
    if conn is None:
        print(f"\n{'═' * 55}")
        print("  ❌  Auth failed — stopping. Check credentials and warehouse ID.")
        print("═" * 55 + "\n")
        sys.exit(1)
    passed += 1

    try:
        if run_check("System catalog access", lambda: check_system_catalog(conn)):
            passed += 1
        if run_check("Billing tables", lambda: check_billing_tables(conn)):
            passed += 1
        if run_check("Data availability", lambda: check_data_freshness(conn)):
            passed += 1
    finally:
        conn.close()

    print(f"\n{'═' * 55}")
    if passed == total:
        print(f"  ✅  All checks passed ({passed}/{total}) — integration is ready.")
    else:
        print(f"  ⚠️   {passed}/{total} checks passed — review failures above.")
    print("═" * 55 + "\n")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
