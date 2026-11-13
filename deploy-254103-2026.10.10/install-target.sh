#!/usr/bin/env bash
set -euo pipefail
cd /home/linaro/deploy-254103-2026.10.10
ips=$(getent ahostsv4 mirrors.ustc.edu.cn | awk '{print $1}' | sort -u)
added=()
cleanup() {
  for ip in "${added[@]}"; do sudo -n ip route del "$ip/32" via 192.168.254.1 dev wlan0 || true; done
}
trap cleanup EXIT
for ip in $ips; do
  if ! ip route show "$ip/32" | grep -q .; then
    sudo -n ip route add "$ip/32" via 192.168.254.1 dev wlan0
    added+=("$ip")
  fi
done
sudo -n env APT_CONFIG="$PWD/apt-ipv4.conf" AI_MONITOR_SKIP_APT_UPDATE=1 ./install.sh
sudo -n ./verify.sh
