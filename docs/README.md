# Vault Documentation

This folder contains operational guides and use-case walkthroughs for the
HashiCorp Vault instance deployed via Docker Compose in this repository.

---

## How to Use This Documentation

Each document is self-contained and covers a specific operational topic.
Start with the **Prerequisites** section inside each guide — every guide
assumes Vault is already running and unsealed (see the top-level
[README](../README.md) for installation and initialisation steps).

Commands throughout all guides are written as `docker exec` calls against the
container named **`hashicorp-vault`** (as defined in `docker-compose.yml`).
You can run them from any terminal on the Docker host without installing the
Vault CLI locally.

Set the following shell variable before running any command in these guides
to avoid repeating it on every line:

```bash
export VAULT_ADDR=http://localhost:8200
```

When a guide asks you to authenticate, replace `<root-token>` with the Initial
Root Token you saved during `vault operator init`.

---

## Document Index

| # | File | Summary |
|---|------|---------|
| 01 | [01-userpass-auth-machine-credentials.md](./01-userpass-auth-machine-credentials.md) | Enable the Userpass auth method, create a local user, organise users into an internal group, provision a KV v2 secrets engine at `machine_credentials`, define a least-privilege policy, attach the policy to the group, and validate the full workflow with testing steps. |

---

## Adding New Documents

1. Create the file in this folder using the next sequential number as a prefix
   (e.g. `02-approle-auth.md`).
2. Add a row to the **Document Index** table above with the file link and a
   one-sentence summary.
3. Follow the same section structure used in existing guides (Overview →
   Prerequisites → Steps → Testing) for consistency.
