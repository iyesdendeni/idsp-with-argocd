# SSP connectivity checklist: https://ssp.id-broadcom.com/default/ui/v1/adminconsole/

Use this when the Admin Console URL does not load. Run from a machine that can reach the cluster and the internet.

## 1. Which environment are you using?

- **idsp-ing** (nginx ingress, LB IP `34.19.89.223` from `ingress-ing-values.yaml`)
- **idsp-gw** (GKE Gateway API; IP from the Gateway status)

Use the steps below for the environment that serves `ssp.id-broadcom.com`.

---

## 2. DNS

```bash
# Must resolve to your ingress/gateway external IP
dig +short ssp.id-broadcom.com
# or
nslookup ssp.id-broadcom.com
```

- **idsp-ing:** Should resolve to `34.19.89.223` (or your nginx ingress LoadBalancer IP).
- **idsp-gw:** Should resolve to the Gateway’s external address.

If it does not resolve or points to the wrong IP, fix DNS (e.g. add/update a CNAME or A record for `ssp.id-broadcom.com`).

---

## 3. TLS secret (HTTPS)

The ingress/gateway uses `ssp-general-tls` for TLS. It must exist in the **same namespace as the SSP app** (e.g. `ssp-ing` or `ssp-gw`).

```bash
# idsp-ing
kubectl get secret ssp-general-tls -n ssp-ing

# idsp-gw
kubectl get secret ssp-general-tls -n ssp-gw
```

If missing, create a TLS secret (e.g. from cert-manager or your certificate) in that namespace with name `ssp-general-tls` (and correct `tls.crt` / `tls.key` for `ssp.id-broadcom.com`).

---

## 4. Ingress / Gateway and backend

**idsp-ing (nginx):**

```bash
# Ingress for ssp.id-broadcom.com
kubectl get ingress -A | grep -E "ssp|id-broadcom"

# Ingress details (host, TLS, backend service)
kubectl get ingress -n ssp-ing -o yaml
# or
kubectl describe ingress -n ssp-ing
```

**idsp-gw (Gateway API):**

```bash
kubectl get gateway,httproute -n ssp-gw
kubectl describe gateway -n ssp-gw
kubectl describe httproute -n ssp-gw
```

Confirm:

- Host is `ssp.id-broadcom.com` (or a rule that matches it).
- TLS is configured and uses `ssp-general-tls` in the app namespace.
- Backend service/port points to the SSP service (e.g. in `ssp-ing` or `ssp-gw`).

---

## 5. SSP app and service

```bash
# idsp-ing
kubectl get pods,svc -n ssp-ing | grep -E "ssp|NAME"

# idsp-gw
kubectl get pods,svc -n ssp-gw | grep -E "ssp|NAME"
```

- Pods should be `Running` and ready (e.g. `1/1` or `2/2`).
- There should be a Service (e.g. `ssp-ssp` or similar) and the Ingress/HTTPRoute backend should reference it by name and port.

---

## 6. Quick curl from inside the cluster (optional)

```bash
# Pick a pod in the same cluster (e.g. an SSP pod or any pod in ssp-ing/ssp-gw)
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -k -v -H "Host: ssp.id-broadcom.com" \
  https://<INGRESS_OR_GATEWAY_IP>/default/ui/v1/adminconsole/
```

Replace `<INGRESS_OR_GATEWAY_IP>` with the IP from step 2. This checks routing and TLS to the backend; if this works but the browser does not, the issue is DNS or client-side (certificate, firewall).

---

## Summary

| Check              | idsp-ing                      | idsp-gw                    |
|--------------------|-------------------------------|----------------------------|
| DNS                | → nginx LB IP (e.g. 34.19.89.223) | → Gateway external IP     |
| TLS secret         | `ssp-general-tls` in `ssp-ing` | `ssp-general-tls` in `ssp-gw` |
| Routing            | `Ingress` in `ssp-ing`        | `Gateway` + `HTTPRoute` in `ssp-gw` |
| Backend            | SSP pods + Service in `ssp-ing` | SSP pods + Service in `ssp-gw` |

Most often the problem is one of: **DNS not pointing to the right IP**, **missing or wrong TLS secret**, or **SSP pods not running**.
