# Scripts

Helper scripts for the Agentic SDLC Orchestrator.

## Available Scripts

### spawn-pod.sh

Creates a Kubernetes pod for an [ASYNC] task using Helm templates.

**Dual Interface:**
The script supports both **positional arguments** (for direct usage) and **CLI-style flags** (for spec-kit integration).

#### Usage (Positional Arguments)
```bash
./spawn-pod.sh <task-id> <branch-name> <repo-url> [context-dir]
```

#### Usage (CLI-style - spec-kit Integration)
```bash
./spawn-pod.sh --task-id <id> --branch <branch> --repo <url> [--context-dir <dir>]
# OR (when installed as 'agentic-sdlc-orchestrator' command)
agentic-sdlc-orchestrator spawn --task-id <id> --branch <branch> --repo <url>
```

#### Arguments

**Positional:**
- `task-id` - Unique identifier for the task (e.g., task-001)
- `branch-name` - Git branch to clone (e.g., specs/feature-001/task-001-async)
- `repo-url` - Git repository URL (SSH or HTTPS)
- `context-dir` - Path to context files (optional, default: /workspace)

**CLI-style Options:**
- `--task-id <id>` - Task identifier
- `--branch <branch>` - Git branch name
- `--repo <url>` - Repository URL
- `--context-dir <dir>` - Context directory (default: /workspace)
- `--ssh-secret <name>` - SSH key secret name
- `--environment <env>` - Environment: dev, stg, prod (default: dev)
- `--namespace <ns>` - Kubernetes namespace

**Environment Variables:**
- `NAMESPACE` - Kubernetes namespace (default: agent-orchestrator)
- `RELEASE_NAME` - Helm release name (default: agentic-sdlc-orchestrator)
- `SSH_SECRET_NAME` - Name of K8s secret containing SSH key (optional)
- `ENVIRONMENT` - Environment to use: dev, stg, prod (default: dev)

#### Examples

**Direct Usage (Positional):**
```bash
# HTTPS repository
./spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo

# SSH repository with SSH key secret
SSH_SECRET_NAME=github-deploy-key ./spawn-pod.sh task-001 specs/feature/task-001-async git@github.com:user/repo.git

# Production environment
ENVIRONMENT=prod NAMESPACE=agent-orchestrator-prod ./spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo
```

**spec-kit Integration (CLI-style):**
```bash
# spec-kit automatically calls with these flags
./scripts/spawn-pod.sh \
  --task-id task-001 \
  --branch specs/feature/task-001-async \
  --repo https://github.com/user/repo \
  --context-dir /path/to/feature
```

#### How it works
1. Parses arguments (supports both positional and CLI-style)
2. Uses Helm to template the pod manifest from the release charts
3. Applies the manifest with kubectl
4. Prints useful kubectl commands for monitoring

#### spec-kit Integration
When a task has `agent_type: agentic-sdlc-orchestrator` in tasks_meta.json, spec-kit's `implement.sh` will:
1. Detect the orchestrator script at `./scripts/spawn-pod.sh`
2. Call it with `--task-id`, `--branch`, `--repo`, and `--context-dir` flags
3. Fall back to standard async delegation if the script is not found

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
