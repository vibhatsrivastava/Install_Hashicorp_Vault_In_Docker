# Use Case 19 — AWS Credentials for Terraform Developers

## Overview

This guide walks through a secure workflow for storing static AWS credentials
in Vault and granting Terraform developers read-only access via group-based
policy:

1. Enable a **KV v2 secrets engine** at the path `aws_credentials` to hold
   AWS access key IDs and secret access keys.
2. Store the **AWS credentials** as a versioned KV secret.
3. Define a **read-only policy** (`aws-readonly`) scoped exclusively to the
   `aws_credentials` path — developers can read credentials but cannot modify
   or delete them.
4. Create an **internal identity group** (`terraform-developers`) and attach
   the `aws-readonly` policy so every group member inherits it automatically.
5. Create **Userpass users** and link them to the group.
6. Run **testing steps** to confirm developers can retrieve credentials and
   that write/delete operations are correctly blocked.

> **Note:** This guide uses **KV v2** instead of the **AWS secrets engine** to
> demonstrate secure distribution of existing, long-lived IAM credentials.
> The KV v2 approach is appropriate when you have pre-existing AWS access keys
> that need to be shared securely among a team, or when your workflow does not
> support dynamic credential rotation. The **AWS secrets engine** generates
> ephemeral credentials on-demand with automatic rotation and revocation, but
> requires Vault to have AWS API access to create and destroy IAM resources.
> Use KV v2 for simple credential sharing and legacy workflows; use the AWS
> secrets engine for production workloads requiring automatic lifecycle
> management. For ephemeral, auto-rotated credentials see
> [09-aws-azure-dynamic-credentials.md](./09-aws-azure-dynamic-credentials.md).

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Vault container running | `docker compose up -d` (see top-level README) |
| Vault initialised and unsealed | You have the **Initial Root Token** and at least one **unseal key** |
| Docker host terminal access | Commands below use `docker exec` — no local Vault CLI needed |
| Userpass auth method enabled | Follow [01-userpass-auth-machine-credentials.md](./01-userpass-auth-machine-credentials.md) Section 1 if not already done |

Export these variables in your shell before running any command in this guide:

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>
```

Verify Vault is reachable and unsealed:

```bash
docker exec -it hashicorp-vault vault status
```

Expected output contains `Sealed: false`. If Vault is sealed, unseal it first:

```bash
docker exec -it hashicorp-vault vault operator unseal <unseal-key>
```

---

## Section 1 — Enable the KV v2 Secrets Engine

Enable a KV version 2 secrets engine at the custom path `aws_credentials`.
Using a dedicated path keeps AWS credentials isolated from other secrets and
makes policy scoping straightforward.

```bash
docker exec -it hashicorp-vault vault secrets enable \
  -path=aws_credentials \
  kv-v2
```

Verify the mount is listed:

```bash
docker exec -it hashicorp-vault vault secrets list
```

Expected output includes a row for `aws_credentials/`.

> **KV v2 path structure:** The engine stores data under
> `aws_credentials/data/<secret-path>` and metadata under
> `aws_credentials/metadata/<secret-path>`. Policies must reference these
> internal sub-paths explicitly (see Section 3).

---

## Section 2 — Store the AWS Credentials

Store the AWS access key ID and secret access key under a meaningful secret
name. The example below uses the path `aws_credentials/terraform/dev` to
indicate these are the credentials used by the Terraform development workflow.

Replace `<AWS_ACCESS_KEY_ID>` and `<AWS_SECRET_ACCESS_KEY>` with the actual
values from your AWS IAM console.

> **Security note:** Passing secrets directly on the command line risks
> exposing them in shell history. Use the stdin (`-`) pattern instead:
>
> ```bash
> printf 'access_key_id=<AWS_ACCESS_KEY_ID>\nsecret_access_key=<AWS_SECRET_ACCESS_KEY>\nregion=us-east-1\n' \
>   | docker exec -i hashicorp-vault vault kv put aws_credentials/terraform/dev -
> ```

Standard form (suitable for non-interactive scripting where history is not a
concern):

```bash
docker exec -it hashicorp-vault vault kv put aws_credentials/terraform/dev \
  access_key_id=<AWS_ACCESS_KEY_ID> \
  secret_access_key=<AWS_SECRET_ACCESS_KEY> \
  region=us-east-1
```

Verify the secret was written:

```bash
docker exec -it hashicorp-vault vault kv get aws_credentials/terraform/dev
```

Expected output shows the `access_key_id`, `secret_access_key`, and `region`
fields with a `version: 1` header.

> **Adding multiple environments:** Store credentials for different AWS
> accounts or environments at separate paths, for example
> `aws_credentials/terraform/prod` or `aws_credentials/terraform/staging`.
> The policy in Section 3 covers all sub-paths under `aws_credentials/`.

---

## Section 3 — Create the Read-Only Policy

The `aws-readonly` policy grants Terraform developers permission to **read**
AWS credentials but blocks any writes, patches, deletions, or listing of
secret metadata. This follows the principle of least privilege.

### 3.1 — Write the policy HCL file

Create the file `aws-readonly-policy.hcl` on your Docker host:

```hcl
# aws-readonly-policy.hcl
#
# Grants read-only access to all secrets stored under the
# aws_credentials KV v2 engine.
#
# Developers can retrieve AWS credentials for use in Terraform
# but cannot create, modify, or delete any secrets.

# Allow the `vault kv` CLI to perform its preflight mount-type lookup.
# Without this, every `vault kv get` command returns a 403 preflight
# error before it even reaches the secret path.
path "sys/internal/ui/mounts/aws_credentials/*" {
  capabilities = ["read"]
}

# Read secret data at any path under the engine.
# Covers: vault kv get aws_credentials/<any-path>
path "aws_credentials/data/*" {
  capabilities = ["read"]
}

# List secret names at the engine root and under sub-paths.
# Allows developers to discover which credential sets exist
# without being able to read the values themselves from this path.
path "aws_credentials/metadata/" {
  capabilities = ["list"]
}

path "aws_credentials/metadata/*" {
  capabilities = ["list", "read"]
}
```

> **Note:** `create`, `update`, `delete`, and `patch` capabilities are
> intentionally omitted. Any attempt to write or delete a secret will return
> `Code: 403. Errors: 1 error occurred: permission denied`.

### 3.2 — Upload the policy to Vault

Copy the file into the container and write it to Vault:

```bash
docker cp aws-readonly-policy.hcl hashicorp-vault:/tmp/aws-readonly-policy.hcl

docker exec -it hashicorp-vault vault policy write aws-readonly \
  /tmp/aws-readonly-policy.hcl
```

Verify the policy was stored and inspect its contents:

```bash
docker exec -it hashicorp-vault vault policy read aws-readonly
```

Expected output shows the HCL you wrote above with no additional capabilities
beyond `read` and `list`.

---

## Section 4 — Create the Identity Group and Attach the Policy

An **internal identity group** decouples policy assignment from individual
users. When you add a user to the group they automatically inherit the
`aws-readonly` policy — no per-user policy assignment is needed.

### 4.1 — Create the group

```bash
docker exec -it hashicorp-vault vault write identity/group \
  name=terraform-developers \
  type=internal \
  policies=aws-readonly
```

Verify the group was created and that the policy is attached:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/terraform-developers
```

Expected output shows:
- `name: terraform-developers`
- `policies: [aws-readonly]`
- `member_entity_ids: []` (empty until users are added in Section 5)

---

## Section 5 — Create Users and Add Them to the Group

Each Terraform developer needs a Userpass login linked to a Vault identity
entity so that Vault can track group membership.

### 5.1 — Create the Userpass account

Create a Userpass login for each developer. The example uses `terraform-dev1`.

> **Security note:** Avoid passing passwords on the command line. Use stdin:
>
> ```bash
> echo 'password=<developer-password>' \
>   | docker exec -i hashicorp-vault vault write auth/userpass/users/terraform-dev1 -
> ```

```bash
docker exec -it hashicorp-vault vault write auth/userpass/users/terraform-dev1 \
  password=<developer-password>
```

Verify the account exists:

```bash
docker exec -it hashicorp-vault vault read auth/userpass/users/terraform-dev1
```

### 5.2 — Create the identity entity for the developer

```bash
docker exec -it hashicorp-vault vault write identity/entity \
  name=terraform-dev1 \
  metadata=team=terraform
```

Note the `id` field in the output — this is the **entity ID** needed in step
5.4. You can also retrieve it later:

```bash
docker exec -it hashicorp-vault vault read identity/entity/name/terraform-dev1
```

### 5.3 — Create an entity alias linking the Userpass login to the entity

First retrieve the Userpass auth mount accessor:

```bash
docker exec -it hashicorp-vault vault auth list
```

Copy the **Accessor** value from the `userpass/` row (format:
`auth_userpass_xxxxxxxx`).

Then create the alias:

```bash
docker exec -it hashicorp-vault vault write identity/entity-alias \
  name=terraform-dev1 \
  canonical_id=<entity-id-from-5.2> \
  mount_accessor=<userpass-accessor>
```

### 5.4 — Add the entity to the terraform-developers group

```bash
docker exec -it hashicorp-vault vault write identity/group/name/terraform-developers \
  member_entity_ids=<entity-id-from-5.2>
```

> **Adding more developers:** Retrieve each developer's entity ID and provide
> all IDs as a comma-separated list:
>
> ```bash
> docker exec -it hashicorp-vault vault write identity/group/name/terraform-developers \
>   member_entity_ids=<id1>,<id2>,<id3>
> ```

Verify the group now lists the entity:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/terraform-developers
```

The `member_entity_ids` field should contain the entity ID added above.

---

## Testing

These steps verify the complete workflow: a developer can authenticate,
retrieve AWS credentials, and is correctly blocked from modifying them.

### T.1 — Log in as the developer (positive test)

```bash
docker exec -it hashicorp-vault vault login \
  -method=userpass \
  username=terraform-dev1 \
  password=<developer-password>
```

Expected: a token is issued. Export it:

```bash
export DEV_TOKEN=<token-from-login-output>
```

### T.2 — Read the AWS credentials (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv get aws_credentials/terraform/dev
```

Expected: output shows the `access_key_id`, `secret_access_key`, and `region`
fields. The developer can copy these values directly into their local
`~/.aws/credentials` file or Terraform provider configuration.

Example Terraform provider block using the retrieved credentials:

```hcl
# terraform/provider.tf
provider "aws" {
  region     = "us-east-1"
  access_key = "<access_key_id from Vault>"
  secret_key = "<secret_access_key from Vault>"
}
```

### T.3 — List available credential paths (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv list aws_credentials/
```

Expected: output lists the `terraform/` prefix, confirming the developer can
discover which credential sets are available.

### T.4 — Attempt to overwrite credentials (negative test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv put aws_credentials/terraform/dev \
  access_key_id=FAKEKEYID \
  secret_access_key=FAKESECRET
```

Expected: `Code: 403. Errors: 1 error occurred: permission denied` — the
`aws-readonly` policy does not grant `create` or `update` capabilities.

### T.5 — Attempt to delete credentials (negative test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv delete aws_credentials/terraform/dev
```

Expected: `Code: 403. Errors: 1 error occurred: permission denied` — the
`aws-readonly` policy does not grant `delete` capability.

### T.6 — Attempt to access an unrelated path (negative test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault secrets list
```

Expected: `Code: 403. Errors: 1 error occurred: permission denied` — the
developer token has no access to `sys/` paths outside the KV engine.

---

## Summary

| Step | Command area | What was configured |
|------|-------------|---------------------|
| 1 | `vault secrets enable` | KV v2 engine mounted at `aws_credentials/` to hold AWS credential pairs |
| 2 | `vault kv put` | AWS access key, secret key, and region stored at `aws_credentials/terraform/dev` |
| 3 | `vault policy write` | `aws-readonly` policy — read-only access to `aws_credentials/data/*`; write and delete capabilities intentionally absent |
| 4 | `vault write identity/group` | `terraform-developers` internal group created with `aws-readonly` policy attached |
| 5 | `vault write identity/entity` + `entity-alias` + group update | Developer user (`terraform-dev1`) created in Userpass, linked to a Vault identity entity, and added to the `terraform-developers` group |
| T | Testing | Confirmed credential retrieval works and write/delete operations are correctly blocked with `403 permission denied` |
