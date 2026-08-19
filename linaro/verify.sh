#!/usr/bin/env bash

set -uo pipefail

RUN_USER="${AI_MONITOR_RUN_USER:-linaro}"
failures=0

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

check_path() {
  local path="$1"
  [[ -e "${path}" ]] && pass "exists: ${path}" || fail "missing: ${path}"
}

check_path /usr/lib/librknnrt.so
check_path /usr/include/rknn_api.h
check_path /opt/ffmpeg-rk/bin/ffmpeg
check_path /opt/ffmpeg-rk/bin/ffprobe
check_path /opt/ZLMediaKit/MediaServer
check_path /opt/ZLMediaKit/config.ini

for package in librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 librga2 librga-dev libasound2 libbsd0 libdrm2 libssl3 libxcb1 libxcb-shape0 libxcb-shm0 libxcb-xfixes0 liblzma5 libjemalloc2 libstdc++6 libgcc-s1 libzmq5 zlib1g sqlite3 python3 python3-venv python3-pip nginx rsync; do
  if version="$(dpkg-query -W -f='${Version}' "${package}" 2>/dev/null)"; then
    pass "${package}: ${version}"
  else
    fail "package not installed: ${package}"
  fi
done

if [[ -x /opt/ffmpeg-rk/bin/ffmpeg ]]; then
  /opt/ffmpeg-rk/bin/ffmpeg -version 2>/dev/null | head -n 1
  if ldd /opt/ffmpeg-rk/bin/ffmpeg 2>&1 | grep -q 'not found'; then
    fail "ffmpeg-rk has unresolved shared libraries"
  else
    pass "ffmpeg-rk shared libraries resolved"
  fi
fi

if [[ -x /opt/ZLMediaKit/MediaServer ]]; then
  if ldd /opt/ZLMediaKit/MediaServer 2>&1 | grep -q 'not found'; then
    fail "ZLMediaKit has unresolved shared libraries"
  else
    pass "ZLMediaKit shared libraries resolved"
  fi
fi

if [[ "$(stat -c '%U' /opt/ZLMediaKit 2>/dev/null)" == "${RUN_USER}" ]]; then
  pass "ZLMediaKit owner: ${RUN_USER}"
else
  fail "ZLMediaKit owner is not ${RUN_USER}"
fi

if [[ -r /sys/kernel/debug/rknpu/version ]]; then
  pass "$(tr -d '\r\n' < /sys/kernel/debug/rknpu/version)"
elif [[ -d /sys/module/rknpu ]]; then
  pass "RKNPU kernel module is loaded"
else
  fail "RKNPU kernel driver not detected"
fi

[[ -e /dev/mpp_service ]] && pass "MPP device is present" || fail "/dev/mpp_service is missing"
[[ -e /dev/rga ]] && pass "RGA device is present" || fail "/dev/rga is missing"
[[ -e /dev/dri/renderD129 || -e /dev/dri/renderD128 ]] && pass "DRM render node is present" || fail "DRM render node is missing"

command -v java >/dev/null && java -version 2>&1 | head -n 1 || fail "java command is missing"
command -v nginx >/dev/null && nginx -v 2>&1 || fail "nginx command is missing"
command -v sqlite3 >/dev/null && sqlite3 --version | head -n 1 || fail "sqlite3 command is missing"

echo "summary: failures=${failures}"
(( failures == 0 ))
