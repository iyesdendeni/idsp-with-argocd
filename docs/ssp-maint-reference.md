# SSP “maint patch” chart & image reference

Broadcom SSP **maint** stream used by this repo for **idsp-gw** (`ssp-gw` Argo CD application).

| Item | Value |
|------|--------|
| **Helm repo (alias)** | `ssp-helm-charts-maint` |
| **Helm repo URL** | `https://ssp-helm-charts-staging.storage.googleapis.com/ssp-maint-patch/` |
| **Chart name** | `ssp` |
| **Image registry base** | `us.gcr.io/saasdev-sed-ssp-hp/maint/` |

Example image (router): `us.gcr.io/saasdev-sed-ssp-hp/maint/ssprouter:<tag>`

## In this Git repo

- **Argo CD Application:** `envs/idsp-gw/apps/ssp-gw.yaml`  
  - `repoURL`: `https://ssp-helm-charts-staging.storage.googleapis.com/ssp-maint-patch` (no trailing slash required by Argo CD)  
  - `chart`: `ssp`  
  - `targetRevision`: set to the Broadcom-released version for your environment (e.g. `4.0.2-1031.stage`).

- **Values:** `envs/idsp-gw/values/ssp-gw-values.yaml`  
  - Pull secret: `ssp-staging-registrypullsecret` (must authenticate to **`us.gcr.io`** for project **`saasdev-sed-ssp-hp`**).

## Registering the repo in Argo CD (optional)

If you add the Helm repo in the Argo CD UI/CLI:

```text
Name:    ssp-helm-charts-maint
URL:     https://ssp-helm-charts-staging.storage.googleapis.com/ssp-maint-patch
Type:    Helm
```

## Related docs

- Image pull / 403 issues: [gcr-ssprouter-image-pull.md](./gcr-ssprouter-image-pull.md)
