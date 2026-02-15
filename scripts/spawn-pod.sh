#!/bin/bash
# spawn-pod.sh - Creates a K8s pod for an [ASYNC] task using Helm templates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMESPACE="${NAMESPACE:-agent-orchestrator}"
RELEASE_NAME="${RELEASE_NAME:-agentic-sdlc-orchestrator}"
SSH_SECRET_NAME="${SSH_SECRET_NAME:-}"

usage() {
    echo "Usage: $0 <task-id> <branch-name> <repo-url> [context-dir]"
    echo ""
    echo "Arguments:"
    echo "  task-id      Unique identifier for the task (e.g., task-001)"
    echo "  branch-name  Git branch to clone (e.g., specs/feature-001/task-001-async)"
    echo "  repo-url     Git repository URL (SSH or HTTPS)"
    echo "  context-dir  Path to context files (optional, e.g., /workspace)"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE        Kubernetes namespace (default: agent-orchestrator)"
    echo "  RELEASE_NAME     Helm release name (default: agentic-sdlc-orchestrator)"
    echo "  SSH_SECRET_NAME  Name of K8s secret containing SSH key (optional)"
    echo "  ENVIRONMENT      Environment to use: dev, stg, prod (default: dev)"
    echo ""
    echo "Examples:"
    echo "  # HTTPS repository"
    echo "  $0 task-001 specs/feature/task-001-async https://github.com/user/repo"
    echo ""
    echo "  # SSH repository with SSH key secret"
    echo "  SSH_SECRET_NAME=github-deploy-key $0 task-001 specs/feature/task-001-async git@github.com:user/repo.git"
    echo ""
    echo "  # Production environment"
    echo "  ENVIRONMENT=prod NAMESPACE=agent-orchestrator-prod $0 task-001 specs/feature/task-001-async https://github.com/user/repo"
    exit 1
}

# Check arguments
[ $# -lt 3 ] && usage

TASK_ID="$1"
BRANCH="$2"
REPO="$3"
CONTEXT_DIR="${4:-/workspace}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "================================"
echo "Spawning K8s Pod via Helm"
echo "================================"
echo "Task ID:      $TASK_ID"
echo "Branch:       $BRANCH"
echo "Repo:         $REPO"
echo "Context Dir:  $CONTEXT_DIR"
echo "Namespace:    $NAMESPACE"
echo "Environment:  $ENVIRONMENT"
echo "SSH Secret:   ${SSH_SECRET_NAME:-none}"
echo ""

# Determine which release to use
RELEASE_DIR="${PROJECT_ROOT}/releases/${RELEASE_NAME}-${ENVIRONMENT}"
if [ ! -d "$RELEASE_DIR" ]; then
    echo "Error: Release directory not found: $RELEASE_DIR"
    echo "Available environments:"
    ls -1 "${PROJECT_ROOT}/releases/" 2>/dev/null || echo "  (none found)"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed. Please install Helm 3.8+"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed. Please install kubectl"
    exit 1
fi

# Build Helm values
echo "Building pod manifest with Helm..."

HELM_VALUES=""
HELM_VALUES="${HELM_VALUES} --set task.id=$TASK_ID"
HELM_VALUES="${HELM_VALUES} --set task.branch=$BRANCH"
HELM_VALUES="${HELM_VALUES} --set task.repo=$REPO"
HELM_VALUES="${HELM_VALUES} --set task.contextDir=$CONTEXT_DIR"

# Add SSH secret if provided
if [ -n "$SSH_SECRET_NAME" ]; then
    HELM_VALUES="${HELM_VALUES} --set pod.sshSecret.enabled=true"
    HELM_VALUES="${HELM_VALUES} --set pod.sshSecret.name=$SSH_SECRET_NAME"
fi

# Generate pod name
POD_NAME="agent-${TASK_ID}"

# Generate and apply the manifest
echo "Generating manifest from Helm chart..."
echo "Release: ${RELEASE_NAME}-${ENVIRONMENT}"
echo ""

# Use helm template to generate the manifest, then apply only the Pod
helm template "${RELEASE_NAME}-${ENVIRONMENT}" "$RELEASE_DIR" \
    $HELM_VALUES \
    --namespace "$NAMESPACE" 2>/dev/null | \
    kubectl apply -f - --namespace "$NAMESPACE"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "Pod created successfully!"
    echo "================================"
    echo "Pod Name:     $POD_NAME"
    echo "Namespace:    $NAMESPACE"
    echo ""
    echo "Useful commands:"
    echo "  # Stream logs:"
    echo "  kubectl logs -f $POD_NAME -n $NAMESPACE"
    echo ""
    echo "  # Check status:"
    echo "  kubectl get pod $POD_NAME -n $NAMESPACE"
    echo ""
    echo "  # Describe pod:"
    echo "  kubectl describe pod $POD_NAME -n $NAMESPACE"
    echo ""
    echo "  # Delete pod:"
    echo "  kubectl delete pod $POD_NAME -n $NAMESPACE"
else
    echo ""
    echo "Error: Failed to create pod"
    exit 1
fi
