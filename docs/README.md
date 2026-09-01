# Vault Documentation

This folder contains operational guides and use-case walkthroughs for the
HashiCorp Vault instance deployed via Docker Compose in this repository.

---

## How to Use This Documentation

Each document is self-contained and covers a specific operational topic.
Start with the **Prerequisites** section inside each guide — every guide
assumes Vault is already running and unsealed (see the top-level
[README](../README.md) for installation and initialisation steps).

Commands throughout all guides use `docker compose exec` against the `vault`
service. You can run them from Bash/zsh on Linux or macOS and PowerShell on
Windows without installing the Vault CLI locally.

Set the root token in your host shell. Authenticated commands explicitly
forward it into the container with `docker compose exec -e VAULT_TOKEN`.

```bash
export VAULT_TOKEN=<your-root-token>
```

```powershell
$env:VAULT_TOKEN = "<your-root-token>"
```

When a guide asks you to authenticate, replace `<root-token>` with the Initial
Root Token you saved during `vault operator init`.

---

## Document Index

| # | File | Summary |
|---|------|---------|
| 01 | [01-userpass-auth-machine-credentials.md](./01-userpass-auth-machine-credentials.md) | Enable the Userpass auth method, create a local user, organise users into an internal group, provision a KV v2 secrets engine at `machine_credentials`, define a least-privilege policy, attach the policy to the group, and validate the full workflow with testing steps. |
| 19 | [19-aws-credentials-terraform-rbac.md](./19-aws-credentials-terraform-rbac.md) | Store static AWS access key and secret key in a KV v2 engine at `aws_credentials`, define a read-only policy, create a `terraform-developers` internal group with the policy attached, add developer users to the group, and verify that members can retrieve credentials for Terraform while write and delete operations are blocked. |
| 20 | [20-vmware-credentials-terraform-rbac.md](./20-vmware-credentials-terraform-rbac.md) | Store vCenter/vSphere connection credentials in a KV v2 engine at `vmware_credentials`, define a read-only policy, create a `terraform-vsphere-developers` internal group with the policy attached, add developer users to the group, and verify that members can retrieve credentials for Terraform while write and delete operations are blocked. |
| — | [use-case-pipeline.md](./use-case-pipeline.md) | Catalogue of all suggested scenario-based use cases (guides 02–20) covering auth methods, secrets engines, operations, governance, and real-world application patterns — with a recommended implementation order. |

---

## Adding New Documents

1. Select the next planned, currently unwritten file in
   [use-case-pipeline.md](./use-case-pipeline.md).
2. Add a row to the **Document Index** table above with the file link and a
   one-sentence summary.
3. Follow the same section structure used in existing guides (Overview →
   Prerequisites → Steps → Testing) for consistency.
