#!/bin/bash
# spawn-pod.sh - Creates a K8s pod for an [ASYNC] task

set -e

NAMESPACE="${NAMESPACE:-agent-orchestrator}"
SSH_SECRET_NAME="${SSH_SECRET_NAME:-}"

usage() {
    echo "Usage: $0 <task-id> <branch-name> <repo-url> <context-dir>"
    echo ""
    echo "Arguments:"
    echo "  task-id      Unique identifier for the task (e.g., task-001)"
    echo "  branch-name  Git branch to clone (e.g., specs/feature-001/task-001-async)"
    echo "  repo-url    Git repository URL (SSH or HTTPS)"
    echo "  context-dir  Path to context files (spec.md, plan.md)"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE        Kubernetes namespace (default: agent-orchestrator)"
    echo "  SSH_SECRET_NAME  Name of K8s secret containing SSH key (optional)"
    echo ""
    echo "Example (HTTPS):"
    echo "  $0 task-001 specs/feature/task-001-async https://github.com/user/repo /context"
    echo ""
    echo "Example (SSH with secret):"
    echo "  SSH_SECRET_NAME=github-deploy-key $0 task-001 specs/feature/task-001-async git@github.com:user/repo.git /context"
    exit 1
}

[ $# -lt 4 ] && usage

TASK_ID="$1"
BRANCH="$2"
REPO="$3"
CONTEXT_DIR="$4"

echo "Creating pod for task: $TASK_ID"
echo "Branch: $BRANCH"
echo "Repo: $REPO"
echo "Namespace: $NAMESPACE"
echo "SSH Secret: ${SSH_SECRET_NAME:-none}"

# Build the pod manifest
MANIFEST=$(cat <<'MANIFEST_EOF'
apiVersion: v1
kind: Pod
metadata:
  name: agent-TASK_ID
  labels:
    app: agent-orchestrator
    task-id: TASK_ID
spec:
  restartPolicy: Never
  containers:
    - name: agent
      image: agentic-sdlc/opencode:latest
      env:
        - name: OPENCODE_SERVER_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: agent-orchestrator-config
              key: server-password
        - name: GIT_REPO
          value: "REPO"
        - name: GIT_BRANCH
          value: "BRANCH"
        - name: TASK_CONTEXT_PATH
          value: "CONTEXT_DIR"
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          cd /workspace
          echo "Cloning repository..."
          git clone -b BRANCH REPO .
          echo "Cloned repository successfully"
          ls -la
          echo "Starting OpenCode..."
          opencode run "Implement the task described in $(ls *.md | head -1)"
          echo "OpenCode finished, committing changes..."
          git add .
          git commit -m "feat: completed TASK_ID" || echo "No changes to commit"
          echo "Pushing to remote..."
          git push || echo "Push failed (may already be up to date)"
      resources:
        limits:
          cpu: "2"
          memory: "4Gi"
        requests:
          cpu: "1"
          memory: "2Gi"
  serviceAccountName: agent-orchestrator
MANIFEST_EOF
)

# Replace placeholders
MANIFEST="${MANIFEST//TASK_ID/$TASK_ID}"
MANIFEST="${MANIFEST//REPO/$REPO}"
MANIFEST="${MANIFEST//BRANCH/$BRANCH}"
MANIFEST="${MANIFEST//CONTEXT_DIR/$CONTEXT_DIR}"

# Add SSH volume if secret is provided
if [ -n "$SSH_SECRET_NAME" ]; then
    SSH_VOLUME_MOUNT=$(cat <<'EOF'
      volumeMounts:
        - name: ssh-key
          mountPath: /root/.ssh
          readOnly: true
EOF
)

    SSH_VOLUME=$(cat <<EOF
  volumes:
    - name: ssh-key
      secret:
        secretName: $SSH_SECRET_NAME
EOF
)

    # Insert SSH volume and volumeMount
    MANIFEST=$(echo "$MANIFEST" | sed "s|  serviceAccountName: agent-orchestrator|$SSH_VOLUME\n  serviceAccountName: agent-orchestrator|")
    MANIFEST=$(echo "$MANIFEST" | sed "s|      resources:|      $SSH_VOLUME_MOUNT\n      resources:|")

    echo "SSH secret '$SSH_SECRET_NAME' will be mounted"
fi

# Apply manifest
echo "$MANIFEST" | kubectl apply -f -

echo ""
echo "Pod agent-${TASK_ID} created successfully in namespace ${NAMESPACE}"
echo "Use './tail-logs.sh agent-${TASK_ID}' to watch progress"
