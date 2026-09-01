---
description: "Use when editing, creating, or reviewing Vault use-case guides in docs/. Enforces section order, command style, and formatting conventions."
applyTo: "docs/**/*.md"
---
# Vault Guide Style Rules

## Mandatory Section Order

Every guide must contain exactly these sections in this order:

1. `## Overview` — bullet list of what the guide configures
2. `## Prerequisites` — requirements table + standard shell-variable block
3. `## Section N — <Topic>` — numbered from 1; one major step per section
4. `## Testing` — end-to-end verification steps (positive + negative tests)
5. `## Summary` — summary table mapping each step to what was configured

Do **not** reorder, rename, or omit any of these sections.

## Prerequisites Block (always include verbatim)

```bash
export VAULT_TOKEN=<your-root-token>
```

```powershell
$env:VAULT_TOKEN = "<your-root-token>"
```

Verify Vault is reachable and unsealed:

```bash
docker exec -it hashicorp-vault vault status
```

## Command Style

- **All** Vault CLI commands use Docker Compose — never assume a local Vault CLI.
- Authenticated commands: `docker compose exec -e VAULT_TOKEN vault vault <command>`.
- Status and unseal commands: `docker compose exec vault vault <command>`.
- Support Bash/zsh and PowerShell. Avoid POSIX-only pipelines, backslash continuations, and shell-specific variable expansion in shared command blocks.

## Security Notes

Include a security callout whenever a command passes a secret on the CLI (passwords, tokens). Show the stdin alternative:

```bash
docker compose exec -e VAULT_TOKEN vault vault write <path> password=<value>
```

## Formatting

- Use a two-column `| Requirement | Notes |` table in Prerequisites.
- Use `### N.M — <sub-step>` headings inside a Section when there are multiple sub-steps.
- Use `> **Note:**` blockquotes for gotchas, not inline prose.
- End each section with a verification command so the reader can confirm before moving on.

## Key Constraints

- TLS is disabled (`tls_disable = 1`). Do not add HTTPS instructions without noting config changes are required.
- KV v2 policy paths must use the `data/` and `metadata/` sub-paths explicitly.
- KV v2 policies need `sys/internal/ui/mounts/<engine>/*` with `read` to avoid `403 preflight` errors on `vault kv` commands.

## Style Reference

See [`docs/01-userpass-auth-machine-credentials.md`](../docs/01-userpass-auth-machine-credentials.md) as the canonical example.
