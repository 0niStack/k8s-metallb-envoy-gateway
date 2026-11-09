#!/usr/bin/env bash
cd "$(dirname "$0")"
kubectl delete -f 05-gateway/ --ignore-not-found
kubectl delete -f 04-apps/ --ignore-not-found
kubectl delete namespace web --ignore-not-found
