#!/usr/bin/env bash
# Generates one self-signed cert per hostname into ./certs
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs

HOSTS=("nginx.example.local" "apache.example.local")

for h in "${HOSTS[@]}"; do
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 365 \
    -keyout "certs/${h}.key" -out "certs/${h}.crt" \
    -subj "/CN=${h}/O=lab" \
    -addext "subjectAltName=DNS:${h}"
  echo "created certs/${h}.{crt,key}"
done
