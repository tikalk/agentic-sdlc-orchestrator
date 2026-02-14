# Agentic SDLC Orchestrator

K8s-based async agent orchestration for Agentic SDLC. Enables running AI coding agents (OpenCode) in Kubernetes pods with full visibility from the main session.

## Overview

This orchestrator integrates with [spec-kit](https://github.com/github/agentic-sdlc-spec-kit) to run [ASYNC] tasks in Kubernetes pods while maintaining visibility through the main OpenCode session.

### Key Features

- **Subagent-based orchestration**: Spawns K8s pods via OpenCode subagents
- **Git-native workflow**: Each task uses isolated git branches
- **Log streaming**: Pod logs stream back to main session
- **Parallel execution**: Multiple [ASYNC] tasks run concurrently

## Architecture

```
Main OpenCode Session
    │
    ├──► Subagent → spawn-pod.sh → K8s Pod
    │                              → tail-logs.sh → main session
    │                              → git commit/push
    │
    └──► Subagent → spawn-pod.sh → K8s Pod
                                 → tail-logs.sh → main session
```

## Installation

### Prerequisites

- Kubernetes 1.25+
- kubectl configured
- Git
- OpenCode CLI

### Install via pip

```bash
pip install git+https://github.com/tikalk/agentic-sdlc-orchestrator.git
```

### Or clone and install

```bash
git clone https://github.com/tikalk/agentic-sdlc-orchestrator.git
cd agentic-sdlc-orchestrator
pip install -e .
```

## Quick Start

### 1. Initialize K8s Resources

```bash
./scripts/k8s/k8s-init.sh
```

### 2. (Optional) Configure Git SSH Credentials

```bash
# Create SSH key if you don't have one
ssh-keygen -t ed25519 -C "agent-orchestrator"

# Add public key to GitHub/GitLab

# Create K8s secret
./scripts/k8s/create-git-secret.sh github-deploy-key ~/.ssh/id_ed25519
```

### 3. Build and Push Docker Image

```bash
docker build -t your-registry/agentic-sdlc-opencode:latest -f docker/Dockerfile.opencode .
docker push your-registry/agentic-sdlc-opencode:latest

# Update spawn-pod.sh with your image
```

### 4. Use with spec-kit

```bash
# Initialize project with orchestrator
specify init my-project --async-agent agentic-sdlc-orchestrator

# Create spec, plan, tasks
/specify
/plan
/tasks

# Implement - [ASYNC] tasks will spawn K8s pods
/implement
```

## Usage

### CLI Commands

```bash
# Spawn a pod
agentic-sdlc-orchestrator spawn \
  --task-id task-001 \
  --branch specs/feature/task-001-async \
  --repo https://github.com/user/repo

# Check status
agentic-sdlc-orchestrator status --task-id task-001

# Stream logs
agentic-sdlc-orchestrator logs --task-id task-001

# List pods
agentic-sdlc-orchestrator list
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NAMESPACE` | K8s namespace | `agent-orchestrator` |
| `SSH_SECRET_NAME` | SSH key secret name | - |

## Scripts

| Script | Purpose |
|--------|---------|
| `k8s-init.sh` | Initialize K8s resources |
| `spawn-pod.sh` | Create pod for task |
| `tail-logs.sh` | Stream pod logs |
| `create-git-secret.sh` | Create SSH secret |

## Integration with spec-kit

The orchestrator integrates with spec-kit's `--async-agent` flag. When running `/implement`, [ASYNC] tasks automatically spawn K8s pods.

See [SPEC.md](./SPEC.md) for technical details.

## Development

### Project Structure

```
agentic-sdlc-orchestrator/
├── SPEC.md                    # Technical specification
├── PRD.md                     # Product requirements
├── pyproject.toml             # Python package config
├── docker/
│   └── Dockerfile.opencode    # OpenCode container
├── k8s/
│   ├── namespace.yaml
│   ├── rbac.yaml
│   ├── configmap.yaml
│   └── pod-template.yaml
└── scripts/k8s/
    ├── k8s-init.sh
    ├── spawn-pod.sh
    ├── tail-logs.sh
    └── create-git-secret.sh
```

## License

MIT

## Related Projects

- [agentic-sdlc-spec-kit](https://github.com/github/agentic-sdlc-spec-kit) - Spec-driven development toolkit
- [agentic-sdlc-team-ai-directives](https://github.com/github/agentic-sdlc-team-ai-directives) - Team AI directives
