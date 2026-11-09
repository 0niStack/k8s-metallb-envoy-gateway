# MetalLB + Envoy Gateway (nginx 01 / apache 02)

```
Client --80/443--> MetalLB IP --> Envoy Gateway --+-- nginx.example.local  -> nginx  (01)
                                                  +-- apache.example.local -> apache (02)
```

## Layout
| Folder | Purpose |
|---|---|
| `01-metallb/` | Install MetalLB, define IP pool + L2 advertisement |
| `02-envoy-gateway/` | Install Envoy Gateway, GatewayClass, pin LoadBalancer IP |
| `03-tls/` | Generate self-signed certs, create TLS secrets |
| `04-apps/` | `01-nginx.yaml`, `02-apache.yaml` |
| `05-gateway/` | Gateway (80 + 443) and HTTPRoutes by hostname |

## Before you run
1. Edit `01-metallb/02-ip-pool.yaml` - set a free range in your LAN.
2. Edit `02-envoy-gateway/02-gatewayclass.yaml` - `loadBalancerIPs` must be inside that range (or delete the line for auto-assign).
3. Hostnames are `nginx.example.local` / `apache.example.local`; to change them edit `03-tls/*.sh`, `05-gateway/*.yaml`, `test.sh`.

## Run
```bash
./deploy-all.sh
./test.sh
```

## Use from your browser
Add to `/etc/hosts` (Windows: `C:\Windows\System32\drivers\etc\hosts`):
```
192.168.1.240  nginx.example.local apache.example.local
```
Open `https://nginx.example.local` and `https://apache.example.local` (accept the self-signed warning).

## Remove
`./cleanup.sh`
