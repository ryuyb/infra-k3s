# Apps Helm Chart

This directory contains the App of Apps pattern for deploying applications to the K3s cluster.

## Usage

1. Add your application ArgoCD Application manifests to the `templates/` directory
2. Configure application-specific values in `values.yaml`
3. ArgoCD will automatically sync and deploy your applications

## Example

See `templates/example-app.yaml` for a sample application deployment using a Helm chart.

## Adding a New Application

Create a new file in `templates/` with your ArgoCD Application definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: your-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://your-chart-repo
    chart: your-chart
    targetRevision: 1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: your-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
