#!/bin/bash
# tail-logs.sh - Tails logs from a K8s pod to stdout

NAMESPACE="${NAMESPACE:-agent-orchestrator}"

POD_NAME="$1"

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <pod-name>"
    echo ""
    echo "Arguments:"
    echo "  pod-name    Name of the pod to tail logs from"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE   Kubernetes namespace (default: agent-orchestrator)"
    exit 1
fi

echo "Tailing logs for pod: $POD_NAME in namespace: $NAMESPACE"
echo "Press Ctrl+C to stop"
echo "---"

kubectl logs -f -n "$NAMESPACE" "$POD_NAME"

echo "---"
echo "Log stream ended"
