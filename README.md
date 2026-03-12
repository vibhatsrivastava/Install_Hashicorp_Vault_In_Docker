# Install HashiCorp Vault in Docker

Install HashiCorp Vault as a Docker container on an Ubuntu host with persistent data using Docker Compose.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Setup](#setup)
- [Initialize and Unseal Vault](#initialize-and-unseal-vault)
- [Login and Verify](#login-and-verify)
- [Accessing the Vault UI](#accessing-the-vault-ui)
- [Common Operations](#common-operations)
- [Persistence and Data Safety](#persistence-and-data-safety)
- [Security Notes](#security-notes)

---

## Overview

| Parameter        | Value                          |
|------------------|-------------------------------|
| Image            | `hashicorp/vault:latest`       |
| Storage Backend  | File (bind-mounted host path)  |
| Transport        | HTTP (TLS disabled)            |
| API / UI Port    | `8200`                         |
| Web UI           | Enabled (`/ui`)                |
| Restart Policy   | `unless-stopped`               |

---

## Prerequisites

- Ubuntu host with **Docker** and **Docker Compose** installed.
- Port `8200` open on the host firewall.
- The user running Docker commands must be in the `docker` group (or use `sudo`).

To verify both tools are installed:

```bash
docker --version
docker compose version
```

---

## Repository Structure

```
.
├── docker-compose.yml          # Docker Compose service definition
└── vault/
    ├── config/
    │   └── vault.hcl           # Vault server configuration
    ├── data/                   # Persistent encrypted storage (bind mount)
    └── logs/                   # Audit log output (bind mount)
```

---

## Setup

### 1 — Clone the repository

```bash
git clone https://github.com/vibhatsrivastava/Install_Hashicorp_Vault_In_Docker.git
cd Install_Hashicorp_Vault_In_Docker
```

### 2 — Set correct permissions on the data directory

The `hashicorp/vault` container entrypoint runs `chown vault:vault` (UID `100`)
on **every bind-mounted directory** before starting the server. All three
directories (`config`, `data`, `logs`) must be owned by UID `100` on the host:

```bash
sudo chown -R 100:100 vault/
```

### 3 — Start the container

```bash
docker compose up -d
```

### 4 — Confirm the container is running

```bash
docker compose ps
docker compose logs vault
```

You should see a line like:

```
==> Vault server started! Log data will stream in below:
```

### 5 — Verify the API is reachable

```bash
curl -s http://localhost:8200/v1/sys/health | python3 -m json.tool
```

- **HTTP 501** — running but not yet initialized ✅  
- **HTTP 503** — initialized but sealed  
- **HTTP 200** — initialized, unsealed, and active  

---

## Initialize and Unseal Vault

> **This step is only required once** — the very first time Vault starts with an
> empty data directory. Initialization generates the unseal keys and root token.

### 1 — Exec into the container

```bash
docker exec -it vault sh
```

### 2 — Set the Vault address (inside the container shell)

```bash
export VAULT_ADDR=http://127.0.0.1:8200
```

### 3 — Initialize Vault

```bash
vault operator init
```

**Sample output:**

```
Unseal Key 1: <key-1>
Unseal Key 2: <key-2>
Unseal Key 3: <key-3>
Unseal Key 4: <key-4>
Unseal Key 5: <key-5>

Initial Root Token: hvs.<root-token>
```

> ⚠️ **Critical:** Save all 5 unseal keys and the root token in a secure
> location (e.g. a secrets manager). They **cannot be recovered** if lost.
> **Never commit them to version control.**

### 4 — Unseal Vault (3 of 5 keys required)

Run the following command **three times**, providing a different unseal key
each time when prompted:

```bash
vault operator unseal   # provide Unseal Key 1
vault operator unseal   # provide Unseal Key 2
vault operator unseal   # provide Unseal Key 3
```

After the third key the output will show:

```
Sealed          false
```

### 5 — Exit the container shell

```bash
exit
```

> **Note:** Vault is automatically sealed again whenever the container restarts.
> You must run `vault operator unseal` (3 keys) each time after a restart.

---

## Login and Verify

You can interact with Vault either inside the container or from the host (with
the Vault CLI installed on the host).

### From inside the container

```bash
docker exec -it vault sh
export VAULT_ADDR=http://127.0.0.1:8200
vault login <root-token>
vault status
```

### From the host (Vault CLI installed)

```bash
export VAULT_ADDR=http://localhost:8200
vault login <root-token>
vault status
```

Expected `vault status` output when healthy:

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         x.x.x
Storage Type    file
Cluster Name    vault-cluster-...
Cluster ID      ...
HA Enabled      false
```

---

## Accessing the Vault UI

Open a browser and navigate to:

```
http://<host-ip>:8200/ui
```

Log in using the **root token** (or any other token/method you configure).

---

## Common Operations

### Stop the container (data is preserved)

```bash
docker compose down
```

### Pull the latest Vault image and recreate the container

```bash
docker compose pull
docker compose up -d
```

### Tail Vault logs in real time

```bash
docker compose logs -f vault
```

### Re-seal Vault manually

```bash
vault operator seal
```

---

## Persistence and Data Safety

Vault's encrypted data is stored on the **host filesystem** at `./vault/data`.
This directory survives `docker compose down`, container recreation, and
`docker compose pull` upgrades. Back up this directory regularly.

```bash
# Example: create a timestamped backup
tar -czf vault-data-backup-$(date +%Y%m%d%H%M%S).tar.gz vault/data
```

---

## Security Notes

| Topic | Detail |
|---|---|
| `IPC_LOCK` capability | Added to the container so Vault can call `mlock(2)` and prevent secrets from being paged to disk. |
| Unseal keys & root token | Store them in a dedicated secrets manager (AWS Secrets Manager, Azure Key Vault, etc.). Never store them in this repository. |
| TLS | TLS is disabled in this setup. For production or internet-facing deployments, enable TLS by setting `tls_disable = 0` in `vault/config/vault.hcl` and providing a certificate and key. |
| Root token | The root token has unrestricted access. Create scoped policies and tokens for day-to-day use, and revoke the root token when not needed. |
| Firewall | Restrict access to port `8200` using `ufw` or cloud security groups to trusted hosts only. |

