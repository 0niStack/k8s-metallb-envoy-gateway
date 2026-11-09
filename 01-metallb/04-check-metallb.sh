#!/usr/bin/env bash
# POST-CHECK: is MetalLB installed, healthy and handing out addresses?
# Usage: ./04-check-metallb.sh
set -uo pipefail

GREEN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; NC=$'\e[0m'
fail=0
ok()   { echo "  ${GREEN}[ OK ]${NC} $*"; }
bad()  { echo "  ${RED}[FAIL]${NC} $*"; fail=$((fail+1)); }
warn() { echo "  ${YEL}[WARN]${NC} $*"; }
hdr()  { echo; echo "== $* =="; }

hdr "1. Cluster access"
kubectl version --request-timeout=5s >/dev/null 2>&1 && ok "kubectl can reach the cluster" || { bad "kubectl cannot reach the cluster"; exit 1; }

hdr "2. MetalLB namespace and CRDs"
kubectl get ns metallb-system >/dev/null 2>&1 && ok "namespace metallb-system exists" || bad "namespace metallb-system missing (run ./01-install.sh)"
for crd in ipaddresspools.metallb.io l2advertisements.metallb.io; do
  kubectl get crd "$crd" >/dev/null 2>&1 && ok "CRD $crd" || bad "CRD $crd missing"
done

hdr "3. Controller"
ready=$(kubectl -n metallb-system get deploy controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
want=$(kubectl -n metallb-system get deploy controller -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ -n "$ready" ] && [ "$ready" = "$want" ] && ok "controller ready ($ready/$want)" || bad "controller not ready (${ready:-0}/${want:-?})"

hdr "4. Speaker (one per node)"
desired=$(kubectl -n metallb-system get ds speaker -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
rdy=$(kubectl -n metallb-system get ds speaker -o jsonpath='{.status.numberReady}' 2>/dev/null)
[ -n "$rdy" ] && [ "$rdy" = "$desired" ] && ok "speaker ready on $rdy/$desired nodes" || bad "speaker ready on ${rdy:-0}/${desired:-?} nodes"
kubectl -n metallb-system get pods -l component=speaker -o wide 2>/dev/null | sed 's/^/     /'

hdr "5. IPAddressPool"
pools=$(kubectl -n metallb-system get ipaddresspools -o name 2>/dev/null)
if [ -z "$pools" ]; then
  bad "no IPAddressPool found (kubectl apply -f 02-ip-pool.yaml)"
else
  for p in $pools; do
    addr=$(kubectl -n metallb-system get "$p" -o jsonpath='{.spec.addresses}' 2>/dev/null)
    ok "$p  ->  $addr"
  done
fi

hdr "6. L2Advertisement"
l2=$(kubectl -n metallb-system get l2advertisements -o name 2>/dev/null)
if [ -z "$l2" ]; then
  bad "no L2Advertisement found - IPs would be assigned but never announced"
else
  for a in $l2; do
    sel=$(kubectl -n metallb-system get "$a" -o jsonpath='{.spec.nodeSelectors[*].matchLabels}' 2>/dev/null)
    ok "$a  nodeSelector: ${sel:-<all nodes>}"
  done
fi

hdr "7. LoadBalancer services and assigned IPs"
lb=$(kubectl get svc -A --field-selector spec.type=LoadBalancer --no-headers 2>/dev/null)
if [ -z "$lb" ]; then
  warn "no LoadBalancer services yet (normal before the gateway is deployed)"
else
  echo "$lb" | while read -r ns name type cip eip rest; do
    if [ "$eip" = "<pending>" ] || [ -z "$eip" ]; then
      echo "  ${RED}[FAIL]${NC} $ns/$name  EXTERNAL-IP pending"
    else
      echo "  ${GREEN}[ OK ]${NC} $ns/$name  EXTERNAL-IP $eip"
    fi
  done
  echo "$lb" | grep -q '<pending>' && fail=$((fail+1))
fi

hdr "8. Reachability of assigned IPs (from this machine)"
for eip in $(kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}' 2>/dev/null); do
  [ -z "$eip" ] && continue
  if ping -c1 -W1 "$eip" >/dev/null 2>&1; then ok "$eip answers ping"
  elif timeout 3 bash -c "echo > /dev/tcp/$eip/80" 2>/dev/null; then ok "$eip port 80 open"
  else warn "$eip not reachable from here (check subnet / firewall / speaker node)"; fi
done

hdr "9. Recent errors in MetalLB logs"
errs=$(kubectl -n metallb-system logs deploy/controller --tail=200 2>/dev/null | grep -Ei '"level":"error"|level=error' | tail -5)
[ -z "$errs" ] && ok "no recent errors in controller log" || { warn "controller log has errors:"; echo "$errs" | sed 's/^/     /'; }

echo
if [ "$fail" -eq 0 ]; then
  echo "${GREEN}MetalLB looks healthy.${NC}"
else
  echo "${RED}$fail check(s) failed.${NC}  See README.md > Troubleshooting."
  exit 1
fi
