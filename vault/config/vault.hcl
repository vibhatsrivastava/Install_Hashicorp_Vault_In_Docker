# =============================================================================
# HashiCorp Vault Server Configuration
# =============================================================================
# Storage backend: file-based (single-node, persistent on host filesystem)
# Transport:       HTTP (TLS disabled — suitable for internal/dev use)
# UI:              Enabled (accessible at http://<host>:8200/ui)
# =============================================================================

# ---------------------------------------------------------------------------
# Storage Backend
# Data is persisted inside the container at /vault/data, which is bind-mounted
# to ./vault/data on the Docker host.
# ---------------------------------------------------------------------------
storage "file" {
  path = "/vault/data"
}

# ---------------------------------------------------------------------------
# TCP Listener
# Vault listens on all interfaces inside the container.
# The Docker Compose file maps container port 8200 → host port 8200.
# tls_disable = 1  →  plain HTTP (no TLS).  Set to 0 and add cert/key paths
#                       to enable HTTPS in production environments.
# ---------------------------------------------------------------------------
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# ---------------------------------------------------------------------------
# API Address
# Used by Vault to construct self-referential redirect URIs and cluster
# addresses. Must match the externally reachable address of this node.
# ---------------------------------------------------------------------------
api_addr = "http://0.0.0.0:8200"

# ---------------------------------------------------------------------------
# Web UI
# Enables the built-in browser-based UI at /ui.
# ---------------------------------------------------------------------------
ui = true
