#!/usr/bin/env bash
# ConnectifyVPN - Semakan kebenaran (remote whitelist) + tarikh tamat langganan
# -----------------------------------------------------------------------------
# Format fail whitelist (1 baris = 1 VPS):
#   <IP> <USERNAME> <YYYY-MM-DD>
# atau:
#   <IP>|<USERNAME>|<YYYY-MM-DD>
#
# Contoh:
#   203.0.113.10 connectifyvpn 2026-12-31
#   203.0.113.11|connectifyvpn|2026-12-31
#
# Nota:
# - Baris kosong / bermula dengan # akan diabaikan.
# - Tarikh mesti format YYYY-MM-DD untuk semakan yang konsisten.

set -euo pipefail

CVP_NAME="connectifyvpn"
CVP_STATE_DIR="/var/lib/${CVP_NAME}"
CVP_CACHE_FILE="${CVP_STATE_DIR}/permission_cache.txt"
CVP_CACHE_MAX_AGE_SECONDS=$((12*60*60)) # 12 jam
CVP_CONF_FILE="/etc/${CVP_NAME}/permission.conf"
CVP_PERMISSION_PATH_DEFAULT="permission/ipuk/ip"

# Output vars selepas semakan berjaya:
#   CVP_PUBLIC_IP, CVP_PERMISSION_URL, CVP_USERNAME, CVP_EXPIRY, CVP_DAYS_LEFT

_cvp_now_epoch() { date +%s; }
_cvp_today() { date -d "0 days" +"%Y-%m-%d"; }

_cvp_have_cmd() { command -v "$1" >/dev/null 2>&1; }

_cvp_fetch() {
  # args: url output_file
  local url="$1"
  local out="$2"
  if _cvp_have_cmd curl; then
    curl -fsSL --connect-timeout 10 --max-time 20 "$url" -o "$out"
  elif _cvp_have_cmd wget; then
    wget -qO "$out" "$url"
  else
    return 127
  fi
}

cvp_get_public_ip() {
  local ip=""
  if _cvp_have_cmd curl; then
    ip="$(curl -fsSL --connect-timeout 10 --max-time 20 https://api.ipify.org 2>/dev/null || true)"
    [[ -n "$ip" ]] || ip="$(curl -fsSL --connect-timeout 10 --max-time 20 https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n' || true)"
  elif _cvp_have_cmd wget; then
    ip="$(wget -qO- https://api.ipify.org 2>/dev/null || true)"
    [[ -n "$ip" ]] || ip="$(wget -qO- https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n' || true)"
  fi
  ip="$(echo -n "$ip" | tr -d ' \t\r\n')"
  if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ""
    return 1
  fi
  echo "$ip"
}

cvp_detect_repo_raw_base() {
  # Cuba detect repo asal jika script ini dijalankan dari folder git clone.
  # Return: raw base URL, contoh: https://raw.githubusercontent.com/OWNER/REPO/BRANCH/
  local dir="${1:-.}"
  if ! _cvp_have_cmd git; then
    return 1
  fi
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  local origin branch owner repo raw
  origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [[ -n "$branch" && "$branch" != "HEAD" ]] || branch="main"

  # Parse owner/repo dari origin
  # https://github.com/owner/repo(.git)
  if [[ "$origin" =~ ^https?://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  # git@github.com:owner/repo(.git)
  elif [[ "$origin" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  # buang .git jika ada
  repo="${repo%.git}"
  raw="https://raw.githubusercontent.com/${owner}/${repo}/${branch}/"
  echo "$raw"
}

cvp_get_permission_url() {
  # Keutamaan:
  # 1) /etc/connectifyvpn/permission.conf (PERMISSION_URL=...)
  # 2) derive dari git origin (repo ini)
  # 3) guna pembolehubah persekitaran REPO (raw base) jika ada
  # 4) fallback gagal
  local repo_dir="${1:-.}"
  local url=""
  local path="${CVP_PERMISSION_PATH:-$CVP_PERMISSION_PATH_DEFAULT}"

  if [[ -f "$CVP_CONF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CVP_CONF_FILE" || true
    if [[ -n "${PERMISSION_URL:-}" ]]; then
      echo "${PERMISSION_URL}"
      return 0
    fi
    if [[ -n "${PERMISSION_RAW_BASE:-}" ]]; then
      echo "${PERMISSION_RAW_BASE%/}/${path}"
      return 0
    fi
  fi

  # derive dari git
  local raw_base=""
  raw_base="$(cvp_detect_repo_raw_base "$repo_dir" 2>/dev/null || true)"
  if [[ -n "$raw_base" ]]; then
    url="${raw_base%/}/${path}"
    echo "$url"
    return 0
  fi

  # guna REPO jika ada (sesetengah installer define REPO)
  if [[ -n "${REPO:-}" ]]; then
    echo "${REPO%/}/${path}"
    return 0
  fi

  # fallback (repo rasmi Budaxcomel)
  echo "https://raw.githubusercontent.com/Budaxcomel/connectifyvpn/main/${path}"
  return 0
}


cvp_fetch_whitelist() {
  # args: url
  local url="$1"
  mkdir -p "$CVP_STATE_DIR" >/dev/null 2>&1 || true

  local tmp="/tmp/${CVP_NAME}_permit.$$"
  if _cvp_fetch "$url" "$tmp"; then
    # simpan cache
    cp -f "$tmp" "$CVP_CACHE_FILE"
    rm -f "$tmp"
    return 0
  fi

  # fallback: guna cache jika masih baru
  if [[ -f "$CVP_CACHE_FILE" ]]; then
    local age=$((_cvp_now_epoch - $(stat -c %Y "$CVP_CACHE_FILE" 2>/dev/null || echo 0)))
    if (( age <= CVP_CACHE_MAX_AGE_SECONDS )); then
      return 0
    fi
  fi
  rm -f "$tmp" >/dev/null 2>&1 || true
  return 1
}

cvp_lookup_entry() {
  # args: ip file
  local ip="$1"
  local file="$2"
  local line=""
  # ignore comments/blank
  line="$(grep -E "^[[:space:]]*${ip}([[:space:]]+|\\|)" "$file" 2>/dev/null | grep -vE '^[[:space:]]*#' | head -n1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi

  local f1 f2 f3 rest
  if [[ "$line" == *"|"* ]]; then
    IFS='|' read -r f1 f2 f3 rest <<<"$line"
  else
    # shellcheck disable=SC2086
    read -r f1 f2 f3 rest <<<"$line"
  fi
  f1="$(echo -n "$f1" | xargs)"
  f2="$(echo -n "$f2" | xargs)"
  f3="$(echo -n "$f3" | xargs)"

  CVP_USERNAME="$f2"
  CVP_EXPIRY="$f3"
  return 0
}

cvp_days_left() {
  # args: expiry_date
  local exp="$1"
  local today="$(_cvp_today)"
  local d1 d2
  d1="$(date -d "$exp" +%s 2>/dev/null || echo 0)"
  d2="$(date -d "$today" +%s 2>/dev/null || echo 0)"
  if [[ "$d1" == "0" || "$d2" == "0" ]]; then
    echo "-99999"
    return 0
  fi
  echo $(((d1 - d2) / 86400))
}

permission_check() {
  # args: optional repo_dir
  local repo_dir="${1:-.}"

  CVP_PUBLIC_IP="$(cvp_get_public_ip || true)"
  if [[ -z "${CVP_PUBLIC_IP:-}" ]]; then
    return 2
  fi

  CVP_PERMISSION_URL="$(cvp_get_permission_url "$repo_dir" || true)"
  if [[ -z "${CVP_PERMISSION_URL:-}" ]]; then
    return 3
  fi

  if ! cvp_fetch_whitelist "$CVP_PERMISSION_URL"; then
    return 4
  fi

  if ! cvp_lookup_entry "$CVP_PUBLIC_IP" "$CVP_CACHE_FILE"; then
    return 5
  fi

  CVP_DAYS_LEFT="$(cvp_days_left "$CVP_EXPIRY")"
  if [[ "$CVP_DAYS_LEFT" =~ ^-?[0-9]+$ ]]; then
    if (( CVP_DAYS_LEFT < 0 )); then
      return 6
    fi
  else
    return 7
  fi

  # Auto simpan config (bila script berjalan sebagai root) supaya menu yang dipasang boleh guna URL yang sama.
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    mkdir -p "/etc/${CVP_NAME}" >/dev/null 2>&1 || true
    if [[ ! -f "$CVP_CONF_FILE" ]]; then
      cat >"$CVP_CONF_FILE" <<EOF
# ConnectifyVPN - Konfigurasi kebenaran
# Anda boleh set salah satu:
#   PERMISSION_URL="https://raw.githubusercontent.com/OWNER/REPO/BRANCH/permission/ipuk/ip"
# atau:
#   PERMISSION_RAW_BASE="https://raw.githubusercontent.com/OWNER/REPO/BRANCH/"
PERMISSION_URL="${CVP_PERMISSION_URL}"
EOF
      chmod 600 "$CVP_CONF_FILE" >/dev/null 2>&1 || true
    fi
  fi

  return 0
}

permission_check_or_exit() {
  local repo_dir="${1:-.}"
  if permission_check "$repo_dir"; then
    return 0
  fi

  local rc=$?
  local ip="${CVP_PUBLIC_IP:-unknown}"
  local url="${CVP_PERMISSION_URL:-unknown}"
  echo -e "\n\e[31m[AKSES DITOLAK]\e[0m Skrip ini memerlukan kebenaran langganan."
  echo -e "IP VPS  : \e[33m${ip}\e[0m"
  echo -e "Sumber  : \e[33m${url}\e[0m"
  case "$rc" in
    2) echo -e "Sebab  : Tidak dapat kesan IP awam VPS." ;;
    3) echo -e "Sebab  : URL whitelist tidak ditemui (tiada config dan bukan git repo)." ;;
    4) echo -e "Sebab  : Gagal muat turun whitelist (GitHub/Internet bermasalah)." ;;
    5) echo -e "Sebab  : IP ini tiada dalam whitelist." ;;
    6) echo -e "Sebab  : Langganan telah tamat tempoh (Expiry: ${CVP_EXPIRY:-unknown})." ;;
    *) echo -e "Sebab  : Semakan kebenaran gagal (kod: $rc)." ;;
  esac
  echo -e "\nJika anda pemilik script:"
  echo -e "1) Pastikan fail whitelist wujud di GitHub (contoh path: ${CVP_PERMISSION_PATH_DEFAULT})"
  echo -e "2) Pastikan format: IP USER EXPIRY (YYYY-MM-DD)"
  echo -e "3) Atau set PERMISSION_URL dalam ${CVP_CONF_FILE}\n"
  exit 1
}
