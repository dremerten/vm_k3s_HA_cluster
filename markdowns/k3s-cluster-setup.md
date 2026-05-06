# K3s HA Cluster Setup Guide

## Prerequisites
- 3 Ubuntu VMs: k3s-cluster1, k3s-cluster2, k3s-cluster3
- Docker installed on host for Nginx load balancer
- Network connectivity between all nodes

## Step 1: Configure Each VM

Run on each VM after first boot to ensure unique identity:

```bash
# Set hostname (run on each VM with appropriate name)
# On k3s-cluster1:
sudo hostnamectl set-hostname k3s-cluster1

# On k3s-cluster2:
sudo hostnamectl set-hostname k3s-cluster2

# On k3s-cluster3:
sudo hostnamectl set-hostname k3s-cluster3

# Regenerate machine-id (run on ALL VMs)
sudo rm /etc/machine-id
sudo systemd-machine-id-setup
sudo reboot
```

## Step 2: Docker Nginx Load Balancer Configuration

Run these commands on your HOST machine (not inside the VMs):

### Create nginx configuration:

```bash
# Create nginx config directory
mkdir -p ~/k3s-lb

# Create nginx.conf
cat > ~/k3s-lb/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

stream {
    upstream k3s_servers {
        server k3s-cluster1:6443 max_fails=3 fail_timeout=5s;
        server k3s-cluster2:6443 max_fails=3 fail_timeout=5s;
        server k3s-cluster3:6443 max_fails=3 fail_timeout=5s;
    }

    server {
        listen 6443;
        proxy_pass k3s_servers;
        proxy_timeout 10s;
        proxy_connect_timeout 5s;
    }
}

http {
    upstream k3s_http {
        server k3s-cluster1:80;
        server k3s-cluster2:80;
        server k3s-cluster3:80;
    }

    upstream k3s_https {
        server k3s-cluster1:443;
        server k3s-cluster2:443;
        server k3s-cluster3:443;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://k3s_http;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    server {
        listen 443;
        location / {
            proxy_pass https://k3s_https;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
```

### Run the Nginx load balancer:

Replace `<K3S_CLUSTER*_IP>` with actual IP addresses of your VMs:

```bash
docker run -d \
  --name k3s-lb \
  --restart unless-stopped \
  -v ~/k3s-lb/nginx.conf:/etc/nginx/nginx.conf:ro \
  -p 6443:6443 \
  -p 80:80 \
  -p 443:443 \
  --add-host k3s-cluster1:<K3S_CLUSTER1_IP> \
  --add-host k3s-cluster2:<K3S_CLUSTER2_IP> \
  --add-host k3s-cluster3:<K3S_CLUSTER3_IP> \
  nginx:alpine
```

Verify load balancer is running:

```bash
# Run on HOST machine
docker ps | grep k3s-lb
docker logs k3s-lb
```

## Step 3: Install k3s on First Server Node (k3s-cluster1)

**Run on k3s-cluster1:**

Replace `<LOAD_BALANCER_IP>` with your actual load balancer IP from Step 2:

```bash
export INSTALL_K3S_VERSION="v1.35.3+k3s1"
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --tls-san k3s-cluster1 \
  --tls-san <LOAD_BALANCER_IP> \
  --write-kubeconfig-mode 644
```

Get the node token for other servers:

```bash
# Run on k3s-cluster1
sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this token, you'll need it for cluster2 and cluster3.

Verify installation:

```bash
# Run on k3s-cluster1
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

## Step 4: Install k3s on Second Server Node (k3s-cluster2)

**Run on k3s-cluster2:**

Replace `<TOKEN_FROM_CLUSTER1>` with the token from Step 3:
Replace `<LOAD_BALANCER_IP>` with your actual load balancer IP:

```bash
export INSTALL_K3S_VERSION="v1.35.3+k3s1"
export K3S_TOKEN="<TOKEN_FROM_CLUSTER1>"
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://k3s-cluster1:6443 \
  --disable traefik \
  --disable servicelb \
  --tls-san k3s-cluster2 \
  --tls-san <LOAD_BALANCER_IP> \
  --write-kubeconfig-mode 644
```

Verify:

```bash
# Run on k3s-cluster2
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

## Step 5: Install k3s on Third Server Node (k3s-cluster3)

**Run on k3s-cluster3:**

Replace `<TOKEN_FROM_CLUSTER1>` with the token from Step 3:
Replace `<LOAD_BALANCER_IP>` with your actual load balancer IP:

```bash
export INSTALL_K3S_VERSION="v1.35.3+k3s1"
export K3S_TOKEN="<TOKEN_FROM_CLUSTER1>"
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://k3s-cluster1:6443 \
  --disable traefik \
  --disable servicelb \
  --tls-san k3s-cluster3 \
  --tls-san <LOAD_BALANCER_IP> \
  --write-kubeconfig-mode 644
```

Verify:

```bash
# Run on k3s-cluster3
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

## Step 6: Install Nginx Gateway API

Run on any control plane node (e.g., k3s-cluster1):

### Install Gateway API CRDs:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

### Install NGINX Gateway Fabric:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
```

### Verify installation:

```bash
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

### Create a Gateway resource:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: nginx-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: gateway-tls
EOF
```

## Step 7: Verify Complete Cluster Setup

**Run on any control plane node (e.g., k3s-cluster1):**

### Check all nodes are ready:

```bash
# Run on k3s-cluster1 (or any control plane node)
kubectl get nodes -o wide
```

You should see all 3 nodes in Ready state.

### Check etcd members:

```bash
# Run on k3s-cluster1 (or any control plane node)
# Find etcd pod name
kubectl get pods -n kube-system | grep etcd

# Check etcd cluster health (adjust pod name as needed)
kubectl exec -n kube-system -it etcd-k3s-cluster1-* -- etcdctl \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  endpoint health --cluster
```

### Verify Gateway API:

```bash
# Run on k3s-cluster1 (or any control plane node)
kubectl get gateway -A
kubectl get httproute -A
```

## Step 8: Label Nodes for Jenkins Workload Separation (Optional)

**Run on k3s-cluster1 (or any control plane node):**

If you plan to deploy Jenkins with the controller on k3s-cluster1 and agents on k3s-cluster2/k3s-cluster3, label the nodes:

```bash
# Label k3s-cluster1 for Jenkins controller
kubectl label nodes k3s-cluster1 jenkins-role=controller

# Label k3s-cluster2 and k3s-cluster3 for Jenkins agents
kubectl label nodes k3s-cluster2 jenkins-role=agent
kubectl label nodes k3s-cluster3 jenkins-role=agent

# Verify labels
kubectl get nodes --show-labels | grep jenkins-role
```

Expected output:
```
k3s-cluster1   Ready    control-plane,master   ...   jenkins-role=controller
k3s-cluster2   Ready    control-plane,master   ...   jenkins-role=agent
k3s-cluster3   Ready    control-plane,master   ...   jenkins-role=agent
```

These labels will be used by Jenkins pod templates to ensure:
- Jenkins controller runs only on k3s-cluster1
- Jenkins agent pods spawn only on k3s-cluster2 and k3s-cluster3

For Jenkins installation instructions, see `jenkins-setup.md`.

## Step 9: Access Cluster from External Machine

Copy kubeconfig from any server node:

```bash
# Run on k3s-cluster1 (or any server node)
sudo cat /etc/rancher/k3s/k3s.yaml
```

On your local/external machine:

```bash
# Run on your LOCAL machine (not on any VM)
# Create/edit ~/.kube/config
# Replace 127.0.0.1 with your LOAD_BALANCER_IP in the server field

# Test access
kubectl get nodes
```

## Troubleshooting

### Check k3s service status:

```bash
# Run on any k3s node (k3s-cluster1, k3s-cluster2, or k3s-cluster3)
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

### Check logs:

```bash
# Run on any k3s node (k3s-cluster1, k3s-cluster2, or k3s-cluster3)
sudo k3s kubectl logs -n kube-system -l app=etcd
```

### Restart k3s if needed:

```bash
# Run on the specific k3s node having issues
sudo systemctl restart k3s
```

### Test load balancer connectivity:

```bash
# Run from HOST machine or any external machine with network access
curl -k https://<LOAD_BALANCER_IP>:6443
```

## Summary

Your HA k3s cluster setup includes:

- 3 k3s server nodes with embedded etcd (high availability control plane)
- Traefik disabled (as requested)
- ServiceLB disabled (as requested)
- Docker Nginx load balancer fronting the cluster on ports 6443, 80, and 443
- Nginx Gateway API for modern ingress/gateway resources
- Version: v1.35.3+k3s1
- Node labels configured for Jenkins workload separation (optional)

All traffic goes through the Nginx load balancer, which distributes requests across all 3 nodes.

## Next Steps

For Jenkins POC setup with dynamic Kubernetes agents:
- See `AGENTS.md` for architecture overview
- See `jenkins-setup.md` for installation instructions
