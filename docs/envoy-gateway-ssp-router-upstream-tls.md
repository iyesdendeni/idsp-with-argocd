# Envoy Gateway → SSP router: upstream TLS / `connection termination`

## Symptom

Browser or `curl` through Envoy shows:

`upstream connect error or disconnect/reset before headers. reset reason: connection termination`

Envoy access log (data plane) often shows:

`upstream_reset_before_response_started{connection_termination}` with `upstream_host` = `<router-pod-ip>:8095`.

## Why `createBackendTLSPolicy: false` is not enough

The `ssp-envoy-ssp-router` **Service** uses `appProtocol: HTTPS` and targets **8095**, where the Broadcom **ssp-router** process serves **TLS only**.

With **no** `BackendTLSPolicy`, Envoy Gateway typically opens a **cleartext HTTP** connection to the upstream. The router’s TLS handler sees invalid bytes and **closes** the connection → the error above.

So **`createBackendTLSPolicy: false`** matches **GKE Gateway** behavior but **does not** reproduce the same upstream protocol behavior on Envoy Gateway for this chart.

## What must be configured

1. **Trust** the router’s server cert using the ISK CA the chart creates: Secret **`ssp-envoy-ssp-keys-isk-ca`** (key **`ca.crt`**).
2. **Backend TLS validation** must accept the router cert’s SANs. The router cert commonly has **critical** SAN **`DNS:*.ssp-envoy.svc`** (and CN like `ssp-envoy-ssp-envoy-ssp`). The usual verification hostname/SNI for the Service is:
   - **`ssp-envoy-ssp-router.ssp-envoy.svc`**  
   (not `*.svc.cluster.local` for name checks against that wildcard SAN).

Envoy’s own doc example uses **`validation.hostname`** equal to a name that appears on the **backend certificate** (e.g. `www.example.com`), not necessarily the public browser hostname.

## GitOps-friendly CA bundle

Gateway API **core** support for CA PEMs points at a **ConfigMap** with key **`ca.crt`**. If you reference a **Secret** for CA and behavior is unclear, mirror the CA into a ConfigMap:

```bash
kubectl get secret ssp-envoy-ssp-keys-isk-ca -n ssp-envoy -o jsonpath='{.data.ca\.crt}' \
  | base64 -d > /tmp/isk-ca.crt
kubectl -n ssp-envoy create configmap ssp-envoy-ssp-router-tls-ca \
  --from-file=ca.crt=/tmp/isk-ca.crt --dry-run=client -o yaml | kubectl apply -f -
```

Example **`BackendTLSPolicy`** (adjust namespace/name if needed) is in:

`envs/idsp-envoy/manifests/backendtlspolicy-ssp-router.yaml`

## If it still fails after policy + CM

We have seen clusters where **direct** `curl` to the router Service (or pod `:8095`) with the same CA returns **200**, but traffic **through** Envoy still returns **503** / `connection_termination`. That points to an **Envoy Gateway ↔ ssp-router** interaction (translation, HTTP version, or TLS verify edge cases with **critical** SANs).

Practical next steps:

1. **Broadcom** support: SSP router + **Envoy Gateway** (version in use) for Gateway API ingress.
2. **Envoy Gateway** release notes / issues for `BackendTLSPolicy` and Java/Netty backends.
3. **Dev-only workaround:** enable the **Backend** API on Envoy Gateway and use `tls.insecureSkipVerify: true` on a **Backend** resource (see [Backend TLS: Skip TLS Verification](https://gateway.envoyproxy.io/latest/tasks/security/backend-skip-tls-verification/)) — requires changing the **HTTPRoute** `backendRefs` to point at that **Backend** (Helm chart change or overlay), **not** for production.
4. **Known-good path:** **GKE Gateway** (`createBackendTLSPolicy: false` in your `ssp-gw` values) until Envoy path is certified.

## Related values

- `envs/idsp-envoy/values/ssp-envoy-values.yaml` — `ssp.ingress.gatewayApi.createBackendTLSPolicy`
- `envs/idsp-gw/values/ssp-gw-values.yaml` — GKE Gateway uses `createBackendTLSPolicy: false`
