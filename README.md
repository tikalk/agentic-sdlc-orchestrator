# Agentic SDLC Orchestrator

K8s-based async agent orchestration for Agentic SDLC. Enables running AI coding agents (OpenCode) in Kubernetes pods with full visibility from the main session.

## Overview

This orchestrator integrates with [spec-kit](https://github.com/tikalk/agentic-sdlc-spec-kit) to run [ASYNC] tasks in Kubernetes pods while maintaining visibility through the main OpenCode session.

### Key Features

- **Helm-based deployment**: Standard Kubernetes deployment via Helm charts
- **External Secrets Operator**: Secure secret management (no hardcoded passwords)
- **Multi-environment support**: Dev, staging, and production configurations
- **GitOps ready**: ArgoCD Application manifests included
- **Subagent-based orchestration**: Spawns K8s pods via OpenCode subagents
- **Git-native workflow**: Each task uses isolated git branches
- **Log streaming**: Pod logs stream back to main session
- **Parallel execution**: Multiple [ASYNC] tasks run concurrently

## Architecture

```
Main OpenCode Session
    │
    ├──► Subagent → Helm/Kubectl → K8s Pod
    │                              → kubectl logs → main session
    │                              → git commit/push
    │
    └──► Subagent → Helm/Kubectl → K8s Pod
                                  → kubectl logs → main session
```

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- kubectl configured
- External Secrets Operator installed
- Git
- OpenCode CLI

## Quick Start

### 1. Deploy to Kubernetes

#### Development
```bash
cd releases/agentic-sdlc-orchestrator-dev
helm dependency update
helm upgrade --install agentic-sdlc-orchestrator-dev . \
  -n agent-orchestrator-dev --create-namespace
```

#### Staging
```bash
cd releases/agentic-sdlc-orchestrator-stg
helm dependency update
helm upgrade --install agentic-sdlc-orchestrator-stg . \
  -n agent-orchestrator-stg --create-namespace
```

#### Production
```bash
cd releases/agentic-sdlc-orchestrator-prod
helm dependency update
helm upgrade --install agentic-sdlc-orchestrator-prod . \
  -n agent-orchestrator-prod --create-namespace
```

### 2. Configure External Secrets

Before deploying, ensure External Secrets Operator is configured:

```yaml
# Example ClusterSecretStore
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: secret-store
spec:
  provider:
    gcpsm:
      projectID: my-project
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: my-cluster
          serviceAccountRef:
            name: external-secrets-sa
```

Create the secret in your secret manager:
```
agentic-sdlc/dev/server-password
  - server-password: <secure-password>
```

### 3. Build and Push Docker Image

```bash
docker build -t your-registry/agentic-sdlc-opencode:0.1.0 \
  -f docker/Dockerfile.opencode .
docker push your-registry/agentic-sdlc-opencode:0.1.0
```

Update the image tag in `values.yaml`:
```yaml
pod:
  image:
    repository: your-registry/agentic-sdlc-opencode
    tag: "0.1.0"
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

### Spawn a Task Pod

**Option 1: Using the helper script (Recommended)**

```bash
# Using the Helm-based spawn-pod.sh script
./scripts/spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo

# With SSH authentication
SSH_SECRET_NAME=github-deploy-key ./scripts/spawn-pod.sh task-001 specs/feature/task-001-async git@github.com:user/repo.git

# Production environment
ENVIRONMENT=prod ./scripts/spawn-pod.sh task-001 specs/feature/task-001-async https://github.com/user/repo

# Stream logs
./scripts/tail-logs.sh agent-task-001
```

**Option 2: Using kubectl directly**

```bash
kubectl run agent-task-001 \
  --image=agentic-sdlc/opencode:0.1.0 \
  --restart=Never \
  --namespace=agent-orchestrator-dev \
  --env="GIT_REPO=https://github.com/user/repo" \
  --env="GIT_BRANCH=specs/feature/task-001-async" \
  --env="OPENCODE_SERVER_PASSWORD=$(kubectl get secret agentic-sdlc-orchestrator-dev-server-password -n agent-orchestrator-dev -o jsonpath='{.data.server-password}' | base64 -d)"

# Stream logs
kubectl logs -f agent-task-001 -n agent-orchestrator-dev
```

### Helper Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `spawn-pod.sh` | Creates K8s pod using Helm templates | `scripts/spawn-pod.sh` |
| `tail-logs.sh` | Streams pod logs to stdout | `scripts/tail-logs.sh` |

See [scripts/README.md](scripts/README.md) for detailed usage.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NAMESPACE` | K8s namespace | `agent-orchestrator` |
| `OPENCODE_SERVER_PASSWORD` | OpenCode server password | From ExternalSecret |
| `GIT_REPO` | Repository URL | - |
| `GIT_BRANCH` | Git branch to clone | `main` |

## Configuration

See [charts/agentic-sdlc-orchestrator/README.md](charts/agentic-sdlc-orchestrator/README.md) for detailed Helm configuration options.

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Namespace for resources | Release namespace |
| `serviceAccount.annotations` | ServiceAccount annotations (for Workload Identity) | `{}` |
| `externalSecret.enabled` | Enable External Secrets Operator integration | `true` |
| `externalSecret.remoteRef.key` | Secret key in external store | `agentic-sdlc/dev/server-password` |
| `pod.image.repository` | Image repository | `agentic-sdlc/opencode` |
| `pod.image.tag` | Image tag | `0.1.0` |
| `pod.resources` | Resource limits and requests | See values.yaml |

## GitOps with ArgoCD

Each environment includes an `argocd.yaml` configuration file:

```bash
# Apply ArgoCD Application
kubectl apply -f releases/agentic-sdlc-orchestrator-prod/argocd.yaml
```

Or create the Application manually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: agentic-sdlc-orchestrator-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tikalk/agentic-sdlc-orchestrator.git
    targetRevision: main
    path: releases/agentic-sdlc-orchestrator-prod
  destination:
    server: https://kubernetes.default.svc
    namespace: agent-orchestrator-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Integration with spec-kit

The orchestrator integrates with spec-kit's `--async-agent` flag. When running `/implement`, [ASYNC] tasks automatically spawn K8s pods via the orchestrator.

See [SPEC.md](./SPEC.md) for technical details.

## Development

### Project Structure

```
agentic-sdlc-orchestrator/
├── SPEC.md                      # Technical specification
├── PRD.md                       # Product requirements
├── pyproject.toml               # Python package config
├── docker/
│   └── Dockerfile.opencode      # OpenCode container
├── charts/
│   └── agentic-sdlc-orchestrator/  # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── README.md
│       └── templates/
│           ├── _helpers.tpl
│           ├── namespace.yaml
│           ├── serviceaccount.yaml
│           ├── rbac.yaml
│           ├── configmap.yaml
│           ├── external-secret.yaml
│           └── pod-template.yaml
├── releases/
│   ├── agentic-sdlc-orchestrator-dev/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── argocd.yaml
│   ├── agentic-sdlc-orchestrator-stg/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── argocd.yaml
│   └── agentic-sdlc-orchestrator-prod/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── argocd.yaml
└── scripts/
    ├── spawn-pod.sh             # Create task pods via Helm
    ├── tail-logs.sh             # Stream pod logs
    └── README.md                # Scripts documentation
```

### Local Development

```bash
# Clone repository
git clone https://github.com/tikalk/agentic-sdlc-orchestrator.git
cd agentic-sdlc-orchestrator

# Install dependencies
pip install -e .

# Test Helm templates
helm template agentic-sdlc-orchestrator charts/agentic-sdlc-orchestrator

# Lint Helm chart
helm lint charts/agentic-sdlc-orchestrator
```

## Security

- **No hardcoded secrets**: All sensitive data managed via External Secrets Operator
- **Workload Identity**: Support for GKE Workload Identity
- **RBAC**: Least-privilege role-based access control
- **Namespace isolation**: Separate namespaces per environment

## Uninstallation

```bash
# Development
helm uninstall agentic-sdlc-orchestrator-dev -n agent-orchestrator-dev

# Staging
helm uninstall agentic-sdlc-orchestrator-stg -n agent-orchestrator-stg

# Production
helm uninstall agentic-sdlc-orchestrator-prod -n agent-orchestrator-prod
```

## License

MIT

## Related Projects

- [agentic-sdlc-spec-kit](https://github.com/tikalk/agentic-sdlc-spec-kit) - Spec-driven development toolkit
- [agentic-sdlc-team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives) - Team AI directives
