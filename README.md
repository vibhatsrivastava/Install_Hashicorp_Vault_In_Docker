# Install HashiCorp Vault in Docker

Run a single-node HashiCorp Vault instance with Docker Compose for local
learning and development. Vault data and audit logs persist in Docker-managed
volumes, so the same setup works on Linux, macOS, and Windows hosts that run
Linux containers.

> **Warning:** Vault is served over HTTP without TLS. The default configuration
> is bound to `localhost` and is suitable only for local learning and
> development. Do not expose it to an untrusted network.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Initialize and Unseal Vault](#initialize-and-unseal-vault)
- [Login and Verify](#login-and-verify)
- [Accessing the Vault UI](#accessing-the-vault-ui)
- [LAN Access](#lan-access)
- [Persistence and Backup](#persistence-and-backup)
- [Common Operations](#common-operations)
- [Security Notes](#security-notes)

## Overview

| Parameter | Value |
|---|---|
| Image | `hashicorp/vault:1.18.3` |
| Storage backend | File storage in the Docker volume `vault-data` |
| Audit log location | Docker volume `vault-logs` |
| Transport | HTTP (TLS disabled) |
| Default API/UI address | `http://localhost:8200` |
| Web UI | Enabled at `/ui` |

## Prerequisites

| Host platform | Required Docker runtime |
|---|---|
| Linux | Docker Engine and Docker Compose plugin 2.24.4 or later |
| Windows | Docker Desktop configured for **Linux containers**, normally with the WSL 2 backend |
| macOS | Docker Desktop or another Docker runtime backed by a Linux VM |

Native Windows-container mode is not supported because `hashicorp/vault` is a
Linux image. Confirm Docker is available:

```text
docker --version
docker compose version
```

The default port is `8200`. Ensure it is unused on the local machine.

## Setup

### 1. Clone the repository

```text
git clone https://github.com/vibhatsrivastava/Install_Hashicorp_Vault_In_Docker.git
cd Install_Hashicorp_Vault_In_Docker
```

### 2. Optionally select a host port

Docker Compose uses port `8200` when no `.env` file is present. To select a
different local port, copy the template and edit `VAULT_HOST_PORT`.

```bash
cp .env.example .env
```

```powershell
Copy-Item .env.example .env
```

For example, set `VAULT_HOST_PORT=18200` in `.env`. The API/UI address then
becomes `http://localhost:18200`.

### 3. Start Vault

```text
docker compose up -d
docker compose ps
docker compose logs vault
```

Vault data and audit logs are stored in Docker-managed named volumes. No host
`chown`, `sudo`, or UID/GID preparation is required.

### 4. Check the service state

```text
docker compose exec vault vault status
```

Before initialization, Vault reports `Initialized: false` and is healthy for
this learning setup. The health endpoint returns HTTP `501` before
initialization, `503` while sealed, and `200` while initialized and unsealed.

## Initialize and Unseal Vault

Perform initialization once for a newly created `vault-data` volume.

### 1. Initialize Vault

```text
docker compose exec vault vault operator init
```

Save all unseal keys and the initial root token in a secure location. They
cannot be recovered if lost and must never be committed to version control.

### 2. Unseal Vault

Run the command three times and supply a different unseal key each time:

```text
docker compose exec vault vault operator unseal
```

Confirm Vault is unsealed:

```text
docker compose exec vault vault status
```

After every container restart, Vault must be unsealed again unless you later
configure an auto-unseal mechanism.

## Login and Verify

Set the root token in the shell that runs Docker commands.

```bash
export VAULT_TOKEN=<your-root-token>
```

```powershell
$env:VAULT_TOKEN = "<your-root-token>"
```

Pass the token explicitly to the container for authenticated commands:

```text
docker compose exec -e VAULT_TOKEN vault vault token lookup
```

The `-e VAULT_TOKEN` option forwards the host-shell value into the container.
Use it for authenticated Vault CLI commands in this repository's guides.

## Accessing the Vault UI

Open `http://localhost:8200/ui`, or substitute the value of
`VAULT_HOST_PORT` when you selected a different port. Sign in with the root
token or another configured authentication method.

## LAN Access

The default Compose file deliberately publishes Vault only to `localhost`.
To expose it on all host interfaces on a trusted network, start it with the
explicit LAN configuration:

```text
docker compose -f docker-compose.yml -f docker-compose.lan.yml up -d
```

`docker-compose.lan.yml` uses the Compose `!override` tag, which requires
Docker Compose 2.24.4 or later, to replace rather than duplicate the default
loopback port mapping.

Open `http://<host-name-or-ip>:<port>/ui`. Configure the host firewall to
allow only trusted clients. Because this repository disables TLS, do not use
this mode on an untrusted network; enable TLS and use a real hostname before
using Vault beyond local development.

## Persistence and Backup

`docker compose down` stops the container but preserves `vault-data` and
`vault-logs`. `docker compose down -v` permanently removes both volumes and
therefore destroys the Vault state.

List the volumes:

```text
docker volume ls
```

Create a backup archive in the current directory. This command runs entirely
inside Docker and works from Bash/zsh and PowerShell:

```text
docker run --rm -v hashicorp-vault_vault-data:/source:ro -v "${PWD}:/backup" alpine tar -czf /backup/vault-data-backup.tar.gz -C /source .
```

> **Note:** In PowerShell, replace `${PWD}` with `${PWD.Path}` if Docker does
> not expand the path correctly. Keep backup archives outside the repository;
> they contain encrypted Vault data and can still be sensitive.

To restore, stop Vault, create the volume if needed, and extract the archive:

```text
docker compose down
docker volume create hashicorp-vault_vault-data
docker run --rm -v hashicorp-vault_vault-data:/target -v "${PWD}:/backup" alpine sh -c "rm -rf /target/* && tar -xzf /backup/vault-data-backup.tar.gz -C /target"
docker compose up -d
```

## Common Operations

```text
docker compose down
docker compose up -d
docker compose logs -f vault
docker compose pull
docker compose up -d
docker compose exec vault vault operator seal
```

## Security Notes

| Topic | Detail |
|---|---|
| TLS | Disabled in `vault/config/vault.hcl`; appropriate only for local learning. |
| Root token | Has unrestricted access. Store it securely and create scoped policies for ordinary use. |
| Network binding | The default port publication is loopback-only. LAN exposure requires the explicit `docker-compose.lan.yml` file. |
| Persistent volumes | `vault-data` contains encrypted Vault storage and `vault-logs` can contain sensitive audit metadata. Do not remove volumes or commit backup archives inadvertently. |
| `IPC_LOCK` | Allows Vault to prevent secrets being swapped to disk when the Docker runtime permits it. |