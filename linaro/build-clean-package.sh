#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ARCHIVE="${AI_MONITOR_SOURCE_ARCHIVE:-${SCRIPT_DIR}/../basic-env-deps.tar.gz}"
OUTPUT_ARCHIVE="${SCRIPT_DIR}/basic-env-install-package.tar.gz"
TEMP_ARCHIVE="${OUTPUT_ARCHIVE}.tmp.$$"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[[ -f "${SOURCE_ARCHIVE}" ]] || die "source archive not found: ${SOURCE_ARCHIVE}"
[[ ! -e "${OUTPUT_ARCHIVE}" ]] || die "output already exists: ${OUTPUT_ARCHIVE}"

TMP_DIR="$(mktemp -d /tmp/ai-monitor-basic-env-linaro.XXXXXX)"
cleanup() {
  rm -rf "${TMP_DIR}"
  rm -f "${TEMP_ARCHIVE}"
}
trap cleanup EXIT

echo "[build] extracting clean runtime tree"
tar -xzf "${SOURCE_ARCHIVE}" -C "${TMP_DIR}" \
  --exclude='basic-env-install-package/ZLMediaKit/www/live' \
  --exclude='basic-env-install-package/ZLMediaKit/www/snap' \
  --exclude='basic-env-install-package/ZLMediaKit/log' \
  --exclude='basic-env-install-package/ZLMediaKit/logs' \
  --exclude='basic-env-install-package/ZLMediaKit/ffmpeg' \
  --exclude='basic-env-install-package/ZLMediaKit/.git' \
  --exclude='basic-env-install-package/ZLMediaKit/www/webassist/.git' \
  --exclude='basic-env-install-package/ZLMediaKit/*.log' \
  --exclude='basic-env-install-package/ZLMediaKit/core*'

PACKAGE_DIR="${TMP_DIR}/basic-env-install-package"
[[ -d "${PACKAGE_DIR}" ]] || die "archive does not contain basic-env-install-package"

install -d \
  "${PACKAGE_DIR}/ZLMediaKit/log" \
  "${PACKAGE_DIR}/ZLMediaKit/www/live" \
  "${PACKAGE_DIR}/ZLMediaKit/www/snap"

required=(
  "${PACKAGE_DIR}/librknnrt.so"
  "${PACKAGE_DIR}/rknn_api.h"
  "${PACKAGE_DIR}/ffmpeg-rk/bin/ffmpeg"
  "${PACKAGE_DIR}/ffmpeg-rk/bin/ffprobe"
  "${PACKAGE_DIR}/ZLMediaKit/MediaServer"
  "${PACKAGE_DIR}/ZLMediaKit/config.ini"
  "${PACKAGE_DIR}/mpp/librockchip-mpp1_1.5.0-1_arm64.deb"
  "${PACKAGE_DIR}/mpp/librockchip-mpp-dev_1.5.0-1_arm64.deb"
  "${PACKAGE_DIR}/mpp/librockchip-vpu0_1.5.0-1_arm64.deb"
  "${PACKAGE_DIR}/rga2/librga2_2.2.0-1_arm64.deb"
  "${PACKAGE_DIR}/rga2/librga-dev_2.2.0-1_arm64.deb"
)

for path in "${required[@]}"; do
  [[ -e "${path}" ]] || die "required file missing after extraction: ${path}"
done

if find "${PACKAGE_DIR}/ZLMediaKit/www/live" "${PACKAGE_DIR}/ZLMediaKit/www/snap" -type f -print -quit | grep -q .; then
  die "runtime archive still contains ZLMediaKit recordings or snapshots"
fi

echo "[build] creating ${OUTPUT_ARCHIVE}"
tar -czf "${TEMP_ARCHIVE}" -C "${TMP_DIR}" basic-env-install-package
gzip -t "${TEMP_ARCHIVE}"
mv "${TEMP_ARCHIVE}" "${OUTPUT_ARCHIVE}"
echo "[build] done"
