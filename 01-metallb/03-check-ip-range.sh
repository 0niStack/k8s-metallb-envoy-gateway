#!/usr/bin/env bash
# PRE-CHECK: are the IPs we want to give MetalLB actually free?
# Usage: ./03-check-ip-range.sh [PREFIX] [START] [END]
#   default: 172.30.1  240  250
# Run this BEFORE applying 02-ip-pool.yaml.
# (After the gateway is deployed, the gateway IP WILL answer - that is expected.)
set -uo pipefail

PREFIX="${1:-172.30.1}"
START="${2:-240}"
END="${3:-250}"

GREEN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; NC=$'\e[0m'
busy=0

echo "Node addresses:"
kubectl get nodes -o wide 2>/dev/null | awk '{print "  "$1"  "$6}' || true
echo
echo "Default route / local subnet:"
ip route 2>/dev/null | grep -E '^default|proto (dhcp|kernel).*src' | sed 's/^/  /' || true
echo
echo "Checking ${PREFIX}.${START} - ${PREFIX}.${END} ..."

for i in $(seq "$START" "$END"); do
  ip="${PREFIX}.${i}"
  used=""
  ping -c1 -W1 "$ip" >/dev/null 2>&1 && used="answers ping"
  if [ -z "$used" ] && command -v arping >/dev/null 2>&1; then
    arping -c1 -w1 "$ip" >/dev/null 2>&1 && used="answers ARP"
  fi
  if [ -n "$used" ]; then
    echo "  ${RED}IN USE${NC}  $ip  ($used)"; busy=$((busy+1))
  else
    echo "  ${GREEN}free  ${NC}  $ip"
  fi
done

echo
if [ "$busy" -eq 0 ]; then
  echo "${GREEN}OK${NC}: whole range looks free."
else
  echo "${YEL}WARNING${NC}: $busy address(es) in use. Pick another range or edit 02-ip-pool.yaml."
  echo "Also make sure your router's DHCP range does not overlap ${PREFIX}.${START}-${END}."
  exit 1
fi
