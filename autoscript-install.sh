#!/usr/bin/env bash
set -euo pipefail

# ConnectifyVPN - Auto Installer (pakej lokal / git clone)
# Author: Budaxcomel
#
# Fungsi:
# 1) Set PERMISSION_URL (remote whitelist/expiry) supaya installer utama boleh jalan
# 2) Salin pakej ke /opt/connectifyvpn
# 3) Jalankan installer utama (/opt/connectifyvpn/run)

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Sila jalankan sebagai root: sudo bash $0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Jika skrip ini berada di root repo, folder connectifyvpn biasanya wujud.
if [[ -d "${SCRIPT_DIR}/connectifyvpn" ]]; then
  REPO_ROOT="${SCRIPT_DIR}"
  SRC_DIR="${SCRIPT_DIR}/connectifyvpn"
else
  # Jika skrip ini berada dalam folder connectifyvpn
  REPO_ROOT="${SCRIPT_DIR}"
  SRC_DIR="${SCRIPT_DIR}"
fi

# ─────────────────────────────────────────────────────────────
# Auto set PERMISSION_URL berdasarkan Git origin (jika ada)
# ─────────────────────────────────────────────────────────────
detect_raw_base() {
  local dir="$1"
  command -v git >/dev/null 2>&1 || return 1
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  local origin branch owner repo
  origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [[ -n "$branch" && "$branch" != "HEAD" ]] || branch="main"

  if [[ "$origin" =~ ^https?://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  elif [[ "$origin" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  repo="${repo%.git}"
  echo "https://raw.githubusercontent.com/${owner}/${repo}/${branch}/"
}

CONF_DIR="/etc/connectifyvpn"
CONF_FILE="${CONF_DIR}/permission.conf"
PERM_PATH="permission/ipuk/ip"

RAW_BASE="$(detect_raw_base "$REPO_ROOT" 2>/dev/null || true)"
mkdir -p "$CONF_DIR"

if [[ -n "$RAW_BASE" ]]; then
  PERM_URL="${RAW_BASE%/}/${PERM_PATH}"
else
  # fallback ke repo rasmi Budaxcomel
  PERM_URL="https://raw.githubusercontent.com/Budaxcomel/connectifyvpn/main/${PERM_PATH}"
fi

cat >"$CONF_FILE" <<CONF
# ConnectifyVPN - Konfigurasi kebenaran (remote whitelist)
PERMISSION_URL="${PERM_URL}"
CONF
chmod 600 "$CONF_FILE" >/dev/null 2>&1 || true

echo "[*] PERMISSION_URL: ${PERM_URL}"

# ─────────────────────────────────────────────────────────────
# Salin pakej ke /opt dan jalankan installer utama
# ─────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/connectifyvpn"

echo "[*] Memasang ConnectifyVPN ke ${INSTALL_DIR} ..."
mkdir -p "${INSTALL_DIR}"
rm -rf "${INSTALL_DIR:?}/"* || true
cp -a "${SRC_DIR}/." "${INSTALL_DIR}/"

chmod +x "${INSTALL_DIR}/run" || true
if [[ -d "${INSTALL_DIR}/menu/menu" ]]; then
  chmod +x "${INSTALL_DIR}/menu/menu/"* || true
fi

# Keperluan asas
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y curl wget unzip jq git >/dev/null 2>&1 || true

echo "[*] Jalankan installer utama..."
exec bash "${INSTALL_DIR}/run"
