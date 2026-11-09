#!/usr/bin/env bash
set -euo pipefail
METALLB_VERSION="v0.14.9"

kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl -n metallb-system wait deployment/controller --for=condition=Available --timeout=3m
kubectl -n metallb-system rollout status daemonset/speaker --timeout=3m
