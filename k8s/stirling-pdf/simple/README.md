## Prep

```bash
kubectl create namespace stirling-pdf
kubectl config set-context --current --namespace=stirling-pdf
```

## Apply and poke it

```bash
kubectl apply -f deployment.yaml -f service.yaml
kubectl get pods -w
kubectl port-forward svc/stirling-pdf 3000:80
```

## Summary of ports
| Component | Port | Description |
| :--- | :--- | :--- |
| **Local Host** | `3000` | The port exposed on your local machine during a port-forward. |
| **Service (`ClusterIP`)** | `80` | The internal cluster port used by other services to contact Stirling-PDF. |
| **Pod Container** | `8080` | The internal port where the Stirling-PDF application actually listens. |
