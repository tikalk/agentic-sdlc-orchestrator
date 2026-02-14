#!/bin/bash
# agentic-sdlc-orchestrator - Main entry point for spec-kit integration

# Usage: agentic-sdlc-orchestrator <command> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")/k8s"

usage() {
    echo "Agentic SDLC Orchestrator - K8s-based async task execution"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  spawn    Spawn a K8s pod for async task execution"
    echo "  status   Check status of a task"
    echo "  logs     Stream logs from a task pod"
    echo "  list     List all running pods"
    echo ""
    echo "Examples:"
    echo "  $0 spawn --task-id task-001 --branch feature-001 --repo https://github.com/user/repo"
    echo "  $0 status --task-id task-001"
    echo "  $0 logs --task-id task-001"
    exit 1
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    spawn)
        TASK_ID=""
        BRANCH=""
        REPO=""
        CONTEXT_DIR="."
        SSH_SECRET_NAME="${SSH_SECRET_NAME:-}"

        while [[ $# -gt 0 ]]; do
            case "$1" in
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
                *)
                    echo "Unknown option: $1"
                    usage
                    ;;
            esac
        done

        if [[ -z "$TASK_ID" ]] || [[ -z "$BRANCH" ]] || [[ -z "$REPO" ]]; then
            echo "Error: --task-id, --branch, and --repo are required"
            exit 1
        fi

        # Check if spawn-pod.sh exists
        if [[ ! -f "$K8S_SCRIPTS_DIR/spawn-pod.sh" ]]; then
            echo "Error: spawn-pod.sh not found at $K8S_SCRIPTS_DIR"
            exit 1
        fi

        # Run spawn-pod.sh
        SSH_SECRET_NAME="$SSH_SECRET_NAME" "$K8S_SCRIPTS_DIR/spawn-pod.sh" \
            "$TASK_ID" \
            "$BRANCH" \
            "$REPO" \
            "$CONTEXT_DIR"
        ;;

    status)
        TASK_ID=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --task-id)
                    TASK_ID="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    usage
                    ;;
            esac
        done

        if [[ -z "$TASK_ID" ]]; then
            echo "Error: --task-id is required"
            exit 1
        fi

        kubectl get pod "agent-$TASK_ID" -o wide 2>/dev/null || echo "Pod not found"
        ;;

    logs)
        TASK_ID=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --task-id)
                    TASK_ID="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    usage
                    ;;
            esac
        done

        if [[ -z "$TASK_ID" ]]; then
            echo "Error: --task-id is required"
            exit 1
        fi

        # Check if tail-logs.sh exists
        if [[ -f "$K8S_SCRIPTS_DIR/tail-logs.sh" ]]; then
            "$K8S_SCRIPTS_DIR/tail-logs.sh" "agent-$TASK_ID"
        else
            kubectl logs -f "agent-$TASK_ID"
        fi
        ;;

    list)
        kubectl get pods -l app=agent-orchestrator -o wide
        ;;

    *)
        usage
        ;;
esac
