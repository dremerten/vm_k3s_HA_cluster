# Jenkins Installation Guide for K3s HA Cluster

This guide walks through installing Jenkins on your k3s HA cluster with the controller on k3s-cluster1 and dynamic agents on k3s-cluster2 & k3s-cluster3.

## Prerequisites

- Completed k3s HA cluster setup (all 3 nodes)
- kubectl configured to access the cluster
- Helm 3 installed on your local machine

## Step 1: Label Nodes for Workload Separation

**Run on k3s-cluster1 (or any control plane node):**

```bash
# Label k3s-cluster1 for Jenkins controller
kubectl label nodes k3s-cluster1 jenkins-role=controller

# Label k3s-cluster2 and k3s-cluster3 for Jenkins agents
kubectl label nodes k3s-cluster2 jenkins-role=agent
kubectl label nodes k3s-cluster3 jenkins-role=agent

# Verify labels
kubectl get nodes --show-labels | grep jenkins-role
```

## Step 2: Install cert-manager for TLS Certificates

**Run on k3s-cluster1 (or any control plane node):**

cert-manager will automatically manage Let's Encrypt certificates for Jenkins.

```bash
# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.crds.yaml

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.2

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

Verify cert-manager is running:

```bash
kubectl get pods -n cert-manager
```

## Step 3: Create Let's Encrypt ClusterIssuer

**Run on k3s-cluster1 (or any control plane node):**

Replace `your-email@example.com` with your actual email:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

For testing, you can also create a staging issuer:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## Step 4: Create Jenkins Namespace

**Run on k3s-cluster1 (or any control plane node):**

```bash
kubectl create namespace jenkins
```

## Step 5: Create Jenkins Values File for Helm

Create a custom values file to configure Jenkins with node affinity:

```bash
cat > jenkins-values.yaml <<'EOF'
controller:
  # Jenkins controller configuration
  image: jenkins/jenkins
  tag: "2.479-jdk17"

  # Resource requests and limits
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

  # Node affinity to pin controller to k3s-cluster1
  nodeSelector:
    jenkins-role: controller

  # Service account for Kubernetes plugin
  serviceAccount:
    create: true
    name: jenkins

  # Admin user credentials (change these!)
  adminUser: "admin"
  adminPassword: "admin123"

  # Install required plugins
  installPlugins:
    - kubernetes:4360.v60b_a_4b_44da_dc
    - workflow-aggregator:600.vb_57cdd26fdd7
    - git:5.7.0
    - configuration-as-code:1850.va_a_8c31d3158b_
    - kubernetes-credentials-provider:1.275.v203f7cc30c32

  # JCasC configuration
  JCasC:
    defaultConfig: true
    configScripts:
      welcome-message: |
        jenkins:
          systemMessage: "Jenkins configured with Kubernetes dynamic agents on k3s-cluster2 and k3s-cluster3"

  # Ingress configuration (we'll use Gateway API instead)
  ingress:
    enabled: false

# Persistence for Jenkins home
persistence:
  enabled: true
  storageClass: "local-path"
  size: "20Gi"
  accessMode: ReadWriteOnce

# Disable agent deployment (we'll use dynamic Kubernetes agents)
agent:
  enabled: false

# Service configuration
controller:
  serviceType: ClusterIP
  servicePort: 8080
EOF
```

## Step 6: Install Jenkins with Helm

**Run on k3s-cluster1 (or any control plane node):**

```bash
# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins-values.yaml \
  --wait \
  --timeout 10m

# Wait for Jenkins pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=600s
```

Verify Jenkins is running:

```bash
kubectl get pods -n jenkins
kubectl get pvc -n jenkins
```

## Step 7: Configure RBAC for Kubernetes Plugin

The Jenkins Helm chart creates a service account, but we need to give it permissions to create pods for agents:

**Run on k3s-cluster1 (or any control plane node):**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-agent-manager
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "persistentvolumeclaims", "events"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-agent-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-agent-manager
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
EOF
```

## Step 8: Expose Jenkins via Gateway API

**Run on k3s-cluster1 (or any control plane node):**

Replace `jenkins.yourdomain.com` with your actual domain:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: jenkins-http
  namespace: jenkins
spec:
  selector:
    app.kubernetes.io/component: jenkins-controller
  ports:
  - name: http
    port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: jenkins-route
  namespace: jenkins
spec:
  parentRefs:
  - name: gateway
    namespace: nginx-gateway
  hostnames:
  - "jenkins.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: jenkins-http
      port: 80
EOF
```

For TLS with Let's Encrypt, update the Gateway resource:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: nginx-gateway
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "jenkins.yourdomain.com"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: jenkins-tls
EOF
```

## Step 9: Get Jenkins Admin Password

**Run on k3s-cluster1 (or any control plane node):**

```bash
# Get the admin password
kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
echo
```

Or if you used the values file, the password is what you set in `adminPassword`.

## Step 10: Access Jenkins UI

1. Ensure your DNS points `jenkins.yourdomain.com` to your load balancer IP
2. Open browser to `https://jenkins.yourdomain.com` (or `http://` if not using TLS yet)
3. Login with:
   - Username: `admin`
   - Password: (from Step 9)

## Step 11: Configure Kubernetes Plugin in Jenkins

This is done via the Jenkins UI:

1. Go to **Manage Jenkins** → **Manage Nodes and Clouds** → **Configure Clouds**
2. Click **Add a new cloud** → **Kubernetes**
3. Configure:
   - **Name**: `kubernetes`
   - **Kubernetes URL**: `https://kubernetes.default.svc.cluster.local`
   - **Kubernetes Namespace**: `jenkins`
   - **Credentials**: (should auto-select the service account)
   - **Jenkins URL**: `http://jenkins-http.jenkins.svc.cluster.local`
   - **Jenkins tunnel**: `jenkins-agent.jenkins.svc.cluster.local:50000`

4. Click **Test Connection** to verify

## Step 12: Create Pod Template for Dynamic Agents

In the Kubernetes cloud configuration:

1. Click **Pod Templates** → **Add Pod Template**
2. Configure:
   - **Name**: `jenkins-agent`
   - **Namespace**: `jenkins`
   - **Labels**: `jenkins-agent`
   - **Node Selector**: `jenkins-role=agent` (this ensures agents run on cluster2/cluster3)

3. Add Container:
   - **Name**: `jnlp`
   - **Docker image**: `jenkins/inbound-agent:latest`
   - **Working directory**: `/home/jenkins/agent`
   - **Command to run**: (leave empty)
   - **Arguments to pass**: (leave empty)

4. Set Resources (optional):
   - **Request CPU**: `500m`
   - **Request Memory**: `512Mi`
   - **Limit CPU**: `1000m`
   - **Limit Memory**: `1Gi`

5. Click **Save**

## Step 13: Test Dynamic Agent Provisioning

Create a test pipeline job:

1. **New Item** → **Pipeline**
2. Name it `test-k3s-agents`
3. In Pipeline script:

```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }
    stages {
        stage('Test') {
            steps {
                sh 'hostname'
                sh 'echo "Running on a dynamic Kubernetes agent"'
                sh 'kubectl get nodes'
            }
        }
    }
}
```

4. Click **Build Now**
5. Watch the build - Jenkins should spawn a pod on k3s-cluster2 or k3s-cluster3

Verify agent pods are created on the correct nodes:

```bash
# Run on k3s-cluster1
kubectl get pods -n jenkins -o wide | grep agent
```

The pods should be running on k3s-cluster2 or k3s-cluster3, NOT on k3s-cluster1.

## Step 14: Verify Complete Setup

**Run on k3s-cluster1 (or any control plane node):**

```bash
# Check Jenkins controller is on cluster1
kubectl get pods -n jenkins -o wide | grep jenkins-

# Check node labels
kubectl get nodes --show-labels | grep jenkins-role

# Test a build and watch agent pods
kubectl get pods -n jenkins -o wide --watch
```

## Troubleshooting

### Jenkins pod won't start
```bash
kubectl describe pod -n jenkins -l app.kubernetes.io/component=jenkins-controller
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller
```

### Agent pods won't spawn
```bash
# Check service account permissions
kubectl auth can-i create pods --namespace=jenkins --as=system:serviceaccount:jenkins:jenkins

# Check Jenkins logs for errors
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller --tail=100
```

### Can't access Jenkins UI
```bash
# Check service
kubectl get svc -n jenkins

# Check Gateway and HTTPRoute
kubectl get gateway -n nginx-gateway
kubectl get httproute -n jenkins

# Port forward for testing
kubectl port-forward -n jenkins svc/jenkins-http 8080:80
# Then access http://localhost:8080
```

## Summary

You now have:
- Jenkins controller running on k3s-cluster1
- Dynamic Kubernetes agents configured to spawn on k3s-cluster2 and k3s-cluster3
- TLS-enabled access via Gateway API
- Automatic certificate management with cert-manager
- Scalable build infrastructure with ephemeral agents

## Next Steps

- Create more pod templates for different build environments (Docker, Maven, Node.js, etc.)
- Configure Jenkins security and user management
- Set up Jenkins pipelines for your projects
- Monitor resource usage across the cluster
- Configure backup for Jenkins home directory
