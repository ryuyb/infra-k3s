# Repository Guidelines

## Project Structure & Module Organization

- `ansible/` holds playbooks, roles, and inventory for provisioning and K3s lifecycle.
- `helm/` contains charts: `infrastructure/`, `infrastructure-resources/`, and `apps/` for GitOps-managed components.
- `tofu/` contains OpenTofu modules (`modules/`) and environment stacks (`stacks/prod/`).
- `scripts/` provides setup, backup, and disaster-recovery utilities; `docs/` has architecture and runbooks.
- Root config includes `.envrc*` for direnv, `.vault_pass` for Ansible Vault, and `kubeconfig.yaml` for local cluster access.

## Build, Test, and Development Commands

- `ansible-playbook ansible/playbooks/bootstrap.yml` bootstraps new nodes.
- `ansible-playbook ansible/playbooks/k3s-cluster.yml` deploys or updates the K3s cluster (use this for workers too).
- `ansible-playbook ansible/playbooks/deploy-argocd.yml` installs ArgoCD and infrastructure apps (requires R2/Cloudflare env vars).
- `./scripts/setup/init-cluster.sh --with-argocd` runs the full bootstrap + K3s + ArgoCD flow.
- `ansible-vault edit ansible/inventory/group_vars/all/vault.yml` edits encrypted secrets.
- `cd tofu/stacks/prod && tofu init && tofu plan && tofu apply` manages Cloudflare DNS/R2 resources.
- `helm list -A` and `helm upgrade ...` manage Helm releases.
- `ansible 'k3s_masters[0]' -m shell -a "kubectl annotate application apps -n argocd argocd.argoproj.io/refresh=hard --overwrite" -e "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"` triggers an ArgoCD async refresh for the `apps` application via the first master node.
- `./scripts/backup/create-backup.sh` and `./scripts/dr/failover.sh ...` handle backups and DR.

## Coding Style & Naming Conventions

- YAML/Ansible uses 2-space indentation and `.yml` files; roles live in `ansible/roles/<role>/{defaults,tasks,handlers,templates}`.
- Helm charts follow `Chart.yaml`, `values.yaml`, and `templates/*.yaml` layout; keep resource names consistent with chart purpose.
- OpenTofu uses `.tf` files in `tofu/modules/<module>` and `tofu/stacks/<env>`.
- Shell scripts are bash in `scripts/`; keep them executable and include a short usage block when adding new ones.

## Testing Guidelines

- No automated test suite is defined in this repository.
- Validate changes with `tofu plan` before `apply`, run targeted Ansible playbooks in a safe environment (or `--check` when feasible), and verify cluster state with `kubectl`/`helm` after changes.

## Commit & Pull Request Guidelines

- Use Conventional Commits as seen in history: `feat(traefik): ...`, `fix: ...`, `refactor(kubewall): ...`.
- PRs should describe intent, affected areas (`ansible/`, `helm/`, `tofu/`), and the exact validation commands run.

## Security & Configuration Tips

- Keep secrets in `.envrc.local` and `ansible/inventory/group_vars/all/vault.yml`; never commit plaintext credentials.
- Store Kubernetes secrets as Sealed Secrets and commit only the encrypted manifests.
