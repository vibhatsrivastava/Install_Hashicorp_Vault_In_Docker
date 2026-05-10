---
name: add-vault-use-case
description: "Create the next numbered Vault use-case guide in docs/. Reads use-case-pipeline.md to find the next unwritten guide automatically, scaffolds it from the standard template, and updates the docs/README.md index. Use when adding a new guide, writing the next vault scenario, or starting the next use case."
argument-hint: "<optional: guide number or topic, e.g. '02' or 'approle'>"
---

# Add Vault Use-Case Guide

## When to Use

- Writing the next guide in `docs/`
- A user asks to "add the next guide", "write guide NN", or "start the next use case"
- Creating any `docs/NN-*.md` file from scratch

## Procedure

### Step 1 — Identify the next unwritten guide

Read [`docs/use-case-pipeline.md`](../../../docs/use-case-pipeline.md) and scan its tables for every planned guide entry (columns: `#`, `File`, `Scenario Summary`).

Then check which files already exist in `docs/` (list the directory). The **next guide** is the lowest-numbered entry in the pipeline table whose file does **not yet exist** in `docs/`.

If the user supplied a number or topic as an argument, locate that specific entry instead.

Extract from the matching pipeline row:
- `NN` — two-digit guide number (e.g. `02`)
- `filename` — exact file name from the `File` column (e.g. `02-approle-auth-cicd.md`)
- `scenario` — the `Scenario Summary` cell (one-line description)

### Step 2 — Scaffold the guide file

Create `docs/<filename>` using the [guide template](./assets/guide-template.md) as the structural skeleton. Substitute:

- `NN` → the two-digit number
- `<Title>` → a human-readable title derived from the scenario summary
- `<scenario>` → the scenario summary from the pipeline table
- All `## Section N` headings → concrete steps appropriate for the specific topic

Follow every rule in the attached file instruction `.github/instructions/vault-guide-style.instructions.md`:
- Section order: Overview → Prerequisites → Section N… → Testing → Summary
- All commands via `docker exec -it hashicorp-vault vault …`
- Standard prerequisites export block (verbatim)
- Security callout wherever a secret appears on the CLI
- End every section with a verification command
- `> **Note:**` blockquotes for gotchas
- KV v2 policies must include `sys/internal/ui/mounts/<engine>/*` with `read`

### Step 3 — Update the Document Index

Open [`docs/README.md`](../../../docs/README.md) and add a new row to the **Document Index** table:

```markdown
| NN | [NN-filename.md](./NN-filename.md) | <one-sentence summary> |
```

Insert it in numeric order. Do **not** modify any other part of `docs/README.md`.

### Step 4 — Confirm

Report back:
- The file created (`docs/<filename>`)
- The row added to `docs/README.md`
- A brief note on any sections that may need the user's real environment details (e.g. actual Role IDs, database URLs) to be filled in before the guide is usable.
