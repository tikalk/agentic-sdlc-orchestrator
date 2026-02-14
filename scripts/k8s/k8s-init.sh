#!/bin/bash
# k8s-init.sh - Initialize K8s resources for agent orchestration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-agent-orchestrator}"

echo "Initializing K8s resources for agent orchestration..."
echo "Namespace: $NAMESPACE"

# Create namespace
echo "Creating namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount
echo "Creating ServiceAccount..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: agent-orchestrator
  namespace: $NAMESPACE
EOF

# Create RBAC
echo "Creating RBAC..."
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: agent-orchestrator
  namespace: $NAMESPACE
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: agent-orchestrator
  namespace: $NAMESPACE
subjects:
  - kind: ServiceAccount
    name: agent-orchestrator
    namespace: $NAMESPACE
roleRef:
  kind: Role
  name: agent-orchestrator
  apiGroup: rbac.authorization.k8s.io
EOF

# Create ConfigMap
echo "Creating ConfigMap..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-orchestrator-config
  namespace: $NAMESPACE
data:
  server-password: "changeme"
EOF

echo ""
echo "K8s resources initialized successfully!"
echo ""
echo "Summary:"
echo "  - Namespace: $NAMESPACE"
echo "  - ServiceAccount: agent-orchestrator"
echo "  - Role: agent-orchestrator"
echo "  - ConfigMap: agent-orchestrator-config"
echo ""
echo "Next steps:"
echo "  1. Build and push the OpenCode Docker image"
echo "  2. Configure git credentials (see docs)"
echo "  3. Run: ./spawn-pod.sh <task-id> <branch> <repo> <context>"
