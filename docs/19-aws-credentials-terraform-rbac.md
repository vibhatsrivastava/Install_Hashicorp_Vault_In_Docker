# Use Case 19 — AWS Credentials for Terraform Developers

## Overview

This guide grants Terraform developers read-only access to static AWS
credentials stored in Vault:

1. Mount a KV v2 engine for AWS credentials.
2. Store a development credential set.
3. Create a scoped read-only policy and attach it to an identity group.
4. Add a Userpass developer and verify the access boundary.

> **Note:** KV v2 distributes existing static AWS credentials. Prefer Vault's
> AWS secrets engine for production workflows that can use dynamic, rotated
> credentials.

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

## Section 1 — Mount and Populate the AWS KV Engine

```text
docker compose exec -e VAULT_TOKEN vault vault secrets enable -path=aws_credentials kv-v2
docker compose exec -e VAULT_TOKEN vault vault secrets list
```

Store a credential set at `aws_credentials/terraform/dev`.

> **Note:** This command exposes credential values to shell history. Use an
> approved secret-delivery workflow rather than command-line credentials in
> production.

```text
docker compose exec -e VAULT_TOKEN vault vault kv put aws_credentials/terraform/dev access_key_id=<aws-access-key-id> secret_access_key=<aws-secret-access-key> region=us-east-1
docker compose exec -e VAULT_TOKEN vault vault kv get aws_credentials/terraform/dev
```

## Section 2 — Create the Read-Only Policy

Create `aws-readonly-policy.hcl` locally:

```hcl
path "sys/internal/ui/mounts/aws_credentials/*" {
  capabilities = ["read"]
}

path "aws_credentials/data/*" {
  capabilities = ["read"]
}

path "aws_credentials/metadata/" {
  capabilities = ["list"]
}

path "aws_credentials/metadata/*" {
  capabilities = ["list", "read"]
}
```

Copy, apply, and inspect the policy:

```text
docker cp aws-readonly-policy.hcl hashicorp-vault:/tmp/aws-readonly-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy write aws-readonly /tmp/aws-readonly-policy.hcl
docker compose exec -e VAULT_TOKEN vault vault policy read aws-readonly
```

## Section 3 — Create the Terraform Developers Group

```text
docker compose exec -e VAULT_TOKEN vault vault write identity/group name=terraform-developers type=internal policies=aws-readonly
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/terraform-developers
```

## Section 4 — Create and Add a Developer

Create the `terraform-dev1` login. Replace the example password with a strong
value.

```text
docker compose exec -e VAULT_TOKEN vault vault write auth/userpass/users/terraform-dev1 password=<developer-password>
docker compose exec -e VAULT_TOKEN vault vault write identity/entity name=terraform-dev1 metadata=team=terraform
docker compose exec -e VAULT_TOKEN vault vault read identity/entity/name/terraform-dev1
```

Copy the entity ID, find the Userpass accessor, create the alias, and add the
entity to the group:

```text
docker compose exec -e VAULT_TOKEN vault vault auth list
docker compose exec -e VAULT_TOKEN vault vault write identity/entity-alias name=terraform-dev1 canonical_id=<entity-id> mount_accessor=<userpass-accessor>
docker compose exec -e VAULT_TOKEN vault vault write identity/group/name/terraform-developers member_entity_ids=<entity-id>
docker compose exec -e VAULT_TOKEN vault vault read identity/group/name/terraform-developers
```

## Testing

### T.1 — Authenticate as the Developer

```text
docker compose exec vault vault login -method=userpass username=terraform-dev1 password=<developer-password>
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
docker compose exec -e VAULT_TOKEN vault vault kv get aws_credentials/terraform/dev
docker compose exec -e VAULT_TOKEN vault vault kv list aws_credentials/
```

Expected: the developer can read the credential set and list allowed paths.

### T.3 — Verify Writes Are Denied

```text
docker compose exec -e VAULT_TOKEN vault vault kv put aws_credentials/terraform/dev access_key_id=FAKE secret_access_key=FAKE
docker compose exec -e VAULT_TOKEN vault vault kv delete aws_credentials/terraform/dev
docker compose exec -e VAULT_TOKEN vault vault secrets list
```

Expected: each command returns `Code: 403`.

## Summary

| Step | What was configured |
|---|---|
| 1 | KV v2 engine at `aws_credentials` and a development credential set |
| 2 | `aws-readonly` policy with read/list-only permissions |
| 3 | `terraform-developers` group with inherited policy |
| 4 | Userpass developer identity and group membership |
| Testing | Read/list access allowed; writes, deletes, and system access denied |