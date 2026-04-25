# Use Case 01 — Userpass Authentication, Groups, KV Secrets & Policy Management

## Overview

This guide walks through a complete identity and secrets management workflow
using HashiCorp Vault:

1. Enable the **Userpass** auth method so that humans can authenticate with a
   username and password.
2. Create a **local user** via the Userpass method.
3. Create an **internal identity group** and attach the user to it.
4. Enable a **KV v2 secrets engine** at the path `machine_credentials`.
5. Define a **least-privilege policy** granting full CRUD access on the
   `machine_credentials` path.
6. Attach the policy to the group so that **every current and future group
   member inherits it automatically**.
7. Run **testing steps** to validate the entire workflow.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Vault container running | `docker compose up -d` (see top-level README) |
| Vault initialised and unsealed | You have the **Initial Root Token** and at least one **unseal key** |
| Docker host terminal access | Commands below use `docker exec` — no local Vault CLI needed |

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

## Section 1 — Enable the Userpass Auth Method

Userpass is a built-in Vault auth method that authenticates users with a
username/password pair. It is not enabled by default.

```bash
docker exec -it hashicorp-vault vault auth enable userpass
```

Verify the auth method is mounted:

```bash
docker exec -it hashicorp-vault vault auth list
```

Expected output includes a row for `userpass/`.

---

## Section 2 — Create a Local User

Create a user named `alice` with a password. Substitute your own values for
`<username>` and `<password>`.

```bash
docker exec -it hashicorp-vault vault write auth/userpass/users/<username> \
  password=<password>
```

**Example:**

```bash
docker exec -it hashicorp-vault vault write auth/userpass/users/alice \
  password=SuperSecret123!
```

> **Security note:** Avoid passing secrets directly on the command line in
> production — they may appear in shell history. Use the `-` flag to read from
> stdin or set the value as an environment variable:
>
> ```bash
> echo 'password=SuperSecret123!' | \
>   docker exec -i hashicorp-vault vault write auth/userpass/users/alice -
> ```

Verify the user was created:

```bash
docker exec -it hashicorp-vault vault read auth/userpass/users/alice
```

---

## Section 3 — Create a Group and Add the User

Vault's **identity system** sits above individual auth methods. The recommended
pattern is:

1. Look up the **entity** that Vault creates automatically when a user first
   logs in — or create one explicitly now.
2. Create an **internal group** and add the entity as a member.

### 3.1 — Retrieve (or create) the user's identity entity

After a user authenticates for the first time, Vault auto-creates an entity.
Since Alice has not logged in yet, create the entity manually so it is ready:

```bash
docker exec -it hashicorp-vault vault write identity/entity \
  name=alice \
  metadata=username=alice
```

Capture the entity ID from the output (look for `id`):

```bash
docker exec -it hashicorp-vault vault read identity/entity/name/alice
```

Note the value of the `id` field — you will need it in step 3.3.

### 3.2 — Create an entity alias linking the Userpass login to the entity

An **entity alias** maps the Userpass login name to the Vault identity entity.
First, retrieve the accessor for the Userpass auth mount:

```bash
docker exec -it hashicorp-vault vault auth list -format=json \
  | docker exec -i hashicorp-vault vault \
    read -format=json sys/auth
```

A simpler one-liner to get the accessor:

```bash
docker exec -it hashicorp-vault vault auth list
```

Copy the **Accessor** value from the `userpass/` row (it looks like
`auth_userpass_xxxxxxxx`).

Create the alias:

```bash
docker exec -it hashicorp-vault vault write identity/entity-alias \
  name=<username> \
  canonical_id=<entity-id> \
  mount_accessor=<userpass-accessor>
```

**Example:**

```bash
docker exec -it hashicorp-vault vault write identity/entity-alias \
  name=alice \
  canonical_id=<entity-id-from-3.1> \
  mount_accessor=auth_userpass_xxxxxxxx
```

### 3.3 — Create the internal group

```bash
docker exec -it hashicorp-vault vault write identity/group \
  name=machine-operators \
  type=internal \
  member_entity_ids=<entity-id-from-3.1>
```

Verify the group was created and contains the entity:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/machine-operators
```

The `member_entity_ids` field should list Alice's entity ID.

> **Adding more users later:** Retrieve their entity ID and update the group:
>
> ```bash
> docker exec -it hashicorp-vault vault write identity/group/name/machine-operators \
>   member_entity_ids=<id1>,<id2>
> ```

---

## Section 4 — Enable the KV v2 Secrets Engine

Enable a KV version 2 secrets engine at the custom path `machine_credentials`:

```bash
docker exec -it hashicorp-vault vault secrets enable \
  -path=machine_credentials \
  kv-v2
```

Verify the mount:

```bash
docker exec -it hashicorp-vault vault secrets list
```

Expected output includes a row for `machine_credentials/`.

> **KV v2 path structure:** Under the hood, KV v2 stores secret data under
> `machine_credentials/data/<secret-path>` and metadata under
> `machine_credentials/metadata/<secret-path>`. Policies must reference these
> internal sub-paths explicitly (see Section 5).

---

## Section 5 — Create the Policy

Create a policy file on the Docker host, then write it to Vault.

### 5.1 — Write the policy HCL file

Create the file `machine-operators-policy.hcl` on your host:

```hcl
# machine-operators-policy.hcl
#
# Grants full CRUD access to all secrets stored under the
# machine_credentials KV v2 engine.

# Read, create, update, and delete secret data
path "machine_credentials/data/*" {
  capabilities = ["create", "read", "update", "delete"]
}

# List secrets at the root of the engine
path "machine_credentials/metadata/" {
  capabilities = ["list"]
}

# List secrets under any sub-path
path "machine_credentials/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

# Allow viewing the engine configuration (required for some CLI commands)
path "machine_credentials/config" {
  capabilities = ["read"]
}
```

### 5.2 — Upload the policy to Vault

Copy the file into the container and write it:

```bash
docker cp machine-operators-policy.hcl hashicorp-vault:/tmp/machine-operators-policy.hcl

docker exec -it hashicorp-vault vault policy write machine-operators \
  /tmp/machine-operators-policy.hcl
```

Verify the policy was stored:

```bash
docker exec -it hashicorp-vault vault policy read machine-operators
```

---

## Section 6 — Attach the Policy to the Group

Attaching a policy to an **internal group** means every entity that is a member
of the group automatically receives the policy's permissions — including any
members added in the future.

```bash
docker exec -it hashicorp-vault vault write identity/group/name/machine-operators \
  policies=machine-operators
```

Verify the policy is listed on the group:

```bash
docker exec -it hashicorp-vault vault read identity/group/name/machine-operators
```

The `policies` field should show `[machine-operators]`.

---

## Section 7 — Testing Steps

These steps verify the entire workflow end-to-end: authentication, secret
CRUD operations, and policy enforcement boundaries.

### 7.1 — Log in as the new user

```bash
docker exec -it hashicorp-vault vault login \
  -method=userpass \
  username=alice \
  password=SuperSecret123!
```

Copy the **token** from the output. You will use it for the remaining tests.
Export it:

```bash
export ALICE_TOKEN=<token-from-login-output>
```

### 7.2 — Write a secret (positive test)

Write a test secret as Alice:

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv put machine_credentials/server01 \
  username=admin \
  password=ChangeMe!
```

Expected: `Success! Data written to: machine_credentials/data/server01`

### 7.3 — Read the secret back (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv get machine_credentials/server01
```

Expected: output shows the `username` and `password` fields.

### 7.4 — Update the secret (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv patch machine_credentials/server01 \
  password=NewPassword456!
```

Expected: `Success! Data patched at: machine_credentials/data/server01`

Read back to confirm the update:

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv get machine_credentials/server01
```

### 7.5 — List secrets (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv list machine_credentials/
```

Expected: output lists `server01`.

### 7.6 — Delete the secret (positive test)

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv delete machine_credentials/server01
```

Expected: `Success! Data deleted (if it existed) at: machine_credentials/data/server01`

Confirm the secret is deleted (reading it should return no data):

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault kv get machine_credentials/server01
```

Expected: `No value found at machine_credentials/data/server01`

### 7.7 — Verify policy enforcement boundary (negative test)

Attempt to access a path that Alice's policy does not cover (e.g., the `sys/`
path):

```bash
docker exec -it hashicorp-vault env VAULT_TOKEN=$ALICE_TOKEN \
  vault read sys/mounts
```

Expected: `Error reading sys/mounts: Error making API request ... Code: 403`

A `403 Forbidden` response confirms that the policy is correctly scoped — Alice
can operate only within `machine_credentials/`.

### 7.8 — Verify group policy inheritance (optional, requires a second user)

Create a second user `bob` following the same steps in Sections 2–3, adding
Bob's entity ID to the `machine-operators` group. Then log in as Bob and repeat
steps 7.2–7.6 to confirm that group membership automatically grants the
`machine-operators` policy without any per-user policy assignment.

```bash
# Create bob
docker exec -it hashicorp-vault vault write auth/userpass/users/bob \
  password=BobSecret789!

# Create bob's entity
docker exec -it hashicorp-vault vault write identity/entity \
  name=bob

# Get bob's entity ID
docker exec -it hashicorp-vault vault read identity/entity/name/bob

# Add both alice and bob to the group (replace IDs accordingly)
docker exec -it hashicorp-vault vault write identity/group/name/machine-operators \
  member_entity_ids=<alice-entity-id>,<bob-entity-id>

# Create entity alias for bob (same accessor as before)
docker exec -it hashicorp-vault vault write identity/entity-alias \
  name=bob \
  canonical_id=<bob-entity-id> \
  mount_accessor=<userpass-accessor>

# Log in as bob and test
docker exec -it hashicorp-vault vault login \
  -method=userpass \
  username=bob \
  password=BobSecret789!
```

Bob should have full CRUD access to `machine_credentials/` without any explicit
per-user policy assignment — the policy flows through the group.

---

## Summary

| Step | Command area | What was configured |
|------|-------------|---------------------|
| 1 | Auth method | `userpass` enabled at `auth/userpass/` |
| 2 | User | `alice` created under Userpass |
| 3 | Identity | Entity + alias created; added to `machine-operators` group |
| 4 | Secrets engine | KV v2 mounted at `machine_credentials/` |
| 5 | Policy | `machine-operators` policy: full CRUD on `machine_credentials/*` |
| 6 | Group policy | Policy attached to group; inherited by all members |
| 7 | Testing | Positive CRUD tests + negative boundary test passed |
