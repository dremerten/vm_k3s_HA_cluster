# README-K3S-UPGRADE.md

## K3s Upgrade Guide (v1.35.0 → v1.35.3) with Embedded etcd

This guide provides a safe, production-ready, step-by-step process to upgrade a K3s cluster using embedded etcd, including proper backup, verification, and restore procedures.

---

# OVERVIEW

- From: v1.35.0+k3s1
- To:   v1.36.1+k3s1
- Datastore: embedded etcd
- Upgrade Type: patch upgrade

---

# RULES

- ALWAYS take an etcd snapshot before upgrading
- Config backups alone are NOT sufficient
- Upgrade server nodes first
- Upgrade ONE node at a time
- Ensure node returns to Ready before continuing
- Maintain etcd quorum (do not take down majority)

---

# 1) PREFLIGHT CHECKS

## Verify versions
```
sudo k3s --version
kubectl version --short
kubectl get nodes -o wide
```
## Confirm etcd datastore
```
ls -la /var/lib/rancher/k3s/server/db/etcd
```

## Cluster health
```
kubectl get --raw='/readyz?verbose'
kubectl get nodes
kubectl -n kube-system get pods -o wide
```
## Existing snapshots
```
sudo k3s etcd-snapshot ls

# human readable size
sudo ls -lh /var/lib/rancher/k3s/server/db/snapshots/
```

## Disk space
```
df -h
```
---

# 2) FULL BACKUP (MANDATORY)

## 2.1 Create etcd snapshot (THIS IS YOUR REAL BACKUP)
```
sudo k3s etcd-snapshot save --name pre-upgrade-$(date +%F-%H%M)
```
## 2.2 Verify snapshot exists
```
sudo k3s etcd-snapshot ls
```
## 2.3 Backup config, TLS, and cluster metadata
```
TS="$(date +%F_%H%M%S)"

sudo mkdir -p /root/k3s-backups

sudo tar -czf "/root/k3s-backups/k3s_backup_${TS}.tgz" \
  /etc/rancher/k3s \
  /var/lib/rancher/k3s/server/tls \
  /var/lib/rancher/k3s/server/token \
  /var/lib/rancher/k3s/server/cred \
  /var/lib/rancher/k3s/server/manifests \
  2>/dev/null || true
```
## 2.4 OPTIONAL: Copy backups off-node
```
scp /var/lib/rancher/k3s/server/db/snapshots/* user@backup-host:/backup/k3s/
scp /root/k3s-backups/* user@backup-host:/backup/k3s/
```
---

# 3) VERIFY CONFIG BEFORE UPGRADE

## Confirm config.yaml exists
```
cat /etc/rancher/k3s/config.yaml
```

## Example expected config
```
disable:
  - traefik
  - servicelb
node-name: hostinger1-staging-cluster

etcd-snapshot-schedule-cron: "0 */6 * * *" 
etcd-snapshot-retention: 10 
etcd-snapshot-dir: /var/lib/rancher/k3s/server/db/snapshots
```
### IMPORTANT
- This file is automatically used by K3s on restart
- It persists across upgrades
- It is already included in the backup

---

## 4) UPGRADE SERVER NODES (CONTROL PLANE)

IMPORTANT: Perform on ONE node at a time

### Drain node
```
kubectl drain <SERVER_NODE> --ignore-daemonsets --delete-emptydir-data
```
## Upgrade K3s
```
export INSTALL_K3S_VERSION="v1.36.1+k3s1"
curl -sfL https://get.k3s.io | sudo -E sh -
```
## Restart service
```
sudo systemctl restart k3s
```
## Verify node is Ready and upgraded
```
kubectl get nodes -o wide
```
## Uncordon node
```
kubectl uncordon <SERVER_NODE>
```
## Repeat for each server node

---

# 5) UPGRADE AGENT NODES

## Drain agent
```
kubectl drain <AGENT_NODE> --ignore-daemonsets --delete-emptydir-data
```
## Upgrade
```
export INSTALL_K3S_VERSION="v1.36.1+k3s1"
curl -sfL https://get.k3s.io | sudo -E sh -
```
## Restart agent
```
sudo systemctl restart k3s-agent
```
## Verify
```
kubectl get nodes
```
## Uncordon
```
kubectl uncordon <AGENT_NODE>
```
## Repeat for all agents

---

# 6) POST-UPGRADE VALIDATION

## Verify versions
```
kubectl get nodes -o wide
```
## Check system pods
```
kubectl -n kube-system get pods
```
## Cluster health
```
kubectl get --raw='/readyz?verbose'
```
## Workloads
```
kubectl get pods -A
```
---

# 7) VERIFY CONFIG AFTER UPGRADE

## Ensure config.yaml still applied
```
cat /etc/rancher/k3s/config.yaml
```
## Verify flags are active
```
ps aux | grep k3s | grep disable
```
---

# 8) ROLLBACK (DISASTER RECOVERY)

## Stop K3s
```
sudo systemctl stop k3s
```
## Restore from snapshot
```
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<SNAPSHOT_PATH>
```

Example:
```
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-upgrade-YYYY-MM-DD-HHMM
```
## Start K3s
```
sudo systemctl start k3s
```
## Verify cluster
```
kubectl get nodes
kubectl get pods -A
```
---

# BEST PRACTICES

- etcd snapshot = source of truth
- Keep multiple snapshots
- Store backups off-node
- Never rely on tar backup alone
- Upgrade during low traffic windows
- Monitor logs during upgrade:
```
journalctl -u k3s -f
```
---

# TLDR
```
sudo k3s etcd-snapshot save --name pre-upgrade
export INSTALL_K3S_VERSION="v1.36.1+k3s1"
curl -sfL https://get.k3s.io | sudo -E sh -
kubectl get nodes

