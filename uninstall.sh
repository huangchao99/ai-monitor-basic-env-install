#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/uninstall-$(date +%Y%m%d-%H%M%S).log"

readonly SCRIPT_DIR LOG_DIR LOG_FILE

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
  echo "[ERROR] 卸载失败，退出码=${exit_code}，出错行=${line_no}" >&2
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

remove_if_exists() {
  local target="$1"
  if [[ -e "${target}" || -L "${target}" ]]; then
    log "删除 ${target}"
    run_root rm -rf "${target}"
  else
    warn "${target} 不存在，跳过"
  fi
}

remove_backups() {
  local pattern="$1"
  shopt -s nullglob
  local matches=( ${pattern} )
  shopt -u nullglob

  local target
  for target in "${matches[@]}"; do
    log "删除备份 ${target}"
    run_root rm -rf "${target}"
  done
}

remove_debs() {
  log "卸载通过本脚本安装的 mpp/rga 包"
  local packages=(
    librga-dev
    librga2
    librockchip-mpp-dev
    librockchip-vpu0
    librockchip-mpp1
  )

  local installed=()
  local pkg
  for pkg in "${packages[@]}"; do
    if dpkg -s "${pkg}" >/dev/null 2>&1; then
      installed+=("${pkg}")
    fi
  done

  if (( ${#installed[@]} > 0 )); then
    run_root apt-get remove -y "${installed[@]}"
  else
    warn "mpp/rga 相关 deb 包未检测到，跳过"
  fi
}

print_summary() {
  cat <<EOF

[INFO] 基础环境卸载完成
[INFO] 日志文件: ${LOG_FILE}
[INFO] 已移除内容:
[INFO]   - /usr/lib/librknnrt.so
[INFO]   - /usr/include/rknn_api.h
[INFO]   - /opt/ffmpeg-rk
[INFO]   - /opt/ZLMediaKit
[INFO]   - mpp/rga 运行包和 dev 包
[INFO] 未卸载 apt 通用依赖，以避免影响系统其他组件。

EOF
}

main() {
  prepare_logging
  require_sudo

  remove_if_exists /usr/lib/librknnrt.so
  remove_if_exists /usr/include/rknn_api.h
  remove_if_exists /opt/ffmpeg-rk
  remove_if_exists /opt/ZLMediaKit
  remove_backups "/opt/ffmpeg-rk.bak.*"
  remove_backups "/opt/ZLMediaKit.bak.*"
  remove_debs
  run_root ldconfig
  print_summary
}

main "$@"
