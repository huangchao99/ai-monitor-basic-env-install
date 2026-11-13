#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="${SCRIPT_DIR}/basic-env-install-package.tar.gz"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
RUN_USER="${AI_MONITOR_RUN_USER:-linaro}"
ALLOW_ROCKCHIP_REPLACE="${AI_MONITOR_ALLOW_ROCKCHIP_PACKAGE_REPLACE:-0}"
SKIP_APT_UPDATE="${AI_MONITOR_SKIP_APT_UPDATE:-0}"

APT_PACKAGES=(
  ca-certificates
  curl
  rsync
  libasound2
  libbsd0
  libdrm2
  libopencv-dev
  libdrm-dev
  libssl3
  libstdc++6
  libgcc-s1
  libxcb1
  libxcb-shape0
  libxcb-shm0
  libxcb-xfixes0
  liblzma5
  libzmq5
  libjemalloc2
  zlib1g
  sqlite3
  python3
  python3-venv
  python3-pip
  nginx
)

PYTHON_SYNC_PACKAGES=(
  python3.10
  python3.10-minimal
  libpython3.10
  libpython3.10-minimal
  libpython3.10-stdlib
)

SQLITE_SYNC_PACKAGES=(
  libsqlite3-0
)

MPP_DEB_NAMES=(
  librockchip-mpp1_1.5.0-1_arm64.deb
  librockchip-mpp-dev_1.5.0-1_arm64.deb
  librockchip-vpu0_1.5.0-1_arm64.deb
)

RGA_DEB_NAMES=(
  librga2_2.2.0-1_arm64.deb
  librga-dev_2.2.0-1_arm64.deb
)

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die() { echo "[ERROR] $*" >&2; exit 1; }

on_error() {
  local exit_code="$1"
  local line_no="$2"
  echo "[ERROR] install failed: exit=${exit_code}, line=${line_no}" >&2
  echo "[ERROR] log: ${LOG_FILE}" >&2
  exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

prepare_logging() {
  mkdir -p "${LOG_DIR}"
  touch "${LOG_FILE}"
  exec > >(tee -a "${LOG_FILE}") 2>&1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run with sudo: sudo ./install.sh"
}

check_host() {
  [[ "$(dpkg --print-architecture)" == "arm64" ]] || die "only arm64 is supported"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "22.04" ]] \
    || die "this package targets Ubuntu 22.04 arm64"
  local board_compatible
  board_compatible="$(tr '\000' '\n' </proc/device-tree/compatible 2>/dev/null || true)"
  grep -qx 'rockchip,rk3588' <<<"${board_compatible}" \
    || die "this package targets RK3588/RK3588S"
  getent passwd "${RUN_USER}" >/dev/null || die "run user not found: ${RUN_USER}"
  RUN_GROUP="$(id -gn "${RUN_USER}")"
  readonly RUN_GROUP
}

verify_bundle() {
  [[ -f "${ARCHIVE}" ]] || die "archive not found: ${ARCHIVE}"
  if [[ -f "${SCRIPT_DIR}/SHA256SUMS" ]]; then
    log "verifying package checksums"
    (cd "${SCRIPT_DIR}" && sha256sum -c SHA256SUMS)
  else
    warn "SHA256SUMS not found; continuing without bundle checksum verification"
  fi
}

extract_bundle() {
  TMP_DIR="$(mktemp -d /tmp/ai-monitor-basic-env-install.XXXXXX)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"
  PACKAGE_DIR="${TMP_DIR}/basic-env-install-package"
  [[ -d "${PACKAGE_DIR}" ]] || die "basic-env-install-package missing from archive"
  readonly TMP_DIR PACKAGE_DIR
}

check_bundle_files() {
  local required=(
    "${PACKAGE_DIR}/librknnrt.so"
    "${PACKAGE_DIR}/rknn_api.h"
    "${PACKAGE_DIR}/ffmpeg-rk/bin/ffmpeg"
    "${PACKAGE_DIR}/ffmpeg-rk/bin/ffprobe"
    "${PACKAGE_DIR}/ZLMediaKit/MediaServer"
    "${PACKAGE_DIR}/ZLMediaKit/config.ini"
  )
  local name
  for name in "${MPP_DEB_NAMES[@]}"; do required+=("${PACKAGE_DIR}/mpp/${name}"); done
  for name in "${RGA_DEB_NAMES[@]}"; do required+=("${PACKAGE_DIR}/rga2/${name}"); done

  local path
  for path in "${required[@]}"; do
    [[ -e "${path}" ]] || die "required bundle file missing: ${path}"
  done
}

apt_has_candidate() {
  local package="$1"
  apt-cache policy "${package}" 2>/dev/null \
    | awk '/Candidate:/ {candidate=$2} END {exit (candidate == "" || candidate == "(none)")}'
}

select_package() {
  local label="$1"
  shift
  local package
  for package in "$@"; do
    if apt_has_candidate "${package}"; then
      echo "${package}"
      return 0
    fi
  done
  die "no apt candidate found for ${label}; tried: $*"
}

install_apt_packages() {
  if [[ "${SKIP_APT_UPDATE}" != "1" ]]; then
    log "updating apt indexes"
    apt-get update
  else
    warn "AI_MONITOR_SKIP_APT_UPDATE=1: apt-get update skipped"
  fi

  local install_packages=()
  local package
  for package in "${APT_PACKAGES[@]}"; do
    if dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null | grep -qx installed; then
      log "apt package already installed; skip: ${package}"
    else
      install_packages+=("${package}")
    fi
  done

  if ! ldconfig -p 2>/dev/null | grep -q 'libturbojpeg\.so\.0'; then
    install_packages+=("$(select_package turbojpeg libturbojpeg libturbojpeg0)")
  fi

  if ! command -v java >/dev/null 2>&1; then
    install_packages+=("$(select_package Java openjdk-8-jdk openjdk-8-jre-headless default-jre-headless)")
  fi

  if ! dpkg-query -W -f='${db:Status-Status}' python3-venv 2>/dev/null | grep -qx installed; then
    install_packages+=("${PYTHON_SYNC_PACKAGES[@]}")
  fi

  if ! dpkg-query -W -f='${db:Status-Status}' sqlite3 2>/dev/null | grep -qx installed; then
    install_packages+=("${SQLITE_SYNC_PACKAGES[@]}")
  fi

  if (( ${#install_packages[@]} == 0 )); then
    log "all apt dependencies are already installed"
    return
  fi

  log "validating apt dependency transaction"
  apt-get -s --allow-change-held-packages install "${install_packages[@]}"

  log "installing missing apt dependencies"
  apt-get install -y --allow-change-held-packages "${install_packages[@]}"
}

ensure_deb_package() {
  local deb_path="$1"
  local package expected installed
  package="$(dpkg-deb -f "${deb_path}" Package)"
  expected="$(dpkg-deb -f "${deb_path}" Version)"
  installed="$(dpkg-query -W -f='${Version}' "${package}" 2>/dev/null || true)"

  if [[ "${installed}" == "${expected}" ]]; then
    log "${package} ${expected} already installed; skip"
    return
  fi

  if [[ -n "${installed}" && "${ALLOW_ROCKCHIP_REPLACE}" != "1" ]]; then
    die "${package} version ${installed} differs from bundle ${expected}; set AI_MONITOR_ALLOW_ROCKCHIP_PACKAGE_REPLACE=1 only after compatibility review"
  fi

  log "installing ${package} ${expected}"
  dpkg -i "${deb_path}"
}

install_rockchip_packages() {
  local name
  for name in "${MPP_DEB_NAMES[@]}"; do
    ensure_deb_package "${PACKAGE_DIR}/mpp/${name}"
  done
  for name in "${RGA_DEB_NAMES[@]}"; do
    ensure_deb_package "${PACKAGE_DIR}/rga2/${name}"
  done
}

backup_path() {
  local path="$1"
  [[ -e "${path}" || -L "${path}" ]] || return 0
  install -d "${BACKUP_DIR}$(dirname "${path}")"
  mv "${path}" "${BACKUP_DIR}${path}"
  log "backup: ${path} -> ${BACKUP_DIR}${path}"
}

install_file_if_changed() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  if [[ -f "${destination}" ]] && cmp -s "${source}" "${destination}"; then
    log "unchanged: ${destination}"
    return
  fi
  backup_path "${destination}"
  install -D -m "${mode}" "${source}" "${destination}"
}

install_runtime_files() {
  BACKUP_DIR="/var/backups/ai-monitor-basic-env/$(date +%Y%m%d-%H%M%S)"
  readonly BACKUP_DIR

  log "installing RKNN runtime"
  install_file_if_changed "${PACKAGE_DIR}/librknnrt.so" /usr/lib/librknnrt.so 0755
  install_file_if_changed "${PACKAGE_DIR}/rknn_api.h" /usr/include/rknn_api.h 0644
  ldconfig

  log "installing ffmpeg-rk"
  backup_path /opt/ffmpeg-rk
  cp -a "${PACKAGE_DIR}/ffmpeg-rk" /opt/ffmpeg-rk
  chmod 0755 /opt/ffmpeg-rk/bin/ffmpeg /opt/ffmpeg-rk/bin/ffprobe

  log "installing ZLMediaKit for ${RUN_USER}:${RUN_GROUP}"
  backup_path /opt/ZLMediaKit
  cp -a "${PACKAGE_DIR}/ZLMediaKit" /opt/ZLMediaKit
  install -d /opt/ZLMediaKit/log /opt/ZLMediaKit/www/live /opt/ZLMediaKit/www/snap
  chmod 0755 /opt/ZLMediaKit/MediaServer
  chown -R "${RUN_USER}:${RUN_GROUP}" /opt/ZLMediaKit
}

main() {
  prepare_logging
  require_root
  check_host
  verify_bundle
  extract_bundle
  check_bundle_files
  install_apt_packages
  install_rockchip_packages
  install_runtime_files

  log "base environment installed"
  log "backup directory: ${BACKUP_DIR}"
  log "no services were installed or started"
  log "run: ./verify.sh"
}

main "$@"
