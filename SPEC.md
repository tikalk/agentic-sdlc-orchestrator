# SPEC.md - K8s Agent Orchestration via OpenCode Subagents

**Project Name**: Agentic SDLC Orchestrator  
**Version**: 1.0.0  
**Date**: 2026-02-14  
**Status**: Draft

---

## 1. Overview

### Purpose

Enable local OpenCode CLI sessions to spawn and control remote AI agent pods running in Kubernetes, with full visibility from the main session.

### Scope

- Spawn K8s pods for [ASYNC] tasks via OpenCode subagents
- Stream pod logs back to the main session
- Autonomous execution with git-based completion detection
- Integration with existing spec-kit workflow

### Out of Scope

- External orchestrator/controller (we use subagents)
- K-Agent framework
- Beads issue tracking
- Web dashboard
- Mayor pattern (Gastown)

---

## 2. Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MAIN OPENCODE SESSION                                │
│                                                                         │
│   Human: /implement                                                    │
│     │                                                                  │
│     ├──► Subagent 1: "Implement T001"                                │
│     │       ├── spawn-pod.sh T001 branch-async                       │
│     │       ├── tail-logs.sh pod-001 → streams to main session       │
│     │       └── git commit + push when done                          │
│     │                                                                  │
│     ├──► Subagent 2: "Implement T002" (parallel)                   │
│     │       ├── spawn-pod.sh T002 branch-async                       │
│     │       ├── tail-logs.sh pod-002 → streams to main session       │
│     │       └── git commit + push when done                          │
│     │                                                                  │
│     └──► Subagent N: "Implement T00N" (parallel)                   │
│             ├── spawn-pod.sh T00N branch-async                       │
│             ├── tail-logs.sh pod-00N → streams to main session       │
│             └── git commit + push when done                          │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         K8s CLUSTER                                    │
│                                                                         │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│   │ Pod 1        │  │ Pod 2        │  │ Pod N        │             │
│   │ opencode run │  │ opencode run │  │ opencode run │             │
│   │ + spec/plan │  │ + spec/plan  │  │ + spec/plan  │             │
│   └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                         │
│   Each pod: git clone → implement → git push → done                   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Git-Based Communication

| Step | Action |
|------|--------|
| 1 | Developer creates branch: `specs/feature-001/task-001-xxx-async` |
| 2 | Orchestrator detects [ASYNC] task |
| 3 | Pod starts: `git clone -b <branch>` |
| 4 | Agent works autonomously |
| 5 | Agent: `git add . && git commit && git push` |
| 6 | Completion detected via log output |

---

## 3. Components

### 3.1 Deployment

| Component | Purpose | Location |
|-----------|---------|----------|
| Helm Chart | K8s resources templating | `charts/agentic-sdlc-orchestrator/` |
| Release (Dev) | Dev environment values | `releases/agentic-sdlc-orchestrator-dev/` |
| Release (Stg) | Staging environment values | `releases/agentic-sdlc-orchestrator-stg/` |
| Release (Prod) | Production environment values | `releases/agentic-sdlc-orchestrator-prod/` |

### 3.2 K8s Manifests (Helm Templates)

| File | Purpose |
|------|---------|
| `templates/namespace.yaml` | Create namespace for agents |
| `templates/rbac.yaml` | ServiceAccount and roles |
| `templates/configmap.yaml` | Shared configuration (non-sensitive) |
| `templates/external-secret.yaml` | External Secrets Operator integration |
| `templates/pod-template.yaml` | Agent pod template |
| `templates/_helpers.tpl` | Helm helper templates |

### 3.3 Docker

| File | Purpose |
|------|---------|
| `docker/Dockerfile.opencode` | Container image with OpenCode + git |

---

## 4. Technical Design

### 4.1 Helm Deployment

Deploy the orchestrator using Helm:

```bash
# Development
helm upgrade --install agentic-sdlc-orchestrator-dev \
  releases/agentic-sdlc-orchestrator-dev \
  -n agent-orchestrator-dev --create-namespace

# Staging
helm upgrade --install agentic-sdlc-orchestrator-stg \
  releases/agentic-sdlc-orchestrator-stg \
  -n agent-orchestrator-stg --create-namespace

# Production
helm upgrade --install agentic-sdlc-orchestrator-prod \
  releases/agentic-sdlc-orchestrator-prod \
  -n agent-orchestrator-prod --create-namespace
```

Spawn a task pod using kubectl (after Helm deployment):

```bash
#!/bin/bash
# Creates a K8s pod for an [ASYNC] task

set -e

usage() {
    echo "Usage: $0 <task-id> <branch-name> <repo-url> <context-dir>"
    exit 1
}

[ $# -lt 4 ] && usage

TASK_ID="$1"
BRANCH="$2"
REPO="$3"
CONTEXT_DIR="$4"

NAMESPACE="${NAMESPACE:-agent-orchestrator}"

# Create pod using Helm-rendered template
helm template agentic-sdlc-orchestrator charts/agentic-sdlc-orchestrator \
  --set task.id="$TASK_ID" \
  --set task.branch="$BRANCH" \
  --set task.repo="$REPO" \
  --set task.contextDir="$CONTEXT_DIR" | kubectl apply -f -

echo "Pod agent-${TASK_ID} created in namespace ${NAMESPACE}"
```

### 4.2 Log Streaming

Stream logs from a K8s pod using kubectl:

```bash
#!/bin/bash
# Tails logs from a K8s pod to stdout

NAMESPACE="${NAMESPACE:-agent-orchestrator}"
POD_NAME="$1"

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <pod-name>"
    exit 1
fi

kubectl logs -f -n "$NAMESPACE" "$POD_NAME"
```

### 4.3 Pod Template (Helm)

See `templates/pod-template.yaml` for the full pod spec template. Key features:

```yaml
{{- define "agentic-sdlc-orchestrator.podTemplate" -}}
restartPolicy: Never
serviceAccountName: {{ include "agentic-sdlc-orchestrator.serviceAccountName" . }}
containers:
  - name: agent
    image: "{{ .Values.pod.image.repository }}:{{ include "agentic-sdlc-orchestrator.imageTag" . }}"
    env:
      - name: OPENCODE_SERVER_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ include "agentic-sdlc-orchestrator.externalSecretName" . }}
            key: server-password
      - name: GIT_REPO
        value: "{{ .Values.task.defaultRepo }}"
      - name: GIT_BRANCH
        value: "{{ .Values.task.defaultBranch }}"
    resources:
      {{- toYaml .Values.pod.resources | nindent 6 }}
{{- end }}
```

---

## 5. Integration with Spec-Kit

### 5.1 Flow

```
spec-kit                           Our Implementation
─────────                          ──────────────────
spec.md ──────► /plan ──────────► tasks.md
    │                               │
    │                               ├── [SYNC] tasks → Human does locally
    │                               │
    │                               └── [ASYNC] tasks → Spawns subagent
    │                                              │
    │                                              ├── spawn-pod.sh
    │                                              ├── tail-logs.sh
    │                                              └── completion detection
```

### 5.2 Integration Point

The integration happens at `/implement` command:
- Parse tasks.md for [ASYNC] markers
- For each [ASYNC] task, spawn an OpenCode subagent
- Subagent creates K8s pod via Helm or kubectl

### 5.3 Context Delivery

Each pod receives:
- Git branch (from tasks.md)
- Repository URL (from git remote)
- Context files (spec.md, plan.md) via git clone

---

## 6. K8s Resources (Helm Templates)

### 6.1 Namespace

See `templates/namespace.yaml`:
```yaml
{{- if .Values.namespace.create }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ include "agentic-sdlc-orchestrator.namespace" . }}
  labels:
    {{- include "agentic-sdlc-orchestrator.labels" . | nindent 4 }}
{{- end }}
```

### 6.2 RBAC

See `templates/rbac.yaml` and `templates/serviceaccount.yaml`:
- ServiceAccount with optional Workload Identity annotations
- Role with pod management permissions
- RoleBinding

### 6.3 External Secrets

See `templates/external-secret.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "agentic-sdlc-orchestrator.externalSecretName" . }}
spec:
  refreshInterval: {{ .Values.externalSecret.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecret.secretStore.name }}
    kind: {{ .Values.externalSecret.secretStore.kind }}
  target:
    name: {{ include "agentic-sdlc-orchestrator.externalSecretName" . }}
  data:
    - secretKey: server-password
      remoteRef:
        key: {{ .Values.externalSecret.remoteRef.key }}
```

**Security Note**: Secrets are managed via External Secrets Operator, not hardcoded in ConfigMap.

---

## 7. Docker

### 7.1 Dockerfile.opencode

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://opencode.ai/install.sh | bash

RUN mkdir -p /workspace

WORKDIR /workspace

CMD ["/bin/bash"]
```

---

## 8. Directory Structure

```
agentic-sdlc-orchestrator/
├── SPEC.md                      # This file
├── PRD.md                       # Product requirements
├── docker/
│   └── Dockerfile.opencode       # OpenCode container image
├── charts/
│   └── agentic-sdlc-orchestrator/  # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── README.md
│       └── templates/
│           ├── _helpers.tpl     # Template helpers
│           ├── namespace.yaml
│           ├── serviceaccount.yaml
│           ├── rbac.yaml
│           ├── configmap.yaml   # Non-sensitive config only
│           ├── external-secret.yaml
│           └── pod-template.yaml
├── releases/
│   ├── agentic-sdlc-orchestrator-dev/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── argocd.yaml          # GitOps config
│   ├── agentic-sdlc-orchestrator-stg/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── argocd.yaml
│   └── agentic-sdlc-orchestrator-prod/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── argocd.yaml
└── scripts/
    # (reserved for future use)
```

---

## 9. Open Questions

1. **Git credentials**: How does the pod authenticate to git? (SSH key, token, or workload identity?)
2. **Completion detection**: Webhook or log parsing? (Log parsing preferred)
3. **Timeout**: How long should a pod run before being killed?
4. **Cleanup**: Auto-delete pods after completion?

---

## 10. Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Kubernetes | 1.25+ | Container orchestration |
| OpenCode | latest | AI coding agent |
| Git | any | Version control |
| kubectl | latest | K8s CLI |

---

## 11. Acceptance Criteria

- [ ] Helm chart deploys successfully to dev/stg/prod environments
- [ ] External Secrets Operator integrates with secret store
- [ ] Pod clones git branch and runs opencode
- [ ] `kubectl logs` streams logs to stdout
- [ ] Agent can commit and push changes
- [ ] Integration with spec-kit /implement works
- [ ] Multiple [ASYNC] tasks run in parallel
- [ ] Human can see all agent activity from main session
- [ ] ArgoCD GitOps deployment works correctly
