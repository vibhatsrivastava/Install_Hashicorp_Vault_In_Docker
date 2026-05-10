# Use Case 20 — VMware Credentials for Terraform Developers

## Overview

This guide walks through a secure workflow for storing VMware vCenter/vSphere
connection credentials in Vault and granting Terraform developers read-only
access via group-based policy:

1. Enable a **KV v2 secrets engine** at the path `vmware_credentials` to hold
   vCenter hostname, username, and password.
2. Store the **vSphere credentials** as a versioned KV secret.
3. Define a **read-only policy** (`vmware-readonly`) scoped exclusively to the
   `vmware_credentials` path — developers can read credentials but cannot
   modify or delete them.
4. Create an **internal identity group** (`terraform-vsphere-developers`) and
   attach the `vmware-readonly` policy so every group member inherits it
   automatically.
5. Create **Userpass users** and link them to the group.
6. Run **testing steps** to confirm developers can retrieve credentials and
   that write/delete operations are correctly blocked.

> **Note:** This guide stores *static* vCenter credentials in KV v2. Vault
> does not provide a native dynamic secrets engine for VMware vSphere, so the
> KV v2 approach with a read-only policy and group-based access control is the
> recommended pattern for securely distributing vSphere credentials to
> Terraform developers.

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

Enable a KV version 2 secrets engine at the custom path `vmware_credentials`.
Using a dedicated path keeps vSphere credentials isolated from other secrets
engines and makes policy scoping straightforward.

```bash
docker exec -it hashicorp-vault vault secrets enable \
  -path=vmware_credentials \
  kv-v2
```

Verify the mount is listed:

```bash
docker exec -it hashicorp-vault vault secrets list
```

Expected output includes a row for `vmware_credentials/`.

> **KV v2 path structure:** The engine stores data under
> `vmware_credentials/data/<secret-path>` and metadata under
> `vmware_credentials/metadata/<secret-path>`. Policies must reference these
> internal sub-paths explicitly (see Section 3).

---

## Section 2 — Store the VMware vCenter Credentials

Store the vCenter hostname, service account username, and password under a
meaningful secret name. The example below uses the path
`vmware_credentials/vsphere/dev` to indicate these are the credentials for
the development vSphere environment.

Replace the placeholder values with the actual details from your vCenter
instance.

> **Security note:** Avoid passing the vCenter password directly on the
> command line — it may appear in shell history. Use the stdin (`-`) pattern
> instead:
>
> ```bash
> printf 'vcenter_server=<VCENTER_HOSTNAME>\nvsphere_user=<VSPHERE_USERNAME>\nvsphere_password=<VSPHERE_PASSWORD>\nallow_unverified_ssl=true\n' \
>   | docker exec -i hashicorp-vault vault kv put vmware_credentials/vsphere/dev -
> ```

Standard form (suitable for non-interactive scripting where history is not a
concern):

```bash
docker exec -it hashicorp-vault vault kv put vmware_credentials/vsphere/dev \
  vcenter_server=<VCENTER_HOSTNAME> \
  vsphere_user=<VSPHERE_USERNAME> \
  vsphere_password=<VSPHERE_PASSWORD> \
  allow_unverified_ssl=true
```

Verify the secret was written:

```bash
docker exec -it hashicorp-vault vault kv get vmware_credentials/vsphere/dev
```

Expected output shows the `vcenter_server`, `vsphere_user`, `vsphere_password`,
and `allow_unverified_ssl` fields with a `version: 1` header.

> **Adding multiple environments:** Store credentials for separate vCenter
> instances or vSphere environments at distinct paths, for example
> `vmware_credentials/vsphere/prod` or `vmware_credentials/vsphere/staging`.
> The policy in Section 3 covers all sub-paths under `vmware_credentials/`.

---

## Section 3 — Create the Read-Only Policy

The `vmware-readonly` policy grants Terraform developers permission to **read**
vSphere credentials but blocks any writes, patches, deletions, or metadata
modifications. This follows the principle of least privilege.

### 3.1 — Write the policy HCL file

Create the file `vmware-readonly-policy.hcl` on your Docker host:

```hcl
# vmware-readonly-policy.hcl
#
# Grants read-only access to all secrets stored under the
# vmware_credentials KV v2 engine.
#
# Developers can retrieve vCenter/vSphere credentials for use in Terraform
# but cannot create, modify, or delete any secrets.

# Allow the `vault kv` CLI to perform its preflight mount-type lookup.
# Without this, every `vault kv get` command returns a 403 preflight
# error before it even reaches the secret path.
path "sys/internal/ui/mounts/vmware_credentials/*" {
  capabilities = ["read"]
}

# Read secret data at any path under the engine.
# Covers: vault kv get vmware_credentials/<any-path>
path "vmware_credentials/data/*" {
  capabilities = ["read"]
}

# List secret names at the engine root and under sub-paths.
# Allows developers to discover which credential sets exist
# without being able to read the values themselves from this path.
path "vmware_credentials/metadata/" {
  capabilities = ["list"]
}

path "vmware_credentials/metadata/*" {
  capabilities = ["list", "read"]
}
```

> **Note:** `create`, `update`, `delete`, and `patch` capabilities are
> intentionally omitted. Any attempt to write or delete a secret will return
> `Code: 403. Errors: 1 error occurred: permission denied`.

### 3.2 — Upload the policy to Vault

Copy the file into the container and write it to Vault:

```bash
docker cp vmware-readonly-policy.hcl hashicorp-vault:/tmp/vmware-readonly-policy.hcl

docker exec -it hashicorp-vault vault policy write vmware-readonly \
  /tmp/vmware-readonly-policy.hcl
```

Verify the policy was stored and inspect its contents:

```bash
docker exec -it hashicorp-vault vault policy read vmware-readonly
```

Expected output shows the HCL above with no capabilities beyond `read` and
`list`.

---

## Section 4 — Create the Identity Group and Attach the Policy

An **internal identity group** decouples policy assignment from individual
users. When you add a developer to the group they automatically inherit the
`vmware-readonly` policy — no per-user policy assignment is needed.

### 4.1 — Create the group

```bash
docker exec -it hashicorp-vault vault write identity/group \
  name=terraform-vsphere-developers \
  type=internal \
  policies=vmware-readonly
```

Verify the group was created and that the policy is attached:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/terraform-vsphere-developers
```

Expected output shows:
- `name: terraform-vsphere-developers`
- `policies: [vmware-readonly]`
- `member_entity_ids: []` (empty until developers are added in Section 5)

---

## Section 5 — Create Users and Add Them to the Group

Each Terraform developer needs a Userpass login linked to a Vault identity
entity so that Vault can track group membership.

### 5.1 — Create the Userpass account

Create a Userpass login for each developer. The example below uses
`vsphere-dev1`.

> **Security note:** Avoid passing passwords on the command line. Use stdin:
>
> ```bash
> echo 'password=<developer-password>' \
>   | docker exec -i hashicorp-vault vault write auth/userpass/users/vsphere-dev1 -
> ```

```bash
docker exec -it hashicorp-vault vault write auth/userpass/users/vsphere-dev1 \
  password=<developer-password>
```

Verify the account exists:

```bash
docker exec -it hashicorp-vault vault read auth/userpass/users/vsphere-dev1
```

### 5.2 — Create the identity entity for the developer

```bash
docker exec -it hashicorp-vault vault write identity/entity \
  name=vsphere-dev1 \
  metadata=team=terraform
```

Note the `id` field in the output — this is the **entity ID** needed in steps
5.3 and 5.4. You can also retrieve it later:

```bash
docker exec -it hashicorp-vault vault read identity/entity/name/vsphere-dev1
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
  name=vsphere-dev1 \
  canonical_id=<entity-id-from-5.2> \
  mount_accessor=<userpass-accessor>
```

### 5.4 — Add the entity to the terraform-vsphere-developers group

```bash
docker exec -it hashicorp-vault vault write identity/group/name/terraform-vsphere-developers \
  member_entity_ids=<entity-id-from-5.2>
```

> **Adding more developers:** Retrieve each developer's entity ID and supply
> all IDs as a comma-separated list:
>
> ```bash
> docker exec -it hashicorp-vault vault write identity/group/name/terraform-vsphere-developers \
>   member_entity_ids=<id1>,<id2>,<id3>
> ```

Verify the group now lists the entity:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/terraform-vsphere-developers
```

The `member_entity_ids` field should contain the entity ID added above.

---

## Testing

These steps verify the complete workflow: a developer can authenticate,
retrieve vSphere credentials, and is correctly blocked from modifying them.

### T.1 — Log in as the developer (positive test)

```bash
docker exec -it hashicorp-vault vault login \
  -method=userpass \
  username=vsphere-dev1 \
  password=<developer-password>
```

Expected: a token is issued. Export it:

```bash
export DEV_TOKEN=<token-from-login-output>
```

### T.2 — Read the vSphere credentials (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv get vmware_credentials/vsphere/dev
```

Expected: output shows the `vcenter_server`, `vsphere_user`,
`vsphere_password`, and `allow_unverified_ssl` fields. The developer can use
these values directly in their Terraform provider configuration:

```hcl
# terraform/provider.tf
provider "vsphere" {
  vsphere_server       = "<vcenter_server from Vault>"
  user                 = "<vsphere_user from Vault>"
  password             = "<vsphere_password from Vault>"
  allow_unverified_ssl = true
}
```

### T.3 — List available credential paths (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv list vmware_credentials/
```

Expected: output lists the `vsphere/` prefix, confirming the developer can
discover which credential sets are available.

### T.4 — Attempt to overwrite credentials (negative test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv put vmware_credentials/vsphere/dev \
  vsphere_password=hackedpassword
```

Expected: `Code: 403. Errors: 1 error occurred: permission denied` — the
`vmware-readonly` policy does not grant `create` or `update` capabilities.

### T.5 — Attempt to delete credentials (negative test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$DEV_TOKEN \
  vault kv delete vmware_credentials/vsphere/dev
```

Expected: `Code: 403. Errors: 1 error occurred: permission denied` — the
`vmware-readonly` policy does not grant `delete` capability.

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
| 1 | `vault secrets enable` | KV v2 engine mounted at `vmware_credentials/` to hold vCenter/vSphere connection details |
| 2 | `vault kv put` | vCenter hostname, vSphere username, password, and SSL setting stored at `vmware_credentials/vsphere/dev` |
| 3 | `vault policy write` | `vmware-readonly` policy — read-only access to `vmware_credentials/data/*`; write and delete capabilities intentionally absent |
| 4 | `vault write identity/group` | `terraform-vsphere-developers` internal group created with `vmware-readonly` policy attached |
| 5 | `vault write identity/entity` + `entity-alias` + group update | Developer user (`vsphere-dev1`) created in Userpass, linked to a Vault identity entity, and added to the `terraform-vsphere-developers` group |
| T | Testing | Confirmed credential retrieval works and write/delete operations are correctly blocked with `403 permission denied` |
