# DigiUsher OCI Permissions Reference

This document lists all IAM policies created by the DigiUsher onboarding stack.

## Policy: digiusher-cost-report-access

Grants read-only access to FOCUS cost and usage reports.

```
define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq
endorse group digiusher-finops-group to read objects in tenancy usage-report
Allow group digiusher-finops-group to read usage-report in tenancy
Allow group digiusher-finops-group to read usage-budgets in tenancy
```

| Statement | Purpose |
|-----------|---------|
| `endorse ... read objects in tenancy usage-report` | Cross-tenancy access to Oracle's billing Object Storage bucket containing FOCUS cost reports |
| `read usage-report` | Access to the Usage API for programmatic cost queries |
| `read usage-budgets` | Access to budget data and alerts |

## Policy: digiusher-resource-discovery (Optional)

Grants read-only access to all resources for inventory.

```
Allow group digiusher-finops-group to read all-resources in tenancy
```

| Statement | Purpose |
|-----------|---------|
| `read all-resources` | Cross-compartment resource discovery via Resource Search API. Enables complete resource inventory for optimization. |

**OCI permission verb levels**: `inspect` < `read` < `use` < `manage`. DigiUsher uses `read` which includes `inspect` plus the ability to read resource contents, but cannot modify anything.

## Policy: digiusher-metrics-access (Optional)

Grants read-only access to monitoring metrics.

```
Allow group digiusher-finops-group to read metrics in tenancy
```

| Statement | Purpose |
|-----------|---------|
| `read metrics` | Access to OCI Monitoring service data including CPU, network, disk I/O metrics across all compartments |

### Available Metric Namespaces

| Namespace | Metrics |
|-----------|---------|
| `oci_computeagent` | CPU utilization, disk I/O, network bytes, memory (requires Cloud Agent) |
| `oci_blockstore` | Volume read/write throughput, IOPS, latency |
| `oci_vcn` | VCN ingress/egress bytes, packets, security list drops |
| `oci_lbaas` | Load balancer connections, bandwidth, HTTP responses |
| `oci_autonomous_database` | CPU utilization, storage, sessions, SQL execution time |
| `oci_database` | DB time, CPU, I/O, sessions |
| `oci_objectstorage` | Bucket size, object count, request counts |
| `oci_functionsaas` | Function invocations, duration, errors |
