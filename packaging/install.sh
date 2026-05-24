#!/usr/bin/env bash
# packaging/install.sh — install gapes-server on a Linux host.
#
# Downloads the release binary for your CPU arch from GitHub releases,
# verifies its SHA256, drops a default config into /etc/gapes/, installs the
# systemd unit, and prints next steps.
#
# Usage:
#   sudo bash packaging/install.sh                # install latest as root
#   sudo GAPES_VERSION=v0.1.0 bash install.sh     # pin a release
#   bash packaging/install.sh --user-mode         # dry-run-ish: stage in $HOME, no system changes
#
# Environment:
#   GAPES_VERSION   release tag (default: latest)
#   GAPES_REPO      override repo (default: fguisso/gapes)
#   GAPES_PREFIX    install prefix (default: /usr/local)

set -euo pipefail

# ─── Constants ──────────────────────────────────────────────────────────────
GAPES_REPO="${GAPES_REPO:-fguisso/gapes}"
GAPES_VERSION="${GAPES_VERSION:-latest}"
GAPES_PREFIX="${GAPES_PREFIX:-/usr/local}"

BIN_DIR="${GAPES_PREFIX}/bin"
CONFIG_DIR="/etc/gapes"
STATE_DIR="/var/lib/gapes"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_NAME="gapes-server.service"

USER_MODE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ─── Helpers ────────────────────────────────────────────────────────────────
log()  { printf '\033[1;34m[gapes]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[gapes]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[gapes]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Install gapes-server.

Usage:
  sudo bash install.sh                  Install system-wide (requires root).
  bash install.sh --user-mode           Stage a local install under $HOME (no root needed).
  bash install.sh --help                Show this help.

Environment overrides:
  GAPES_VERSION   Release tag to install (default: latest).
  GAPES_REPO      GitHub repo (default: fguisso/gapes).
  GAPES_PREFIX    Install prefix (default: /usr/local).

Examples:
  sudo bash install.sh
  sudo GAPES_VERSION=v0.1.0 bash install.sh
  GAPES_PREFIX="$HOME/.local" bash install.sh --user-mode
EOF
}

# ─── Argument parsing ───────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user-mode) USER_MODE=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           usage; die "unknown argument: $1" ;;
    esac
done

# ─── Privilege check ────────────────────────────────────────────────────────
if [[ "${USER_MODE}" -eq 0 && "$(id -u)" -ne 0 ]]; then
    die "must run as root (or pass --user-mode for a non-system install). Try: sudo bash $0"
fi

if [[ "${USER_MODE}" -eq 1 ]]; then
    BIN_DIR="${GAPES_PREFIX:-$HOME/.local}/bin"
    CONFIG_DIR="${HOME}/.config/gapes"
    STATE_DIR="${HOME}/.local/share/gapes"
    warn "user-mode: installing under ${BIN_DIR}, config in ${CONFIG_DIR}, state in ${STATE_DIR}"
    warn "user-mode skips systemd unit + user creation. You will run the binary yourself."
fi

# ─── Tool check ─────────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }
need curl
need tar
need sha256sum
need install
need uname

# ─── Detect arch ────────────────────────────────────────────────────────────
detect_arch() {
    local m
    m="$(uname -m)"
    case "$m" in
        x86_64|amd64)  echo "x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
        *)             die "unsupported CPU arch: $m (need x86_64 or aarch64)" ;;
    esac
}

TARGET_TRIPLE="$(detect_arch)"
log "detected target: ${TARGET_TRIPLE}"

# ─── Resolve version ────────────────────────────────────────────────────────
resolve_version() {
    if [[ "${GAPES_VERSION}" != "latest" ]]; then
        echo "${GAPES_VERSION}"
        return
    fi
    # Latest release redirect — works without an API token.
    local url tag
    url="https://github.com/${GAPES_REPO}/releases/latest"
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${url}" \
        | sed -E 's|.*/tag/||')"
    [[ -n "${tag}" && "${tag}" != "${url}" ]] || die "couldn't resolve latest release for ${GAPES_REPO}"
    echo "${tag}"
}

VERSION="$(resolve_version)"
log "installing version: ${VERSION}"

ASSET="gapes-server-${VERSION}-${TARGET_TRIPLE}.tar.gz"
ASSET_URL="https://github.com/${GAPES_REPO}/releases/download/${VERSION}/${ASSET}"
SHA_URL="${ASSET_URL}.sha256"

# ─── Download + verify ──────────────────────────────────────────────────────
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

log "downloading ${ASSET}"
curl -fsSL "${ASSET_URL}" -o "${TMP}/${ASSET}"
curl -fsSL "${SHA_URL}"   -o "${TMP}/${ASSET}.sha256"

log "verifying SHA256"
(
    cd "${TMP}"
    # The .sha256 file may be either bare hash or `<hash>  <filename>`.
    expected="$(awk '{print $1}' "${ASSET}.sha256")"
    actual="$(sha256sum "${ASSET}" | awk '{print $1}')"
    [[ "${expected}" == "${actual}" ]] \
        || die "SHA256 mismatch! expected=${expected} actual=${actual}"
)
log "SHA256 verified"

log "extracting"
tar -xzf "${TMP}/${ASSET}" -C "${TMP}"
[[ -f "${TMP}/gapes-server" ]] \
    || die "archive does not contain gapes-server binary"

# ─── Install ────────────────────────────────────────────────────────────────
log "installing binary to ${BIN_DIR}/gapes-server"
install -d "${BIN_DIR}"
install -m 0755 "${TMP}/gapes-server" "${BIN_DIR}/gapes-server"

# ─── Create user/group (system mode only) ───────────────────────────────────
if [[ "${USER_MODE}" -eq 0 ]]; then
    if ! getent group  gapes >/dev/null; then
        log "creating system group: gapes"
        groupadd --system gapes
    fi
    if ! getent passwd gapes >/dev/null; then
        log "creating system user: gapes"
        useradd --system --gid gapes \
            --home-dir "${STATE_DIR}" \
            --shell /usr/sbin/nologin \
            --comment "gapes-server" \
            gapes
    fi
fi

# ─── Create dirs ────────────────────────────────────────────────────────────
log "creating directories"
install -d -m 0750 "${CONFIG_DIR}"
install -d -m 0750 "${STATE_DIR}"
install -d -m 0750 "${STATE_DIR}/data"
install -d -m 0750 "${STATE_DIR}/pages"

if [[ "${USER_MODE}" -eq 0 ]]; then
    chown -R gapes:gapes "${STATE_DIR}"
    chown    root:gapes  "${CONFIG_DIR}"
fi

# ─── Drop default config ────────────────────────────────────────────────────
CONFIG_FILE="${CONFIG_DIR}/pages.toml"
EXAMPLE_SRC="${REPO_ROOT}/pages.example.toml"

if [[ -f "${CONFIG_FILE}" ]]; then
    log "config already exists, leaving it alone: ${CONFIG_FILE}"
else
    if [[ -f "${EXAMPLE_SRC}" ]]; then
        log "writing default config to ${CONFIG_FILE} (edit before starting!)"
        install -m 0640 "${EXAMPLE_SRC}" "${CONFIG_FILE}"
    else
        warn "pages.example.toml not found in repo root — skipping config drop"
        warn "you'll need to create ${CONFIG_FILE} yourself"
    fi
    if [[ "${USER_MODE}" -eq 0 && -f "${CONFIG_FILE}" ]]; then
        chown root:gapes "${CONFIG_FILE}"
    fi
fi

# ─── Install systemd unit (system mode only) ────────────────────────────────
if [[ "${USER_MODE}" -eq 0 ]]; then
    UNIT_SRC="${SCRIPT_DIR}/systemd/${SERVICE_NAME}"
    UNIT_DST="${SYSTEMD_DIR}/${SERVICE_NAME}"
    if [[ -f "${UNIT_SRC}" ]]; then
        log "installing systemd unit: ${UNIT_DST}"
        install -m 0644 "${UNIT_SRC}" "${UNIT_DST}"
        if command -v systemctl >/dev/null 2>&1; then
            log "running systemctl daemon-reload"
            systemctl daemon-reload
        else
            warn "systemctl not found — skipping daemon-reload"
        fi
    else
        warn "systemd unit not found at ${UNIT_SRC} — skipping"
    fi
fi

# ─── Next steps ─────────────────────────────────────────────────────────────
cat <<EOF

  gapes-server installed.

  Next steps:

    1. Edit the config:
         \$EDITOR ${CONFIG_FILE}
       Notably: [server].public_url, [server].trusted_proxy.

EOF

if [[ "${USER_MODE}" -eq 0 ]]; then
    cat <<EOF
    2. Start the service:
         systemctl enable --now gapes-server
         systemctl status gapes-server
         journalctl -u gapes-server -f

    3. Put Caddy (or another TLS-terminating proxy) in front of it.
       gapes-server is HTTP-only by design — it MUST NOT be exposed to
       the public internet directly. Sample Caddyfile:
         ${REPO_ROOT}/Caddyfile.example
       Install Caddy (https://caddyserver.com/docs/install), then:
         sudo cp ${REPO_ROOT}/Caddyfile.example /etc/caddy/Caddyfile
         sudo \$EDITOR /etc/caddy/Caddyfile      # set your domain + email
         sudo systemctl reload caddy

EOF
else
    cat <<EOF
    2. Run it yourself:
         ${BIN_DIR}/gapes-server --config ${CONFIG_FILE}

EOF
fi

log "done."
