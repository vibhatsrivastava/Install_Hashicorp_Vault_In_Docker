# Use Case 01 — Userpass Authentication, Groups, KV Secrets, and Policies

## Overview

This guide configures a local Userpass user with group-based access to machine
credentials:

1. Enable Userpass authentication and create a user.
2. Create an identity entity, alias, and internal group.
3. Mount a KV v2 engine and create a least-privilege policy.
4. Attach the policy to the group and test allowed and denied operations.

## Prerequisites

| Requirement | Notes |
|---|---|
| Vault container running | `docker compose up -d`; see the top-level README |
| Vault initialized and unsealed | Root token and three unseal keys are available |
| Docker host terminal | Bash/zsh on Linux/macOS or PowerShell on Windows |

Set the root token in the host shell:

```bash
export VAULT_TOKEN=<your-root-token>
```

```powershell
$env:VAULT_TOKEN = "<your-root-token>"
```

Every authenticated command below uses `docker compose exec -e VAULT_TOKEN` to
pass this host variable to Vault. Verify the server is reachable and unsealed:

```text
docker compose exec vault vault status
docker compose exec -e VAULT_TOKEN vault vault token lookup
```

## Section 1 — Enable Userpass and Create a User

Enable the Userpass auth method:

```text
docker compose exec -e VAULT_TOKEN vault vault auth enable userpass
docker compose exec -e VAULT_TOKEN vault vault auth list
```

Create the `alice` login. Replace the example password with a strong value.

> **Note:** The command exposes the password to shell history. For production,
> use an approved secret-delivery workflow instead of placing passwords on the
> command line.

```text
docker compose exec -e VAULT_TOKEN vault vault write auth/userpass/users/alice password=<alice-password>
docker compose exec -e VAULT_TOKEN vault vault read auth/userpass/users/alice
```

## Section 2 — Create the Identity Entity and Group

Create the entity and retrieve its ID from the output:

```text
docker compose exec -e VAULT_TOKEN vault vault write identity/entity name=alice metadata=username=alice
docker compose exec -e VAULT_TOKEN vault vault read identity/entity/name/alice
```

Retrieve the Userpass accessor, then create an alias using the entity ID and
accessor values returned above:

```text
docker compose exec -e VAULT_TOKEN vault vault auth list
docker compose exec -e VAULT_TOKEN vault vault write identity/entity-alias name=alice canonical_id=<entity-id> mount_accessor=<userpass-accessor>
```

Create the group and verify it contains Alice's entity ID:

```text
docker compose exec -e VAULT_TOKEN vault vault write identity/group name=machine-operators type=internal member_entity_ids=<entity-id>
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/machine-operators
```

## Section 3 — Create the KV v2 Engine and Policy

Mount a KV v2 engine for machine credentials:

```text
docker compose exec -e VAULT_TOKEN vault vault secrets enable -path=machine_credentials kv-v2
docker compose exec -e VAULT_TOKEN vault vault secrets list
```

Create `machine-operators-policy.hcl` locally with the following content:

```hcl
path "sys/internal/ui/mounts/machine_credentials/*" {
  capabilities = ["read"]
}

path "machine_credentials/data/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "machine_credentials/metadata/" {
  capabilities = ["list"]
}

path "machine_credentials/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
```

Copy and apply the policy. `docker cp` works from PowerShell and Bash/zsh:

```text
docker cp machine-operators-policy.hcl hashicorp-vault:/tmp/machine-operators-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy write machine-operators /tmp/machine-operators-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy read machine-operators
```

## Section 4 — Attach the Policy to the Group

Attach the policy and confirm the group configuration:

```text
docker compose exec -e VAULT_TOKEN vault vault write identity/group/name/machine-operators policies=machine-operators
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/machine-operators
```

## Testing

### T.1 — Authenticate as Alice

Log in and copy the issued client token. Replace the root-token host variable
with Alice's token before running the remaining tests.

```text
docker compose exec vault vault login -method=userpass username=alice password=<alice-password>
```

```bash
export VAULT_TOKEN=<alice-token>
```

```powershell
$env:VAULT_TOKEN = "<alice-token>"
```

### T.2 — Verify credential CRUD access

```text
docker compose exec -e VAULT_TOKEN vault vault kv put machine_credentials/server01 username=admin password=<server-password>
docker compose exec -e VAULT_TOKEN vault vault kv get machine_credentials/server01
docker compose exec -e VAULT_TOKEN vault vault kv patch machine_credentials/server01 password=<new-server-password>
docker compose exec -e VAULT_TOKEN vault vault kv list machine_credentials/
docker compose exec -e VAULT_TOKEN vault vault kv delete machine_credentials/server01
```

Expected: each allowed operation succeeds.

### T.3 — Verify the policy boundary

```text
docker compose exec -e VAULT_TOKEN vault vault read sys/mounts
```

Expected: `Code: 403`, confirming that Alice cannot read unrelated system
paths.

## Summary

| Step | What was configured |
|---|---|
| 1 | Userpass authentication and the `alice` user |
| 2 | Alice's entity, alias, and `machine-operators` group |
| 3 | KV v2 at `machine_credentials` and a CRUD policy |
| 4 | Group policy inheritance |
| Testing | Allowed KV operations and a denied system-path request |