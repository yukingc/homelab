Use the **Tailscale Kubernetes Operator**. It runs inside minikube, makes outbound connections to your tailnet, and gives each Ingress its own tailnet node with HTTPS. You don't need `minikube tunnel` or port-forwarding, and it's the closest k8s equivalent to TSDProxy.

## 1. Tailnet setup (one time)
- In your ACL policy, add `tagOwners` for `tag:k8s-operator` and `tag:k8s` (owned by `autogroup:admin`, and `tag:k8s` also owned by `tag:k8s-operator`).
- In Admin Console → Settings → OAuth clients, create a client with the **Devices Core** and **Auth Keys** write scopes, tagged `tag:k8s-operator`.
- Make sure MagicDNS and HTTPS certificates are enabled.

## 2. Install the operator
```bash
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  -n tailscale --create-namespace \
  --set-string oauth.clientId=<ID> \
  --set-string oauth.clientSecret=<SECRET> --wait
```
(Helm is only for the operator. Your app manifests stay plain `kubectl apply`.)

## 3. Stirling-PDF manifest (`stirling-pdf.yaml`)

(See the file.)

## To deploy

```bash
kubectl apply -f stirling-pdf.yaml
kubectl -n stirling-pdf get ingress   # shows the tailnet address once ready
```
It'll be reachable at `https://stirling-pdf-k8s.<tailnet>.ts.net`.

## Gotchas
- I used the hostname `stirling-pdf-k8s` so it doesn't collide with the one TSDProxy already registered. Once you're happy, stop the compose version and rename if you like.
- The first image pull is large, so give the pod a couple of minutes. Check with `kubectl -n stirling-pdf get pods`.
- If the proxy node doesn't appear, check `kubectl -n tailscale logs deploy/operator`. It's usually an ACL tag or OAuth scope issue.
- Minikube's default storage class is fine for this, but data lives inside the minikube VM/container, so `minikube delete` wipes it.

A simpler alternative is a `Service` with `type: LoadBalancer` and `loadBalancerClass: tailscale`. That skips the Ingress but gives you plain HTTP over the tailnet, with no HTTPS cert.

I can also convert this into a Kustomize layout for your `homelab/k8s` dir when you get to that step.