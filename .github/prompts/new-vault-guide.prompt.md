---
name: new-vault-guide
description: "Create a new numbered use-case guide in docs/ following the project's established structure and style."
---

Create the use-case guide **`docs/${guide-filename}`** for the following scenario:

**Scenario:** ${scenario-description}

---

## Requirements

Follow these rules exactly — they match every existing guide in this project:

1. **File location**: `docs/${guide-filename}` (number prefix already determined by `docs/use-case-pipeline.md`)
2. **Section order** (mandatory):
   - `## Overview` — what this guide covers, in bullet form
   - `## Prerequisites` — table of requirements (Vault running, unsealed, root token in hand)
   - `## Section N — <Topic>` — one section per major step; number them from 1
   - `## Testing` — step-by-step verification of the full workflow
   - `## Summary` — one-paragraph recap of what was accomplished
3. **All commands** must use `docker compose exec`; authenticated commands must use `docker compose exec -e VAULT_TOKEN vault vault …` — no local Vault CLI.
4. **Prerequisites block** must include the standard shell-variable export:
   ```bash
   export VAULT_TOKEN=<your-root-token>
   ```
   and the PowerShell equivalent:
   ```powershell
   $env:VAULT_TOKEN = "<your-root-token>"
   ```
5. **Security notes** where relevant (e.g., avoid secrets on the command line, use stdin instead).
6. Use the style of [`docs/01-userpass-auth-machine-credentials.md`](../docs/01-userpass-auth-machine-credentials.md) as the canonical reference.

After creating the guide file, **update `docs/README.md`**: add a row to the Document Index table with the file link and a one-sentence summary.
