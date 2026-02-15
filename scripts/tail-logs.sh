#!/bin/bash
# tail-logs.sh - Streams logs from a K8s pod to stdout

set -e

NAMESPACE="${NAMESPACE:-agent-orchestrator}"

usage() {
    echo "Usage: $0 <pod-name>"
    echo ""
    echo "Arguments:"
    echo "  pod-name     Name of the pod to tail logs from"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE    Kubernetes namespace (default: agent-orchestrator)"
    echo ""
    echo "Examples:"
    echo "  $0 agent-task-001"
    echo "  NAMESPACE=agent-orchestrator-prod $0 agent-task-001"
    exit 1
}

# Check arguments
[ $# -lt 1 ] && usage

POD_NAME="$1"

echo "Streaming logs from pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo "Press Ctrl+C to stop"
echo ""

kubectl logs -f -n "$NAMESPACE" "$POD_NAME"
