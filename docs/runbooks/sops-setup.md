# SOPS + age setup (ArgoCD)

This repo uses SOPS with age for Kubernetes Secrets in `k8s/secrets`.

## 1) Create age key locally

```bash
age-keygen -o key.txt
chmod 600 key.txt
```

Get the public key from `key.txt` (line starting with `# public key:`) and update `.sops.yaml`.

```bash
cp .sops.yaml.example .sops.yaml
# edit .sops.yaml and replace the age public key
```

## 2) Install the key into ArgoCD

The `deploy-argocd` playbook will install the key into ArgoCD automatically
from `key.txt` in the repo root.

If you need to do it manually:

```bash
kubectl -n argocd create secret generic argocd-sops-age --from-file=key.txt
```

## 3) Create encrypted secrets

```bash
sops k8s/secrets/grafana-admin.sops.yaml
sops k8s/secrets/authentik-secret.sops.yaml
sops k8s/secrets/cloudflare-api-token.sops.yaml
sops k8s/secrets/namespaces.sops.yaml
sops k8s/secrets/tailscale-operator-oauth.sops.yaml
sops k8s/secrets/pgadmin4.sops.yaml

cp k8s/secrets/velero-r2-credentials.sops.yaml.example k8s/secrets/velero-r2-credentials.sops.yaml
sops -e -i k8s/secrets/velero-r2-credentials.sops.yaml

cp k8s/secrets/tailscale-operator-oauth.sops.yaml.example k8s/secrets/tailscale-operator-oauth.sops.yaml
sops -e -i k8s/secrets/tailscale-operator-oauth.sops.yaml

cp k8s/secrets/pgadmin4.sops.yaml.example k8s/secrets/pgadmin4.sops.yaml
sops -e -i k8s/secrets/pgadmin4.sops.yaml
```

Make sure `k8s/secrets/namespaces.sops.yaml` includes the `velero`,
`tailscale`, and `database` namespaces.

Commit only the encrypted `*.sops.yaml` files.
