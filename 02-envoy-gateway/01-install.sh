#!/usr/bin/env bash
set -euo pipefail
EG_VERSION="v1.3.0"   # check https://gateway.envoyproxy.io for the latest

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "${EG_VERSION}" \
  -n envoy-gateway-system --create-namespace

kubectl -n envoy-gateway-system wait deployment/envoy-gateway \
  --for=condition=Available --timeout=5m
