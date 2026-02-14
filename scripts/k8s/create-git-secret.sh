#!/bin/bash
# create-git-secret.sh - Create K8s secret from SSH key

set -e

NAMESPACE="${NAMESPACE:-agent-orchestrator}"

usage() {
    echo "Usage: $0 <secret-name> <path-to-private-key>"
    echo ""
    echo "Arguments:"
    echo "  secret-name          Name for the K8s secret (e.g., github-deploy-key)"
    echo "  path-to-private-key  Path to SSH private key (e.g., ~/.ssh/id_ed25519)"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE   Kubernetes namespace (default: agent-orchestrator)"
    echo ""
    echo "Example:"
    echo "  $0 github-deploy-key ~/.ssh/id_ed25519"
    exit 1
}

[ $# -lt 2 ] && usage

SECRET_NAME="$1"
KEY_PATH="$2"

# Expand tilde
KEY_PATH="${KEY_PATH/#\~/$HOME}"

if [ ! -f "$KEY_PATH" ]; then
    echo "Error: Private key not found at: $KEY_PATH"
    exit 1
fi

echo "Creating SSH secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
echo "Key: $KEY_PATH"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true

# Create the secret
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-file=id_rsa="$KEY_PATH" \
    --type=Opaque \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo ""
echo "Secret '$SECRET_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "  1. Add the public key to your git host (GitHub/GitLab)"
echo "  2. Run pods with SSH_SECRET_NAME=$SECRET_NAME"
echo ""
echo "Example spawn command:"
echo "  SSH_SECRET_NAME=$SECRET_NAME ./spawn-pod.sh task-001 branch https://github.com/user/repo /context"
