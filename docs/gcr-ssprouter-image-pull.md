# Fixing `ssp-router` image pull: `us.gcr.io/saasdev-sed-ssp-hp/maint/ssprouter`

## How the SSP chart wires pull secrets (4.0.2.x)

The **router** Deployment uses **`ssp.global.ssp.registry.existingSecrets`** only (`ssprouter-deployment.yaml`). It does **not** read Kubernetes-style `global.imagePullSecrets` at the pod spec for `ssp-router`.

Your values must include:

```yaml
ssp:
  global:
    ssp:
      registry:
        existingSecrets:
          - name: ssp-staging-registrypullsecret   # or your secret name
```

**Verify the rendered pod spec** (after `helm template` or from a live pod):

```bash
kubectl get pod -n ssp-gw -l app.kubernetes.io/name=ssp-router -o jsonpath='{.items[0].spec.imagePullSecrets}' ; echo
kubectl get pod -n ssp-gw -l app.kubernetes.io/name=ssp-router -o jsonpath='{.items[0].spec.containers[0].image}' ; echo
```

If `imagePullSecrets` is populated but pulls still fail, the problem is the **secret’s credentials** (or the image/tag), not Argo CD or missing Helm keys.

---

## What the error means

You may see both:

1. **`not found`** – The tag `4.1.0.1283` does not exist in that repo, **or** you have no permission to read it (some registries return “not found” instead of 403).
2. **`403 Forbidden`** on `https://us.gcr.io/v2/token` – The credentials in **`ssp-staging-registrypullsecret`** are not allowed to pull from project **`saasdev-sed-ssp-hp`** (or the token is wrong/expired).

So this is primarily a **Google Artifact Registry / GCR access** issue for Broadcom’s hosting project, not an Argo CD bug.

---

## Fix 1: Registry credentials (403)

1. **Confirm the secret exists** in `ssp-gw` and is a docker config:

   ```bash
   kubectl get secret ssp-staging-registrypullsecret -n ssp-gw -o yaml
   ```

   Type should be `kubernetes.io/dockerconfigjson`.

2. **Use credentials Broadcom gave you** for **`us.gcr.io`** and project **`saasdev-sed-ssp-hp`**.  
   Typical approaches:
   - **JSON key** for a GCP service account that has **`Artifact Registry Reader`** (or legacy GCR: **`Storage Object Viewer`** on the bucket backing `us.gcr.io` for that project).
   - Recreate the secret, e.g.:

     ```bash
     kubectl create secret docker-registry ssp-staging-registrypullsecret \
       --docker-server=us.gcr.io \
       --docker-username=_json_key \
       --docker-password="$(cat /path/to/service-account.json)" \
       --namespace=ssp-gw \
       --dry-run=client -o yaml | kubectl apply -f -
     ```

3. **If you use Workload Identity** on GKE, ensure the node SA or dedicated WI SA has permission to pull from **`saasdev-sed-ssp-hp`** (Broadcom often documents the exact binding).

4. **Ask Broadcom** if your subscription includes pull access to **`saasdev-sed-ssp-hp/maint/ssprouter`** and which service account or key to use.

---

## Fix 2: Chart version vs image tag (NotFound / wrong tag)

Your Argo app may use chart **`4.0.2-1031.stage`** while the failing image is **`4.1.0.1283`**. That can happen if:

- The chart revision in the cluster differs from what you expect, or  
- A values file / override points the router to a newer image than you are entitled to pull.

**Actions:**

1. See what the chart actually renders:

   ```bash
   helm show values ssp --repo https://ssp-helm-charts-staging.storage.googleapis.com/ssp-maint-patch --version 4.0.2-1031.stage | less
   ```

2. Align **`targetRevision`** in `envs/idsp-gw/apps/ssp-gw.yaml` with the **SSP release Broadcom told you to use** (so default images match your entitlement).

3. If Broadcom documents an **image override** for `ssprouter`, set it under **`envs/idsp-gw/values/ssp-gw-values.yaml`** (exact keys depend on the chart – use `helm show values` / Broadcom docs). Example **shape** only (names may differ):

   ```yaml
   ssp:
     ssprouter:
       image:
         repository: us.gcr.io/saasdev-sed-ssp-hp/maint/ssprouter
         tag: "<tag-you-are-entitled-to>"
   ```

---

## Quick checklist

| Check | Command / action |
|--------|-------------------|
| Exact image on pod | `kubectl get pod -n ssp-gw -l app.kubernetes.io/name=ssp-router -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'` |
| Pull secret on pod | `kubectl get pod -n ssp-gw -l app.kubernetes.io/name=ssp-router -o jsonpath='{.items[0].spec.imagePullSecrets}'` |
| Event message | `kubectl describe pod -n ssp-gw <ssp-router-pod-name>` |
| Chart defaults | `helm show values` / `helm template` for your `targetRevision` |

---

## Summary

- **403** → Fix **GCP IAM + docker pull secret** (or Workload Identity) for **`us.gcr.io`** and project **`saasdev-sed-ssp-hp`**; confirm with Broadcom.  
- **Not found** → Confirm **tag exists** and you are **licensed** for that build; align **Helm chart version** and any **image overrides** with Broadcom’s install guide.
