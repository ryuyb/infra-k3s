# Stateful Services and Node Scheduling

This document tracks stateful services and their node scheduling configurations due to local storage constraints.

## Overview

Since the cluster uses local-path storage (no distributed storage like Longhorn or Ceph), stateful services with persistent volumes must be pinned to specific nodes to ensure data persistence across pod restarts.

## Node Scheduling Methods

### 1. NodeSelector (Simple, Hostname-based)

Pin to a specific node by hostname:

```yaml
nodeSelector:
  kubernetes.io/hostname: master
```

**Use case**: When you need to pin to a specific node.

### 2. NodeSelector (Label-based)

Pin to nodes with specific labels:

```yaml
nodeSelector:
  node-role.kubernetes.io/storage: "true"
  disk-type: ssd
```

**Use case**: When you want to pin to any node with certain characteristics (e.g., all nodes with SSD storage).

**Label nodes**:
```bash
kubectl label nodes worker1 disk-type=ssd
kubectl label nodes worker1 node-role.kubernetes.io/storage=true
```

### 3. Node Affinity (Advanced)

More flexible scheduling with required or preferred rules:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - master
          - worker1
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: disk-type
          operator: In
          values:
          - ssd
```

**Use case**: When you need complex scheduling logic (e.g., prefer certain nodes but allow others as fallback).

## Pinned Services

### Master Node (`kubernetes.io/hostname: master`)

| Service | Namespace | Type | Storage | Size | Reason |
|---------|-----------|------|---------|------|--------|
| Prometheus | monitoring | StatefulSet | PVC (local-path) | 10Gi | Time-series metrics database |
| Grafana | monitoring | Deployment | PVC (local-path) | 5Gi | Dashboard configurations and data |

### Worker1 Node (`kubernetes.io/hostname: worker1`)

| Service | Namespace | Type | Storage | Size | Reason |
|---------|-----------|------|---------|------|--------|
| PostgreSQL | database | StatefulSet | PVC (local-path) | 20Gi | Relational database with persistent data |
| pgAdmin4 | database | Deployment | PVC (local-path) | 5Gi | Database management UI, connection configs |

## Configuration Details

### Prometheus
- **File**: `helm/infrastructure/templates/prometheus.yaml`
- **Configuration**:
  ```yaml
  prometheus:
    prometheusSpec:
      nodeSelector:
        kubernetes.io/hostname: master
      storageSpec:
        volumeClaimTemplate:
          spec:
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 10Gi
  ```

### Grafana
- **File**: `helm/infrastructure/templates/grafana.yaml`
- **Configuration**:
  ```yaml
  persistence:
    enabled: true
    type: pvc
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    size: 5Gi

  nodeSelector:
    kubernetes.io/hostname: master
  ```

### PostgreSQL
- **File**: `helm/apps/templates/postgresql.yaml`
- **Configuration**:
  ```yaml
  primary:
    nodeSelector:
      kubernetes.io/hostname: worker1

    persistence:
      enabled: true
      storageClass: local-path
      size: 20Gi
      accessModes:
        - ReadWriteOnce
  ```
- **Access**:
  - Internal: `postgresql.database.svc.cluster.local:5432`
  - External: pgAdmin4 at `https://pgadmin.{{ .Values.domain }}`
- **Credentials**: Stored in Kubernetes Secret `postgresql` in `database` namespace

### pgAdmin4
- **File**: `helm/apps/templates/pgadmin4.yaml`
- **Configuration**:
  ```yaml
  persistentVolume:
    enabled: true
    storageClass: local-path
    size: 5Gi
    accessModes:
      - ReadWriteOnce

  nodeSelector:
    kubernetes.io/hostname: worker1
  ```
- **Access**: `https://pgadmin.{{ .Values.domain }}`
- **Default credentials**: `admin@example.com` / `changeme` (请修改)

## Verification

Check that services are running on the correct nodes:

```bash
# Check Prometheus pod placement
kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o wide

# Check Grafana pod placement
kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o wide

# Check PostgreSQL pod placement
kubectl get pod -n database -l app.kubernetes.io/name=postgresql -o wide

# Check pgAdmin4 pod placement
kubectl get pod -n database -l app.kubernetes.io/name=pgadmin4 -o wide

# Verify PVCs are bound
kubectl get pvc -n monitoring
kubectl get pvc -n database
```

## Important Notes

1. **Data Loss Risk**: If a pinned node fails, the service cannot be rescheduled to another node without manual intervention and potential data loss.

2. **Migration Process**: To move a service to a different node:
   - Scale down the service
   - Copy PV data to the new node
   - Update nodeSelector to the new node
   - Scale up the service

3. **Backup Strategy**: Ensure Velero backups are configured for these services to enable disaster recovery.

4. **Future Improvements**: Consider implementing distributed storage (Longhorn, Rook-Ceph) to eliminate node affinity requirements.

## Last Updated

2026-01-17
