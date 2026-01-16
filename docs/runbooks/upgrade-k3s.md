# Runbook: Upgrade K3s

## Prerequisites

- [ ] Backup completed before upgrade
- [ ] Check K3s release notes for breaking changes
- [ ] Verify target version compatibility

## Steps

### 1. Check Current Version

```bash
kubectl get nodes -o wide
k3s --version
```

### 2. Create Backup

```bash
./scripts/backup/create-backup.sh --name pre-upgrade-$(date +%Y%m%d)
```

### 3. Update Ansible Variables

Edit `ansible/inventory/group_vars/all.yml`:

```yaml
k3s_version: "v1.30.0+k3s1"  # Target version
```

### 4. Upgrade Master First

```bash
ansible-playbook ansible/playbooks/upgrade.yml -l k3s_masters
```

### 5. Verify Master

```bash
# Check master version
kubectl get nodes

# Verify API server healthy
kubectl get --raw /healthz
```

### 6. Upgrade Workers (Rolling)

```bash
# One at a time
ansible-playbook ansible/playbooks/upgrade.yml -l k3s_workers --forks=1
```

### 7. Verify All Nodes

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## Verification

```bash
# All nodes on new version
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'

# All system pods running
kubectl get pods -n kube-system

# Workloads healthy
kubectl get pods -A | grep -v Running
```

## Rollback

If upgrade fails:

### Option 1: Restore from Backup

```bash
# On failed node, uninstall
/usr/local/bin/k3s-uninstall.sh

# Reinstall previous version
ansible-playbook ansible/playbooks/k3s-cluster.yml -l <node>
```

### Option 2: Full Cluster Restore

```bash
# Restore entire cluster from pre-upgrade backup
velero restore create --from-backup pre-upgrade-<date>
```

## Notes

- Always upgrade master before workers
- K3s supports skipping minor versions (1.28 → 1.30)
- Check [K3s releases](https://github.com/k3s-io/k3s/releases) for changelogs
