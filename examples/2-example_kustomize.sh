# Render and inspect the Dev environment
kubectl kustomize overlays/dev

# Render and inspect the Prod environment (notice the generated ConfigMap hash)
kubectl kustomize overlays/prod

# Apply development overlay directly
kubectl apply -k overlays/dev

# Apply production overlay directly
kubectl apply -k overlays/prod


# To remove deployed resources
kubectl delete -k overlays/dev
kubectl delete -k overlays/prod