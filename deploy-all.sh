#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "== 01 MetalLB ==";        ./01-metallb/01-install.sh
kubectl apply -f 01-metallb/02-ip-pool.yaml

echo "== 02 Envoy Gateway ==";  ./02-envoy-gateway/01-install.sh
kubectl apply -f 02-envoy-gateway/02-gatewayclass.yaml

echo "== 03 TLS ==";            ./03-tls/01-generate-certs.sh
                               ./03-tls/02-create-secrets.sh

echo "== 04 Apps ==";           kubectl apply -f 04-apps/01-nginx.yaml -f 04-apps/02-apache.yaml
echo "== 05 Gateway ==";        kubectl apply -f 05-gateway/01-gateway.yaml -f 05-gateway/02-httproutes.yaml

echo; echo "Gateway address:"
kubectl -n web get gateway main-gateway
