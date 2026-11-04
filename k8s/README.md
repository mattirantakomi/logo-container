# Kubernetes deployment (k0s + Tailscale)

Manifests to run the LOGO! Soft Comfort container on a Kubernetes cluster and
reach the noVNC browser desktop over Tailscale.

## Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | `logo-soft` namespace |
| `pvc.yaml` | 5Gi PVC for `/home/logo/workspace` (adjust `storageClassName`) |
| `deployment.yaml` | The pod: GHCR image, `SYS_ADMIN`, unconfined seccomp/apparmor, 2Gi `/dev/shm` |
| `service.yaml` | ClusterIP service (noVNC 6080, VNC 5901, xpra 14500) |
| `service-tailscale.yaml` | Exposes noVNC on your tailnet via the Tailscale operator |
| `ghcr-pull-secret.example.yaml` | Reminder for creating the private-registry pull secret |
| `kustomization.yaml` | Applies namespace + pvc + deployment + service together |

## 1. Pull secret for the private GHCR image

The image is private by default, so create a pull secret (do not commit the token):

```bash
kubectl create namespace logo-soft
kubectl create secret docker-registry ghcr-pull \
  --namespace logo-soft \
  --docker-server=ghcr.io \
  --docker-username=mattirantakomi \
  --docker-password='<YOUR_GHCR_PAT_with_read:packages>'
```

Alternatively, make the GHCR package public and delete the `imagePullSecrets`
block from `deployment.yaml`.

## 2. Deploy

```bash
kubectl apply -k k8s/
```

Check it comes up:

```bash
kubectl -n logo-soft get pods -w
kubectl -n logo-soft logs deploy/logo-soft
```

> **Storage:** if the PVC stays `Pending`, your cluster has no default
> StorageClass. List them with `kubectl get storageclass` and set
> `storageClassName` in `pvc.yaml` (k0s often has `openebs-hostpath`).

## 3. Access the desktop

### Option A — Tailscale (recommended, matches your setup)

If the [Tailscale Kubernetes operator](https://tailscale.com/kb/1236/kubernetes-operator)
is installed, enable the tailnet service:

```bash
# uncomment service-tailscale.yaml in kustomization.yaml, then:
kubectl apply -k k8s/
```

Then open the noVNC desktop from any device on your tailnet:

```
http://logo-soft:6080
```

(If your operator exposes via `LoadBalancer`, `kubectl -n logo-soft get svc
logo-soft-ts` shows the assigned tailnet address.)

Running a **subnet router** or **sidecar** instead of the operator? Delete
`service-tailscale.yaml`, keep the ClusterIP `service.yaml`, and reach
`logo-soft.logo-soft.svc.cluster.local:6080` through your existing tailnet
routing.

### Option B — port-forward (quick test, no Tailscale needed)

```bash
kubectl -n logo-soft port-forward svc/logo-soft 6080:6080
# then open http://localhost:6080
```

## Notes

- **Single replica only.** This is a stateful interactive desktop; the RWO PVC
  and `Recreate` strategy enforce one pod.
- **Privileges.** `SYS_ADMIN` + unconfined seccomp/apparmor are required for
  XFCE icon rendering (glycin/bubblewrap), mirroring the docker-compose setup.
  Make sure your cluster's Pod Security Admission allows this (the `logo-soft`
  namespace should be `privileged`, not `restricted`):
  ```bash
  kubectl label namespace logo-soft pod-security.kubernetes.io/enforce=privileged --overwrite
  ```
- **Resources.** Requests 1.5Gi / limits 3Gi RAM. The app idles around ~1.1Gi.
- **No auth.** VNC/noVNC have no password (same as the compose setup), so keep
  access restricted to your tailnet — do not expose 6080 publicly.
