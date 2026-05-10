# Vault Use-Case Pipeline — Suggested Learning & Implementation Scenarios

This document lists recommended scenario-based use cases for learning and
practically implementing HashiCorp Vault. Each entry maps to a future guide
in this `docs/` folder, follows the same structure as existing guides
(Overview → Prerequisites → Steps → Testing), and is ordered from foundational
to advanced.

---

## Authentication & Identity

| # | File | Scenario Summary |
|---|------|-----------------|
| 02 | `02-approle-auth-cicd.md` | **AppRole Auth for CI/CD** — A CI/CD pipeline (e.g., GitHub Actions, Jenkins) authenticates to Vault without a human user. Uses Role ID + Secret ID to retrieve a short-lived token and fetch deployment secrets. |
| 03 | `03-token-ttl-management.md` | **Token Auth & TTLs** — Create short-lived, renewable tokens with explicit TTLs and max TTLs; demonstrate token revocation and orphan tokens. |
| 04 | `04-ldap-oidc-auth.md` | **LDAP / OIDC Auth** — Integrate Vault with an external identity provider (e.g., Keycloak in Docker) so corporate logins grant Vault access. |

---

## Secrets Engines

| # | File | Scenario Summary |
|---|------|-----------------|
| 05 | `05-dynamic-database-credentials.md` | **Dynamic Database Credentials** — Vault generates ephemeral PostgreSQL usernames/passwords on demand; credentials auto-expire; no shared static passwords ever touch disk. |
| 06 | `06-transit-encryption-as-a-service.md` | **Transit Secrets Engine (Encryption-as-a-Service)** — An application encrypts and decrypts data via Vault's API without ever holding encryption keys itself. |
| 07 | `07-pki-tls-certificates.md` | **PKI Secrets Engine** — Issue short-lived TLS certificates for internal services; automate certificate rotation without a full external CA infrastructure. |
| 08 | `08-ssh-secrets-engine.md` | **SSH Secrets Engine** — Sign SSH public keys so engineers get time-limited SSH access to servers without distributing static `authorized_keys` files. |
| 09 | `09-aws-azure-dynamic-credentials.md` | **AWS / Azure Dynamic Credentials** — Vault generates short-lived cloud-provider credentials scoped to specific IAM roles on demand. |

---

## Operations & Governance

| # | File | Scenario Summary |
|---|------|-----------------|
| 10 | `10-auto-unseal-transit.md` | **Auto-Unseal with Transit** — Use a second Vault instance (or cloud KMS) to auto-unseal so container restarts do not require manual unseal key entry. |
| 11 | `11-namespaces-multi-tenancy.md` | **Namespaces & Multi-Tenancy** — Isolate two teams (e.g., `team-a` and `team-b`) using namespaces so each has its own auth methods, secrets engines, and policies. |
| 12 | `12-audit-logging.md` | **Audit Logging** — Enable the file audit device, trigger a set of operations, and parse the logs to demonstrate who accessed what and when. |
| 13 | `13-kv-versioning-rollback.md` | **Secret Versioning & Rollback** — Use KV v2 version history to roll back a corrupted secret, and explore the difference between soft-delete and permanent destroy. |
| 14 | `14-lease-renewal-revocation.md` | **Lease & Renewal Management** — Inspect active leases, renew them programmatically, and bulk-revoke all credentials issued to a compromised token. |
| 15 | `15-identity-groups-rbac-policies.md` | **Identity Groups & RBAC Policies** — Create Vault identity entities and internal groups, assign multiple users to one or more groups, define tiered HCL policies (read-only, read-write, admin) using capability sets, attach each policy to the appropriate group, and verify that effective permissions reflect group membership without per-user policy assignments. |

---

## Real-World Application Patterns

| # | File | Scenario Summary |
|---|------|-----------------|
| 16 | `16-vault-agent-sidecar.md` | **Vault Agent Sidecar** — Run Vault Agent alongside an app container; the agent auto-authenticates and writes secrets to a file the app reads — zero secrets in environment variables. |
| 17 | `17-sentinel-policies.md` | **Sentinel Policies (EGP / RGP)** — Enforce fine-grained rules such as "only allow writes between 09:00–17:00" or "require MFA for secret deletion". |
| 18 | `18-disaster-recovery-snapshots.md` | **Disaster Recovery** — Snapshot Vault state, simulate data loss, restore from the snapshot, and verify that all secrets survive the recovery. |
| 19 | `19-aws-credentials-terraform-rbac.md` | **AWS Credentials for Terraform Developers** — Store static AWS access key and secret key in a KV v2 engine, define a read-only policy scoped to those credentials, create an internal identity group for Terraform developers, attach the policy to the group, and add users so they can securely retrieve AWS credentials when writing Terraform code. |

---

## Recommended Implementation Order

Start here if you are new to Vault beyond the basics:

1. **02 — AppRole Auth** — immediately applicable to any automation or CI/CD pipeline.
2. **05 — Dynamic Database Credentials** — solves the most common real-world secret-sprawl problem.
3. **06 — Transit Engine** — introduces the encryption-as-a-service pattern with no key management in application code.
4. **16 — Vault Agent Sidecar** — production-ready secret injection that eliminates secrets from environment variables entirely.

Work through the remaining scenarios in any order that fits your use case once
these four are solid.

---

## Adding a New Use Case

1. Create the guide file in this folder using the number prefix shown in the
   table above (e.g., `05-dynamic-database-credentials.md`).
2. Follow the section structure: **Overview → Prerequisites → Steps → Testing
   → Summary**.
3. Add a row to the relevant table above and to the **Document Index** in
   [README.md](./README.md).
