## Port forward service stirling-pdf

```bash
kubectl port-forward svc/stirling-pdf 3000:80
```

To enable all interfaces in order to access from another machine:

```bash
kubectl port-forward svc/stirling-pdf 3000:80 --address 0.0.0.0
```

## Port forward k8s dashboard

```bash
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8081:80 --address 0.0.0.0
```

