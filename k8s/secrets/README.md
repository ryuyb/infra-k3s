# SOPS-managed secrets

Create encrypted secrets in this directory using SOPS + age.

Edit existing encrypted secrets:

```bash
sops k8s/secrets/grafana-admin.sops.yaml
sops k8s/secrets/authentik-secret.sops.yaml
sops k8s/secrets/cloudflare-api-token.sops.yaml
sops k8s/secrets/namespaces.sops.yaml
sops k8s/secrets/tailscale-operator-oauth.sops.yaml
sops k8s/secrets/pgadmin4.sops.yaml
```

Decrypt secrets (to stdout):

```bash
sops -d k8s/secrets/grafana-admin.sops.yaml
sops -d k8s/secrets/authentik-secret.sops.yaml
sops -d k8s/secrets/cloudflare-api-token.sops.yaml
sops -d k8s/secrets/namespaces.sops.yaml
sops -d k8s/secrets/pgadmin4.sops.yaml
```

If your key is not in the default location:

```bash
SOPS_AGE_KEY_FILE=./key.txt sops -d k8s/secrets/grafana-admin.sops.yaml
```

Add Velero R2 credentials:

```bash
cp velero-r2-credentials.sops.yaml.example velero-r2-credentials.sops.yaml
sops -e -i velero-r2-credentials.sops.yaml
```

Add Tailscale Operator OAuth secret:

```bash
cp tailscale-operator-oauth.sops.yaml.example tailscale-operator-oauth.sops.yaml
sops -e -i tailscale-operator-oauth.sops.yaml
```

Add pgAdmin password secret:

```bash
cp pgadmin4.sops.yaml.example pgadmin4.sops.yaml
sops -e -i pgadmin4.sops.yaml
```

Ensure `k8s/secrets/namespaces.sops.yaml` includes the `velero`, `tailscale`,
and `database` namespaces so secrets can be created before applications sync.
