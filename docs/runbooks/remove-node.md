# Runbook: Remove Node

## Prerequisites

- [ ] Node is accessible (if graceful removal)
- [ ] Workloads can be rescheduled to other nodes
- [ ] Backup completed if node has local PVCs

## Steps

### 1. Drain Node

```bash
# Evict all pods gracefully
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### 2. Verify Pods Rescheduled

```bash
# Check no pods remain (except DaemonSets)
kubectl get pods -A -o wide | grep <node-name>

# Verify services still healthy
kubectl get pods -A
```

### 3. Remove from Cluster

```bash
# Delete node object
kubectl delete node <node-name>
```

### 4. Uninstall K3s (if node accessible)

```bash
ansible-playbook ansible/playbooks/k3s-uninstall.yml -l <node-name>
```

Or manually on the node:
```bash
/usr/local/bin/k3s-agent-uninstall.sh  # For workers
/usr/local/bin/k3s-uninstall.sh        # For masters
```

### 5. Remove from Tailscale

```bash
# On the node
tailscale logout

# Or from Tailscale admin console
# https://login.tailscale.com/admin/machines
```

### 6. Update Inventory

Remove node from `ansible/inventory/hosts.yml`.

## Verification

```bash
# Node no longer in cluster
kubectl get nodes

# Tailscale mesh updated
tailscale status

# All services healthy
kubectl get pods -A
```

## Rollback

If removal was accidental:

1. Re-add node following [add-node.md](add-node.md)
2. Restore any PVC data from backup if needed

## Notes

- For master nodes, ensure another master exists before removal
- Single-master clusters cannot have master removed
