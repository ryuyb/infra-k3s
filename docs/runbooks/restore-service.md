# Runbook: Restore Service

## Prerequisites

- [ ] Velero installed and configured
- [ ] Backup exists for the service
- [ ] Target namespace exists (or will be created)

## Steps

### 1. List Available Backups

```bash
./scripts/backup/list-backups.sh

# Or with velero directly
velero backup get
```

### 2. Inspect Backup Contents

```bash
velero backup describe <backup-name> --details
```

### 3. Restore Service

#### Option A: Restore to Same Namespace

```bash
./scripts/dr/restore-workload.sh --app <app-name> --backup <backup-name>
```

#### Option B: Restore to Different Namespace

```bash
velero restore create --from-backup <backup-name> \
  --include-namespaces <source-ns> \
  --namespace-mappings <source-ns>:<target-ns>
```

#### Option C: Restore Specific Resources

```bash
velero restore create --from-backup <backup-name> \
  --include-resources deployments,services,configmaps \
  --selector app=<app-name>
```

### 4. Monitor Restore Progress

```bash
velero restore describe <restore-name>
velero restore logs <restore-name>
```

### 5. Verify Service

```bash
# Check pods running
kubectl get pods -n <namespace> -l app=<app-name>

# Check service endpoints
kubectl get endpoints -n <namespace>

# Test service connectivity
kubectl run test --rm -it --image=busybox -- wget -qO- http://<service>
```

## Verification

```bash
# Restore completed
velero restore get | grep <restore-name>

# All resources restored
kubectl get all -n <namespace> -l app=<app-name>

# PVC data restored (if applicable)
kubectl exec -n <namespace> <pod> -- ls /data
```

## Rollback

If restore causes issues:

```bash
# Delete restored resources
kubectl delete all -n <namespace> -l app=<app-name>

# Re-restore from different backup
velero restore create --from-backup <older-backup>
```

## Common Issues

### PVC Not Restoring

Ensure node-agent is running:
```bash
kubectl get pods -n velero -l name=node-agent
```

### Restore Stuck

Check Velero logs:
```bash
kubectl logs -n velero -l app.kubernetes.io/name=velero
```

### Partial Restore

Some resources may have dependencies. Restore in order:
1. Secrets/ConfigMaps
2. PVCs
3. Deployments/StatefulSets
4. Services/HTTPRoutes
