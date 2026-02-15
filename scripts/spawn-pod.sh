#!/bin/bash
# spawn-pod.sh - Creates a K8s pod for an [ASYNC] task using Helm templates
# Usage: spawn-pod.sh [OPTIONS] <task-id> <branch-name> <repo-url> [context-dir]
#   OR: agentic-sdlc-orchestrator spawn --task-id <id> --branch <branch> --repo <repo> --context-dir <dir>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMESPACE="${NAMESPACE:-agent-orchestrator}"
RELEASE_NAME="${RELEASE_NAME:-agentic-sdlc-orchestrator}"
SSH_SECRET_NAME="${SSH_SECRET_NAME:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Parse CLI-style arguments (for spec-kit integration)
parse_cli_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --task-id)
                TASK_ID="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --repo)
                REPO="$2"
                shift 2
                ;;
            --context-dir)
                CONTEXT_DIR="$2"
                shift 2
                ;;
            --ssh-secret)
                SSH_SECRET_NAME="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            spawn)
                # Handle 'agentic-sdlc-orchestrator spawn' syntax
                shift
                ;;
            *)
                # Unknown option - might be positional arg
                break
                ;;
        esac
    done
    
    # If we still have positional args after parsing CLI args, use them
    if [[ $# -gt 0 && -z "$TASK_ID" ]]; then
        TASK_ID="$1"
        shift
    fi
    if [[ $# -gt 0 && -z "$BRANCH" ]]; then
        BRANCH="$1"
        shift
    fi
    if [[ $# -gt 0 && -z "$REPO" ]]; then
        REPO="$1"
        shift
    fi
    if [[ $# -gt 0 && -z "$CONTEXT_DIR" ]]; then
        CONTEXT_DIR="$1"
        shift
    fi
}

usage() {
    echo "Usage: $0 [OPTIONS] <task-id> <branch-name> <repo-url> [context-dir]"
    echo "   OR: agentic-sdlc-orchestrator spawn --task-id <id> --branch <branch> --repo <repo> [--context-dir <dir>]"
    echo ""
    echo "Arguments (positional):"
    echo "  task-id      Unique identifier for the task (e.g., task-001)"
    echo "  branch-name  Git branch to clone (e.g., specs/feature-001/task-001-async)"
    echo "  repo-url     Git repository URL (SSH or HTTPS)"
    echo "  context-dir  Path to context files (optional, default: /workspace)"
    echo ""
    echo "Options (CLI-style):"
    echo "  --task-id <id>        Task identifier"
    echo "  --branch <branch>     Git branch name"
    echo "  --repo <url>          Repository URL"
    echo "  --context-dir <dir>   Context directory (default: /workspace)"
    echo "  --ssh-secret <name>   SSH key secret name"
    echo "  --environment <env>   Environment: dev, stg, prod (default: dev)"
    echo "  --namespace <ns>      Kubernetes namespace"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE        Kubernetes namespace (default: agent-orchestrator)"
    echo "  RELEASE_NAME     Helm release name (default: agentic-sdlc-orchestrator)"
    echo "  SSH_SECRET_NAME  Name of K8s secret containing SSH key (optional)"
    echo "  ENVIRONMENT      Environment to use: dev, stg, prod (default: dev)"
    echo ""
    echo "Examples:"
    echo "  # Positional arguments (direct usage)"
    echo "  $0 task-001 specs/feature/task-001-async https://github.com/user/repo"
    echo ""
    echo "  # CLI-style arguments (spec-kit integration)"
    echo "  agentic-sdlc-orchestrator spawn --task-id task-001 --branch specs/feature/task-001-async --repo https://github.com/user/repo"
    echo ""
    echo "  # With SSH authentication"
    echo "  SSH_SECRET_NAME=github-deploy-key $0 task-001 specs/feature/task-001-async git@github.com:user/repo.git"
    echo ""
    echo "  # Production environment"
    echo "  ENVIRONMENT=prod NAMESPACE=agent-orchestrator-prod $0 task-001 specs/feature/task-001-async https://github.com/user/repo"
}

# Parse arguments (supports both CLI-style and positional)
parse_cli_args "$@"

# Validate required arguments
if [[ -z "$TASK_ID" ]]; then
    echo "Error: task-id is required"
    usage
    exit 1
fi

if [[ -z "$BRANCH" ]]; then
    echo "Error: branch-name is required"
    usage
    exit 1
fi

if [[ -z "$REPO" ]]; then
    echo "Error: repo-url is required"
    usage
    exit 1
fi

# Set default context dir if not provided
CONTEXT_DIR="${CONTEXT_DIR:-/workspace}"

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
    echo "  # OR use tail-logs.sh:"
    echo "  ./scripts/tail-logs.sh $POD_NAME"
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
