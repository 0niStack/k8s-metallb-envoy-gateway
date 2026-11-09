#!/usr/bin/env bash
# Full health check: MetalLB -> Envoy Gateway -> apps -> gateway -> HTTP/HTTPS
set -uo pipefail
cd "$(dirname "$0")"

GREEN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; NC=$'\e[0m'
fail=0
ok()  { echo "  ${GREEN}[ OK ]${NC} $*"; }
bad() { echo "  ${RED}[FAIL]${NC} $*"; fail=$((fail+1)); }
hdr() { echo; echo "== $* =="; }

hdr "A. MetalLB"
./01-metallb/04-check-metallb.sh || fail=$((fail+1))

hdr "B. Envoy Gateway"
r=$(kubectl -n envoy-gateway-system get deploy envoy-gateway -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${r:-0}" -ge 1 ] && ok "envoy-gateway controller ready" || bad "envoy-gateway controller not ready"
kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null | grep -q True \
  && ok "GatewayClass eg accepted" || bad "GatewayClass eg not accepted"

hdr "C. TLS secrets (namespace web)"
for s in tls-nginx tls-apache; do
  kubectl -n web get secret "$s" >/dev/null 2>&1 && ok "secret $s" || bad "secret $s missing"
done

hdr "D. Apps"
for d in nginx apache; do
  r=$(kubectl -n web get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "${r:-0}" -ge 1 ] && ok "$d ready ($r replicas)" || bad "$d not ready"
done

hdr "E. Gateway and routes"
IP=$(kubectl -n web get gateway main-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
PROG=$(kubectl -n web get gateway main-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
[ -n "$IP" ] && ok "gateway address $IP" || bad "gateway has no address"
[ "$PROG" = "True" ] && ok "gateway Programmed=True" || bad "gateway Programmed=${PROG:-Unknown}"
for rt in nginx-route apache-route; do
  acc=$(kubectl -n web get httproute "$rt" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
  [ "$acc" = "True" ] && ok "$rt accepted" || bad "$rt not accepted"
done

hdr "F. Live requests via $IP"
if [ -n "$IP" ]; then
  for host in nginx.example.local apache.example.local; do
    for sp in http:80 https:443; do
      s=${sp%%:*}; p=${sp##*:}
      out=$(curl -sk --max-time 5 --resolve "${host}:${p}:${IP}" "${s}://${host}/" 2>/dev/null)
      [ -n "$out" ] && ok "$s://$host -> $out" || bad "$s://$host no response"
    done
  done
fi

echo
[ "$fail" -eq 0 ] && echo "${GREEN}ALL CHECKS PASSED${NC}" || { echo "${RED}$fail problem(s) found${NC} - see README.md > Troubleshooting"; exit 1; }
