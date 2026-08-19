#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="${SCRIPT_DIR}/basic-env-install-package.tar.gz"
RUN_USER="${AI_MONITOR_RUN_USER:-linaro}"
failures=0
warnings=0

pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; warnings=$((warnings + 1)); }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

echo "AI Monitor RK3588 basic environment preflight"
echo "run user: ${RUN_USER}"

arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
[[ "${arch}" == "arm64" || "${arch}" == "aarch64" ]] \
  && pass "architecture: ${arch}" \
  || fail "unsupported architecture: ${arch}"

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "22.04" ]]; then
    pass "operating system: ${PRETTY_NAME:-Ubuntu 22.04}"
  else
    fail "expected Ubuntu 22.04, found ${PRETTY_NAME:-unknown}"
  fi
else
  fail "cannot read /etc/os-release"
fi

getent passwd "${RUN_USER}" >/dev/null \
  && pass "run user exists: ${RUN_USER}" \
  || fail "run user does not exist: ${RUN_USER}"

board_model="$(tr -d '\000' </proc/device-tree/model 2>/dev/null || true)"
board_compatible="$(tr '\000' '\n' </proc/device-tree/compatible 2>/dev/null || true)"
if grep -qx 'rockchip,rk3588' <<<"${board_compatible}"; then
  pass "SoC: RK3588 (${board_model:-unknown board})"
else
  fail "expected RK3588, found: ${board_model:-unknown board}"
fi

if [[ -r /sys/kernel/debug/rknpu/version ]]; then
  pass "$(tr -d '\r\n' < /sys/kernel/debug/rknpu/version)"
elif [[ -d /sys/module/rknpu ]]; then
  pass "RKNPU kernel module is loaded"
else
  fail "RKNPU kernel driver was not detected"
fi

[[ -e /dev/dri/renderD129 || -e /dev/dri/renderD128 ]] \
  && pass "DRM render node is present" \
  || fail "no DRM render node found under /dev/dri"

[[ -e /dev/mpp_service || -e /dev/mpp-service ]] && pass "MPP device is present" || warn "MPP device is not present"
[[ -e /dev/rga ]] && pass "RGA device is present" || warn "/dev/rga is not present"
[[ -e /dev/ttyS4 ]] && pass "GPS serial device is present: /dev/ttyS4" || warn "GPS serial device is missing: /dev/ttyS4"

if [[ -r /usr/lib/librknnrt.so ]]; then
  runtime_version="$(strings /usr/lib/librknnrt.so 2>/dev/null | sed -n 's/^librknnrt version: /&/p' | head -n 1)"
  if [[ "${runtime_version}" == *'2.3.2'* ]]; then
    pass "${runtime_version}"
  else
    warn "installed ${runtime_version:-RKNN Runtime version unknown}; package will install 2.3.2"
  fi
else
  warn "RKNN Runtime is not installed; package will install 2.3.2"
fi

if [[ -f "${ARCHIVE}" ]]; then
  pass "runtime archive exists"
  tar -tzf "${ARCHIVE}" >/dev/null 2>&1 \
    && pass "runtime archive is readable" \
    || fail "runtime archive is damaged"
else
  fail "runtime archive not found: ${ARCHIVE}"
fi

if [[ -f "${SCRIPT_DIR}/SHA256SUMS" ]]; then
  if (cd "${SCRIPT_DIR}" && sha256sum -c SHA256SUMS >/dev/null 2>&1); then
    pass "package checksums are valid"
  else
    fail "package checksum verification failed"
  fi
else
  warn "SHA256SUMS is not present"
fi

for package in librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 librga2 librga-dev; do
  if version="$(dpkg-query -W -f='${Version}' "${package}" 2>/dev/null)"; then
    pass "${package}: ${version}"
  else
    warn "${package}: not installed"
  fi
done

for command_name in apt-get dpkg tar sha256sum sudo; do
  command -v "${command_name}" >/dev/null \
    && pass "command available: ${command_name}" \
    || fail "required command missing: ${command_name}"
done

available_kb="$(df -Pk /opt 2>/dev/null | awk 'NR == 2 {print $4}')"
if [[ "${available_kb:-0}" =~ ^[0-9]+$ ]] && (( available_kb >= 3145728 )); then
  pass "free space under /opt: $((available_kb / 1024)) MiB"
else
  fail "at least 3 GiB free space is required under /opt"
fi

for port in 80 554 8000 8001 9000 10000; do
  if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
    warn "ZLMediaKit/nginx port is already in use: ${port}"
  else
    pass "port is free: ${port}"
  fi
done

if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)5555$'; then
  warn "application ZMQ port 5555 is occupied; use 5556 in the application deployment"
fi

echo "summary: failures=${failures}, warnings=${warnings}"
(( failures == 0 ))
