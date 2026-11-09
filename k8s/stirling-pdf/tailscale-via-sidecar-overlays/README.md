## Prerequisite

Save the auth key into a Kubernetes Secret.

```bash
kubectl create secret generic tailscale-auth --from-literal=TS_AUTHKEY=tskey-auth-xxxxxx
```

## How to Deploy

- To deploy WITHOUT the Tailscale sidecar (Vanilla Stirling-PDF):

```bash
kubectl apply -k stirling-pdf/base/
```

- To deploy WITH the Tailscale sidecar:

```bash
kubectl apply -k stirling-pdf/overlays/with-tailscale/
```