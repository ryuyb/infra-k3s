# Runbook: Add Node

## Prerequisites

- [ ] VPS provisioned with SSH access
- [ ] Public IP address known
- [ ] Tailscale auth key available
- [ ] Ansible inventory updated

## Steps

### 1. Update Inventory

Add node to `ansible/inventory/hosts.yml`:

```yaml
k3s_workers:
  hosts:
    new-worker:
      ansible_host: "{{ vault_ansible_hosts['new-worker'] }}"
      ansible_user: "{{ vault_ansible_users['new-worker'] }}"
```

Update `ansible/inventory/group_vars/all/vault.yml` with the node's connection
details (public IP during bootstrap; switch to the Tailscale IP after the node
joins the mesh if desired).

### 2. Bootstrap Node

```bash
# Run bootstrap playbook
ansible-playbook ansible/playbooks/bootstrap.yml -l new-worker
```

This installs:
- Base packages
- Firewall rules
- Tailscale (node joins mesh)

### 3. Join K3s Cluster

```bash
# Install K3s agent
ansible-playbook ansible/playbooks/k3s-worker.yml -l new-worker
```

### 4. Verify

```bash
# Check node joined
kubectl get nodes

# Verify Tailscale connectivity
tailscale status

# Check node is Ready
kubectl describe node new-worker
```

## Rollback

If node fails to join:

```bash
# Remove from cluster
kubectl delete node new-worker

# Uninstall K3s on node
ansible-playbook ansible/playbooks/k3s-uninstall.yml -l new-worker

# Re-run from step 3
```

## Post-Add Tasks

- [ ] Verify pods can schedule on new node
- [ ] Check node labels applied correctly
- [ ] Monitor node metrics in Prometheus
