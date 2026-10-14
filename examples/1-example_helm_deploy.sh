# 1. Validate the chart syntax
helm lint ./helm-demo-app

# 2. Render manifests locally to standard output (dry run)
helm template my-release ./helm-demo-app

# 3. Deploy the chart to your Kubernetes cluster
helm install my-release ./helm-demo-appp --namespace container-demo --create-namespace

# 4. Override values on the fly without changing files
helm upgrade my-release ./helm-demo-app --namespace container-demo --set replicaCount=4

# 5. Check release history and rollback if needed
helm history my-release -n container-demo
helm rollback my-release 1 -n container-demo