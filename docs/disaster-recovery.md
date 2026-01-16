# Disaster Recovery

## Backup Strategy

### Velero + Kopia

- **Cluster resources**: Velero snapshots all Kubernetes objects
- **Persistent volumes**: Kopia (via node-agent) backs up PVC data
- **Storage**: Cloudflare R2 (S3-compatible, zero egress fees)

### Backup Schedules

| Schedule | Retention | Scope |
|----------|-----------|-------|
| Hourly | 24 hours | Critical apps (label: `backup=critical`) |
| Daily | 30 days | All namespaces |
| Weekly | 90 days | All namespaces |

## Failure Scenarios

### 1. Single Node Failure

**Symptoms**: Node unreachable, pods in `Unknown` state

**Recovery**:
```bash
# Cordon failed node
kubectl cordon <failed-node>

# Delete node from cluster
kubectl delete node <failed-node>

# Pods automatically reschedule to healthy nodes
```

### 2. Application Data Corruption

**Recovery**:
```bash
# List available backups
./scripts/backup/list-backups.sh

# Restore specific app
./scripts/dr/restore-workload.sh --app myapp --backup <backup-name>
```

### 3. Complete Cluster Loss

**Recovery**:
```bash
# 1. Provision new VPS
# 2. Bootstrap with Ansible
ansible-playbook ansible/playbooks/bootstrap.yml -l new-master

# 3. Install K3s
ansible-playbook ansible/playbooks/k3s-master.yml -l new-master

# 4. Install Velero
kubectl apply -k kubernetes/infrastructure/velero/

# 5. Restore from backup
velero restore create --from-backup <latest-backup>
```

### 4. Node Migration (Planned)

**Scenario**: Moving workload from one provider to another

```bash
# Failover script handles:
# - Cordon source node
# - Create backup
# - Restore to target
# - Verify services
./scripts/dr/failover.sh --source-node vps-aws-1 --target-node vps-vultr-1
```

## Recovery Time Objectives

| Scenario | RTO | RPO |
|----------|-----|-----|
| Pod failure | < 1 min | 0 (stateless) |
| Node failure | < 5 min | Hourly backup |
| Cluster rebuild | < 30 min | Daily backup |

## Verification

### Test Backup
```bash
# Create manual backup
./scripts/backup/create-backup.sh --name test-backup

# Verify backup completed
velero backup describe test-backup
```

### Test Restore
```bash
# Restore to different namespace
velero restore create --from-backup test-backup \
  --namespace-mappings default:restore-test
```

## R2 Bucket Access

Backups stored in Cloudflare R2:
- Bucket: `${VELERO_BUCKET}`
- Endpoint: `${R2_ENDPOINT}`
- Credentials: `velero-r2-credentials` secret

Verify connectivity:
```bash
# Using AWS CLI with R2
aws s3 ls s3://${VELERO_BUCKET} --endpoint-url ${R2_ENDPOINT}
```
