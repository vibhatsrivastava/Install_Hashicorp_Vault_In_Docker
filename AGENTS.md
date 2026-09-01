# Agent Instructions — Install HashiCorp Vault in Docker

This repository deploys a single-node HashiCorp Vault instance via Docker Compose for learning and local development. The primary deliverable is numbered, tutorial-style documentation in `docs/`.

---

## Project Essentials

| Item | Value |
|------|-------|
| Container name | `hashicorp-vault` |
| Vault API / UI | `http://localhost:8200` |
| Storage backend | File (Docker-managed `vault-data` volume) |
| TLS | Disabled (HTTP only — dev/learning environment) |
| Config file | `vault/config/vault.hcl` |

Start / stop the stack:

```bash
docker compose up -d
docker compose down        # data persists in the named volume
```

---

## Running Vault Commands

All Vault CLI commands run inside the container via `docker compose exec`. No local Vault CLI installation is required.

```bash
docker compose exec -e VAULT_TOKEN vault vault <command>
```

Set these shell variables before running any guide commands:

```bash
export VAULT_TOKEN=<your-root-token>
```

---

## Repository Structure

```
AGENTS.md                     ← this file
docker-compose.yml
vault/
  config/vault.hcl            ← Vault server config (storage, listener, ui)
  data/                       ← legacy host path; persistent state uses volumes
  logs/                       ← legacy host path; persistent state uses volumes
docs/
  README.md                   ← document index
  use-case-pipeline.md        ← catalogue of all planned guides (02–18)
  01-userpass-auth-machine-credentials.md
  …                           ← future numbered guides
```

---

## Documentation Conventions

- Every guide lives in `docs/` with a two-digit numeric prefix (`01-`, `02-`, …).
- Section order is always: **Overview → Prerequisites → Steps → Testing → Summary**.
- All commands are written as `docker compose exec` calls so readers need no local CLI.
- The [`docs/README.md`](docs/README.md) Document Index must be updated whenever a new guide is added.
- The [`docs/use-case-pipeline.md`](docs/use-case-pipeline.md) table lists planned guides — use it to determine the next unwritten file name and topic.
- See the existing guide [`docs/01-userpass-auth-machine-credentials.md`](docs/01-userpass-auth-machine-credentials.md) as the canonical style reference.

### Adding a New Guide

1. Check `docs/use-case-pipeline.md` for the correct number, file name, and scenario summary.
2. Create `docs/<NN>-<slug>.md` following the five-section structure above.
3. Add a row to the Document Index table in `docs/README.md`.

---

## Key Constraints

- **No TLS in this setup** — `tls_disable = 1` in `vault.hcl`. Do not add TLS instructions without first noting it requires config changes.
- **`/vault/config` is NOT mounted read-only** — the entrypoint runs `chown vault:vault` on startup; a `:ro` mount causes a crash-loop.
- **Volume ownership:** `vault-permissions` runs once as root to make the managed data and log volumes writable by Vault (UID 100) before the server starts.
- **Platform support:** Linux Docker Engine, Docker Desktop with Linux containers/WSL2 on Windows, and Docker Desktop or an equivalent Linux-VM runtime on macOS. Native Windows containers are unsupported.
- **Networking:** `docker-compose.yml` binds HTTP to `127.0.0.1`; use `docker-compose.lan.yml` only for deliberate trusted-LAN exposure.
- Secrets must never be committed to the repository. Docker volumes and backup archives can contain sensitive data.
