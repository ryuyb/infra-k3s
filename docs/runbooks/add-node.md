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
      public_ip: 1.2.3.4
      ansible_user: root
```

### 2. Bootstrap Node

```bash
# Run bootstrap playbook (uses public IP)
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
