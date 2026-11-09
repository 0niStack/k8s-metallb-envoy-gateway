#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

kubectl create namespace web --dry-run=client -o yaml | kubectl apply -f -

for h in nginx.example.local apache.example.local; do
  name="tls-${h%%.*}"     # tls-nginx / tls-apache
  kubectl -n web create secret tls "$name" \
    --cert="certs/${h}.crt" --key="certs/${h}.key" \
    --dry-run=client -o yaml | kubectl apply -f -
done
