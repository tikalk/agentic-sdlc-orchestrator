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

### 3.1 Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `spawn-pod.sh` | Creates K8s pod for a task | `scripts/k8s/` |
| `tail-logs.sh` | Streams pod logs to stdout | `scripts/k8s/` |
| `k8s-init.sh` | Initialize K8s resources | `scripts/k8s/` |

### 3.2 K8s Manifests

| File | Purpose |
|------|---------|
| `k8s/namespace.yaml` | Create namespace for agents |
| `k8s/rbac.yaml` | ServiceAccount and roles |
| `k8s/configmap.yaml` | Shared configuration |
| `k8s/pod-template.yaml` | Agent pod template |

### 3.3 Docker

| File | Purpose |
|------|---------|
| `docker/Dockerfile.opencode` | Container image with OpenCode + git |

---

## 4. Technical Design

### 4.1 spawn-pod.sh

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

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: agent-${TASK_ID}
  labels:
    app: agent-orchestrator
    task-id: ${TASK_ID}
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
          value: "${REPO}"
        - name: GIT_BRANCH
          value: "${BRANCH}"
        - name: TASK_CONTEXT_PATH
          value: "${CONTEXT_DIR}"
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          cd /workspace
          git clone -b ${BRANCH} ${REPO} .
          ls -la
          opencode run "Implement the task described in $(ls *.md | head -1)"
          git add .
          git commit -m "feat: completed ${TASK_ID}" || true
          git push
      resources:
        limits:
          cpu: "2"
          memory: "4Gi"
  serviceAccountName: agent-orchestrator
EOF

echo "Pod agent-${TASK_ID} created in namespace ${NAMESPACE}"
```

### 4.2 tail-logs.sh

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

### 4.3 Pod Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: agent-{task-id}
  labels:
    app: agent-orchestrator
    task-id: {task-id}
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
          value: "{repo-url}"
        - name: GIT_BRANCH
          value: "{branch-name}"
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          cd /workspace
          git clone -b {branch-name} {repo-url} .
          opencode run "Implement the task"
          git add .
          git commit -m "feat: completed {task-id}" || true
          git push
  serviceAccountName: agent-orchestrator
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
- Subagent runs spawn-pod.sh + tail-logs.sh

### 5.3 Context Delivery

Each pod receives:
- Git branch (from tasks.md)
- Repository URL (from git remote)
- Context files (spec.md, plan.md) via git clone

---

## 6. K8s Resources

### 6.1 Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: agent-orchestrator
```

### 6.2 RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: agent-orchestrator
  namespace: agent-orchestrator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: agent-orchestrator
  namespace: agent-orchestrator
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: agent-orchestrator
  namespace: agent-orchestrator
subjects:
  - kind: ServiceAccount
    name: agent-orchestrator
roleRef:
  kind: Role
  name: agent-orchestrator
  apiGroup: rbac.authorization.k8s.io
```

### 6.3 ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-orchestrator-config
  namespace: agent-orchestrator
data:
  server-password: "changeme"
```

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
├── k8s/
│   ├── namespace.yaml           # Namespace
│   ├── rbac.yaml               # ServiceAccount, Role, RoleBinding
│   ├── configmap.yaml          # Shared config
│   └── pod-template.yaml        # Agent pod template
└── scripts/
    └── k8s/
        ├── k8s-init.sh         # Initialize K8s resources
        ├── spawn-pod.sh        # Create pod for task
        └── tail-logs.sh        # Stream pod logs
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

- [ ] spawn-pod.sh creates a pod successfully
- [ ] Pod clones git branch and runs opencode
- [ ] tail-logs.sh streams logs to stdout
- [ ] Agent can commit and push changes
- [ ] Integration with spec-kit /implement works
- [ ] Multiple [ASYNC] tasks run in parallel
- [ ] Human can see all agent activity from main session
