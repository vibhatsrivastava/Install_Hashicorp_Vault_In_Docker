# Use Case NN — <Title>

## Overview

This guide walks through <!-- one-sentence goal -->:

1. <!-- Step 1 bullet -->
2. <!-- Step 2 bullet -->
3. <!-- Step 3 bullet -->
4. Run **testing steps** to validate the entire workflow.

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

## Section 1 — <Topic>

<!-- Explain what this section accomplishes and why. -->

```bash
docker exec -it hashicorp-vault vault <command>
```

Verify:

```bash
docker exec -it hashicorp-vault vault <verify-command>
```

Expected output: <!-- describe expected output -->

---

## Section 2 — <Topic>

<!-- Explain what this section accomplishes and why. -->

```bash
docker exec -it hashicorp-vault vault <command>
```

> **Security note:** Avoid passing secrets directly on the command line in
> production — they may appear in shell history. Use the `-` flag to read from
> stdin:
>
> ```bash
> echo 'key=value' | docker exec -i hashicorp-vault vault write <path> -
> ```

Verify:

```bash
docker exec -it hashicorp-vault vault <verify-command>
```

---

## Section 3 — <Topic>

<!-- Repeat Section pattern as needed. Number sections sequentially. -->
<!-- Use ### N.M — <sub-step> headings when a section has multiple sub-steps. -->

---

## Testing

These steps verify the entire workflow end-to-end.

### T.1 — <Positive test description>

```bash
docker exec -it hashicorp-vault vault <command>
```

Expected: <!-- describe success output -->

### T.2 — <Negative test description>

```bash
docker exec -it hashicorp-vault vault <command>
```

Expected: `Code: 403` — confirms the policy boundary is correctly enforced.

---

## Summary

| Step | Command area | What was configured |
|------|-------------|---------------------|
| 1 | <!-- area --> | <!-- what --> |
| 2 | <!-- area --> | <!-- what --> |
| 3 | <!-- area --> | <!-- what --> |
| Testing | <!-- area --> | Positive and negative tests passed |
