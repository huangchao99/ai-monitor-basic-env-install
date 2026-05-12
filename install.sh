#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/basic-env-install-package"
PACKAGE_ZIP="${SCRIPT_DIR}/basic-env-install-package.zip"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

APT_PACKAGES=(
  git
  build-essential
  yasm
  pkg-config
  libdrm-dev
  libx264-dev
  libx265-dev
  libvpx-dev
  libfdk-aac-dev
  libmp3lame-dev
  libopus-dev
  libturbojpeg
  libzmq5
  libjemalloc2
  sqlite3
  python3
  python3-venv
  python3-pip
  curl
  openjdk-8-jdk
  nginx
)

MPP_DEBS=(
  "${PACKAGE_DIR}/mpp/librockchip-mpp1_1.5.0-1_arm64.deb"
  "${PACKAGE_DIR}/mpp/librockchip-mpp-dev_1.5.0-1_arm64.deb"
  "${PACKAGE_DIR}/mpp/librockchip-vpu0_1.5.0-1_arm64.deb"
)

RGA_DEBS=(
  "${PACKAGE_DIR}/rga2/librga2_2.2.0-1_arm64.deb"
  "${PACKAGE_DIR}/rga2/librga-dev_2.2.0-1_arm64.deb"
)

readonly SCRIPT_DIR PACKAGE_DIR PACKAGE_ZIP LOG_DIR LOG_FILE

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

on_error() {
  local exit_code="$1"
  local line_no="$2"
  echo "[ERROR] 安装失败，退出码=${exit_code}，出错行=${line_no}" >&2
  echo "[ERROR] 请检查日志: ${LOG_FILE}" >&2
  exit "${exit_code}"
}

trap 'on_error $? $LINENO' ERR

prepare_logging() {
  mkdir -p "${LOG_DIR}"
  touch "${LOG_FILE}"
  exec > >(tee -a "${LOG_FILE}") 2>&1
}

require_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      die "当前不是 root，且系统未找到 sudo。"
    fi
    SUDO="sudo"
  else
    SUDO=""
  fi
}

run_root() {
  if [[ -n "${SUDO}" ]]; then
    "${SUDO}" "$@"
  else
    "$@"
  fi
}

check_os() {
  log "检查系统环境"

  local arch
  arch="$(dpkg --print-architecture)"
  [[ "${arch}" == "arm64" ]] || die "仅支持 arm64，当前架构: ${arch}"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || die "仅支持 Ubuntu，当前系统: ${ID:-unknown}"
    case "${VERSION_ID:-}" in
      20.04|22.04) ;;
      *)
        warn "当前 Ubuntu 版本为 ${VERSION_ID:-unknown}，脚本按 20.04/22.04 设计，继续执行请自行确认兼容性。"
        ;;
    esac
  else
    warn "无法读取 /etc/os-release，跳过发行版检查。"
  fi
}

extract_package_if_needed() {
  if [[ -d "${PACKAGE_DIR}" ]]; then
    return
  fi

  [[ -f "${PACKAGE_ZIP}" ]] || die "未找到安装包目录 ${PACKAGE_DIR}，也未找到压缩包 ${PACKAGE_ZIP}"

  log "检测到安装包压缩文件，准备解压: ${PACKAGE_ZIP}"

  if command -v unzip >/dev/null 2>&1; then
    unzip -q "${PACKAGE_ZIP}" -d "${SCRIPT_DIR}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "${PACKAGE_ZIP}" "${SCRIPT_DIR}"
  else
    die "系统未找到 unzip 或 python3，无法解压 ${PACKAGE_ZIP}"
  fi

  [[ -d "${PACKAGE_DIR}" ]] || die "压缩包已解压，但未找到目录: ${PACKAGE_DIR}"
}

check_package_files() {
  log "检查安装包内容"

  local required_files=(
    "${PACKAGE_DIR}/librknnrt.so"
    "${PACKAGE_DIR}/rknn_api.h"
    "${PACKAGE_DIR}/ffmpeg-rk/bin/ffmpeg"
    "${PACKAGE_DIR}/ffmpeg-rk/bin/ffprobe"
    "${PACKAGE_DIR}/ZLMediaKit/MediaServer"
    "${PACKAGE_DIR}/ZLMediaKit/config.ini"
    "${MPP_DEBS[@]}"
    "${RGA_DEBS[@]}"
  )

  local missing=()
  local file
  for file in "${required_files[@]}"; do
    [[ -e "${file}" ]] || missing+=("${file}")
  done

  if (( ${#missing[@]} > 0 )); then
    printf '[ERROR] 缺少以下安装包文件:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
}

install_apt_packages() {
  log "安装系统依赖包"
  run_root apt-get update
  run_root apt-get install -y "${APT_PACKAGES[@]}"
}

install_deb_group() {
  local group_name="$1"
  shift

  log "安装 ${group_name} deb 包"
  run_root dpkg -i "$@" || {
    warn "${group_name} 初次安装存在依赖问题，尝试 apt-get -f install 修复"
    run_root apt-get install -f -y
    run_root dpkg -i "$@"
  }
}

install_rknn_runtime() {
  log "安装 RKNN Runtime"
  run_root install -m 0755 "${PACKAGE_DIR}/librknnrt.so" /usr/lib/librknnrt.so
  run_root install -m 0644 "${PACKAGE_DIR}/rknn_api.h" /usr/include/rknn_api.h
  run_root ldconfig
}

copy_dir_with_backup() {
  local src="$1"
  local dst="$2"

  if [[ -e "${dst}" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    warn "目标已存在，先备份: ${dst} -> ${backup}"
    run_root mv "${dst}" "${backup}"
  fi

  run_root mkdir -p "$(dirname "${dst}")"
  run_root cp -a "${src}" "${dst}"
}

install_ffmpeg_rk() {
  log "安装 ffmpeg-rk 到 /opt/ffmpeg-rk"
  copy_dir_with_backup "${PACKAGE_DIR}/ffmpeg-rk" /opt/ffmpeg-rk
  run_root chmod 0755 /opt/ffmpeg-rk/bin/ffmpeg /opt/ffmpeg-rk/bin/ffprobe
}

install_zlmediakit() {
  log "安装 ZLMediaKit 到 /opt/ZLMediaKit"
  copy_dir_with_backup "${PACKAGE_DIR}/ZLMediaKit" /opt/ZLMediaKit
  run_root chmod 0755 /opt/ZLMediaKit/MediaServer
  run_root mkdir -p /opt/ZLMediaKit/log
  run_root chown -R hzhy:hzhy /opt/ZLMediaKit
}

verify_installation() {
  log "校验安装结果"

  local required_paths=(
    /usr/lib/librknnrt.so
    /usr/include/rknn_api.h
    /opt/ffmpeg-rk/bin/ffmpeg
    /opt/ffmpeg-rk/bin/ffprobe
    /opt/ZLMediaKit/MediaServer
    /opt/ZLMediaKit/config.ini
  )

  local path
  for path in "${required_paths[@]}"; do
    [[ -e "${path}" ]] || die "安装校验失败，文件不存在: ${path}"
  done

  dpkg -s librockchip-mpp1 >/dev/null 2>&1 || die "安装校验失败: librockchip-mpp1 未安装"
  dpkg -s librockchip-mpp-dev >/dev/null 2>&1 || die "安装校验失败: librockchip-mpp-dev 未安装"
  dpkg -s librockchip-vpu0 >/dev/null 2>&1 || die "安装校验失败: librockchip-vpu0 未安装"
  dpkg -s librga2 >/dev/null 2>&1 || die "安装校验失败: librga2 未安装"
  dpkg -s librga-dev >/dev/null 2>&1 || die "安装校验失败: librga-dev 未安装"

  local apt_pkg
  for apt_pkg in "${APT_PACKAGES[@]}"; do
    dpkg -s "${apt_pkg}" >/dev/null 2>&1 || die "安装校验失败: ${apt_pkg} 未安装"
  done
}

print_summary() {
  cat <<EOF

[INFO] 基础环境安装完成
[INFO] 日志文件: ${LOG_FILE}
[INFO] 已安装内容:
[INFO]   - mpp: librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0
[INFO]   - rga: librga2 librga-dev
[INFO]   - RKNN Runtime: /usr/lib/librknnrt.so /usr/include/rknn_api.h
[INFO]   - ffmpeg-rk: /opt/ffmpeg-rk
[INFO]   - ZLMediaKit: /opt/ZLMediaKit
[INFO]   - apt 依赖: ${APT_PACKAGES[*]}

EOF
}

main() {
  prepare_logging
  require_sudo
  check_os
  extract_package_if_needed
  check_package_files
  install_apt_packages
  install_deb_group "mpp" "${MPP_DEBS[@]}"
  install_deb_group "rga" "${RGA_DEBS[@]}"
  install_rknn_runtime
  install_ffmpeg_rk
  install_zlmediakit
  verify_installation
  print_summary
}

main "$@"
