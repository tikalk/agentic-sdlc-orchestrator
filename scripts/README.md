# Scripts

Helper scripts for the Agentic SDLC Orchestrator.

## Available Scripts

### spawn-pod.sh

Creates a Kubernetes pod for an [ASYNC] task using Helm templates.

**Usage:**
```bash
./spawn-pod.sh <task-id> <branch-name> <repo-url> [context-dir]
```

**Arguments:**
- `task-id` - Unique identifier for the task (e.g., task-001)
- `branch-name` - Git branch to clone (e.g., specs/feature-001/task-001-async)
- `repo-url` - Git repository URL (SSH or HTTPS)
- `context-dir` - Path to context files (optional, default: /workspace)

**Environment Variables:**
- `NAMESPACE` - Kubernetes namespace (default: agent-orchestrator)
- `RELEASE_NAME` - Helm release name (default: agentic-sdlc-orchestrator)
- `SSH_SECRET_NAME` - Name of K8s secret containing SSH key (optional)
- `ENVIRONMENT` - Environment to use: dev, stg, prod (default: dev)

**Examples:**

```bash
# HTTPS repository
./spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo

# SSH repository with SSH key secret
SSH_SECRET_NAME=github-deploy-key ./spawn-pod.sh task-001 specs/feature/task-001-async git@github.com:user/repo.git

# Production environment
ENVIRONMENT=prod NAMESPACE=agent-orchestrator-prod ./spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo
```

**How it works:**
1. Uses Helm to template the pod manifest from the release charts
2. Applies the manifest with kubectl
3. Prints useful kubectl commands for monitoring

### tail-logs.sh

Streams logs from a Kubernetes pod to stdout.

**Usage:**
```bash
./tail-logs.sh <pod-name>
```

**Arguments:**
- `pod-name` - Name of the pod to tail logs from

**Environment Variables:**
- `NAMESPACE` - Kubernetes namespace (default: agent-orchestrator)

**Examples:**

```bash
# Tail logs from a pod
./tail-logs.sh agent-task-001

# Production namespace
NAMESPACE=agent-orchestrator-prod ./tail-logs.sh agent-task-001
```

## Prerequisites

- Helm 3.8+
- kubectl configured with cluster access
- External Secrets Operator installed in the cluster
- Helm releases deployed (dev/stg/prod)

## Deployment Flow

1. **Deploy the Helm chart first:**
   ```bash
   cd releases/agentic-sdlc-orchestrator-dev
   helm dependency update
   helm upgrade --install agentic-sdlc-orchestrator-dev . \
     -n agent-orchestrator-dev --create-namespace
   ```

2. **Then spawn task pods:**
   ```bash
   ./scripts/spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo
   ```

3. **Monitor logs:**
   ```bash
   ./scripts/tail-logs.sh agent-task-001
   ```
