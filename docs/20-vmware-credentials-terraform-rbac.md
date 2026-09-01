# Use Case 20 — VMware Credentials for Terraform Developers

## Overview

This guide gives Terraform vSphere developers read-only access to static
vCenter credentials stored in Vault:

1. Mount a KV v2 engine for vSphere credentials.
2. Store a vCenter credential set.
3. Create a read-only policy and attach it to an identity group.
4. Add a Userpass developer and verify policy enforcement.

> **Note:** Vault has no native dynamic vSphere secrets engine. Use a scoped
> KV v2 policy and rotate the stored service-account credential regularly.

## Prerequisites

| Requirement | Notes |
|---|---|
| Vault running and unsealed | See the top-level README |
| Root token | Required to configure the engine, policy, and identity group |
| Userpass enabled | Complete Use Case 01 Section 1 first |

```bash
export VAULT_TOKEN=<your-root-token>
```

```powershell
$env:VAULT_TOKEN = "<your-root-token>"
```

```text
docker compose exec vault vault status
docker compose exec -e VAULT_TOKEN vault vault token lookup
```

## Section 1 — Mount and Populate the VMware KV Engine

```text
docker compose exec -e VAULT_TOKEN vault vault secrets enable -path=vmware_credentials kv-v2
docker compose exec -e VAULT_TOKEN vault vault secrets list
```

Store a vCenter credential set at `vmware_credentials/vsphere/dev`.

> **Note:** This command exposes the vCenter password to shell history. Use an
> approved secret-delivery workflow rather than command-line credentials in
> production.

```text
docker compose exec -e VAULT_TOKEN vault vault kv put vmware_credentials/vsphere/dev vcenter_server=<vcenter-hostname> vsphere_user=<vsphere-username> vsphere_password=<vsphere-password> allow_unverified_ssl=true
docker compose exec -e VAULT_TOKEN vault vault kv get vmware_credentials/vsphere/dev
```

## Section 2 — Create the Read-Only Policy

Create `vmware-readonly-policy.hcl` locally:

```hcl
path "sys/internal/ui/mounts/vmware_credentials/*" {
  capabilities = ["read"]
}

path "vmware_credentials/data/*" {
  capabilities = ["read"]
}

path "vmware_credentials/metadata/" {
  capabilities = ["list"]
}

path "vmware_credentials/metadata/*" {
  capabilities = ["list", "read"]
}
```

Copy, apply, and inspect the policy:

```text
docker cp vmware-readonly-policy.hcl hashicorp-vault:/tmp/vmware-readonly-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy write vmware-readonly /tmp/vmware-readonly-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy read vmware-readonly
```

## Section 3 — Create the vSphere Developers Group

```text
docker compose exec -e VAULT_TOKEN vault vault write identity/group name=terraform-vsphere-developers type=internal policies=vmware-readonly
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/terraform-vsphere-developers
```

## Section 4 — Create and Add a Developer

```text
docker compose exec -e VAULT_TOKEN vault vault write auth/userpass/users/vsphere-dev1 password=<developer-password>
docker compose exec -e VAULT_TOKEN vault vault write identity/entity name=vsphere-dev1 metadata=team=terraform
docker compose exec -e VAULT_TOKEN vault vault read identity/entity/name/vsphere-dev1
```

Copy the entity ID, find the Userpass accessor, create the alias, and add the
entity to the group:

```text
docker compose exec -e VAULT_TOKEN vault vault auth list
docker compose exec -e VAULT_TOKEN vault vault write identity/entity-alias name=vsphere-dev1 canonical_id=<entity-id> mount_accessor=<userpass-accessor>
docker compose exec -e VAULT_TOKEN vault vault write identity/group/name/terraform-vsphere-developers member_entity_ids=<entity-id>
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/terraform-vsphere-developers
```

## Testing

### T.1 — Authenticate as the Developer

```text
docker compose exec vault vault login -method=userpass username=vsphere-dev1 password=<developer-password>
```

Copy the issued token into the host environment:

```bash
export VAULT_TOKEN=<developer-token>
```

```powershell
$env:VAULT_TOKEN = "<developer-token>"
```

### T.2 — Read and List Credentials

```text
docker compose exec -e VAULT_TOKEN vault vault kv get vmware_credentials/vsphere/dev
docker compose exec -e VAULT_TOKEN vault vault kv list vmware_credentials/
```

Expected: the developer can read the vCenter credential set and list allowed
paths.

### T.3 — Verify Writes Are Denied

```text
docker compose exec -e VAULT_TOKEN vault vault kv put vmware_credentials/vsphere/dev vsphere_password=FAKE
docker compose exec -e VAULT_TOKEN vault vault kv delete vmware_credentials/vsphere/dev
docker compose exec -e VAULT_TOKEN vault vault secrets list
```

Expected: each command returns `Code: 403`.

## Summary

| Step | What was configured |
|---|---|
| 1 | KV v2 engine at `vmware_credentials` and a vCenter credential set |
| 2 | `vmware-readonly` policy with read/list-only permissions |
| 3 | `terraform-vsphere-developers` group with inherited policy |
| 4 | Userpass developer identity and group membership |
| Testing | Read/list access allowed; writes, deletes, and system access denied |