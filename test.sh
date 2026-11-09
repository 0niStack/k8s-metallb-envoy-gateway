#!/usr/bin/env bash
# Usage: ./test.sh [GATEWAY_IP]   (auto-detected if omitted)
set -euo pipefail
IP="${1:-$(kubectl -n web get gateway main-gateway -o jsonpath='{.status.addresses[0].value}')}"
echo "Gateway IP: $IP"

for host in nginx.example.local apache.example.local; do
  for sp in "http:80" "https:443"; do
    s=${sp%%:*}; p=${sp##*:}
    printf '%-6s %-24s -> ' "$s" "$host"
    curl -sk --resolve "${host}:${p}:${IP}" "${s}://${host}/"
  done
done
