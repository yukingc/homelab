NAMESPACE = monitoring

.PHONY: up down restart status minikube-check

minikube-check:
	@minikube status | grep -q "Running" || (echo "❌ minikube is not running. Run: minikube start" && exit 1)

up: minikube-check
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f .

down: minikube-check
	kubectl delete -f .

restart: minikube-check
	kubectl rollout restart deployment/grafana -n $(NAMESPACE)

status: minikube-check
	kubectl get all -n $(NAMESPACE)

# ClusterIP port-forward (default, works with any service type)
open: minikube-check
	@echo "🚀 Port-forwarding Grafana → http://localhost:3000 (Ctrl+C to stop)"
	kubectl port-forward svc/grafana 3000:3000 -n $(NAMESPACE)

# minikube service tunnel (requires NodePort service type)
open-nodeport: minikube-check
	@echo "🚀 Opening Grafana via minikube service tunnel..."
	minikube service grafana -n $(NAMESPACE)
