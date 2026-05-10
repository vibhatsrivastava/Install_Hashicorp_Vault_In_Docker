# Agent Instructions — Install HashiCorp Vault in Docker

This repository deploys a single-node HashiCorp Vault instance via Docker Compose for learning and local development. The primary deliverable is numbered, tutorial-style documentation in `docs/`.

---

## Project Essentials

| Item | Value |
|------|-------|
| Container name | `hashicorp-vault` |
| Vault API / UI | `http://localhost:8200` |
| Storage backend | File (`./vault/data`) |
| TLS | Disabled (HTTP only — dev/learning environment) |
| Config file | `vault/config/vault.hcl` |

Start / stop the stack:

```bash
docker compose up -d
docker compose down        # data persists in ./vault/data
```

---

## Running Vault Commands

All Vault CLI commands run inside the container via `docker exec`. No local Vault CLI installation is required.

```bash
docker exec -it hashicorp-vault vault <command>
```

Set these shell variables before running any guide commands:

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>
```

---

## Repository Structure

```
AGENTS.md                     ← this file
docker-compose.yml
vault/
  config/vault.hcl            ← Vault server config (storage, listener, ui)
  data/                       ← encrypted storage (bind mount, git-ignored)
  logs/                       ← audit log output (bind mount, git-ignored)
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
- All commands are written as `docker exec` calls so readers need no local CLI.
- The [`docs/README.md`](docs/README.md) Document Index must be updated whenever a new guide is added.
- The [`docs/use-case-pipeline.md`](docs/use-case-pipeline.md) table lists all planned future guides (02–18) — use it to determine the correct file name and topic for the next guide.
- See the existing guide [`docs/01-userpass-auth-machine-credentials.md`](docs/01-userpass-auth-machine-credentials.md) as the canonical style reference.

### Adding a New Guide

1. Check `docs/use-case-pipeline.md` for the correct number, file name, and scenario summary.
2. Create `docs/<NN>-<slug>.md` following the five-section structure above.
3. Add a row to the Document Index table in `docs/README.md`.

---

## Key Constraints

- **No TLS in this setup** — `tls_disable = 1` in `vault.hcl`. Do not add TLS instructions without first noting it requires config changes.
- **`/vault/config` is NOT mounted read-only** — the entrypoint runs `chown vault:vault` on startup; a `:ro` mount causes a crash-loop.
- Secrets must never be committed to the repository. The `vault/data/` and `vault/logs/` directories are bind mounts and should remain git-ignored.
