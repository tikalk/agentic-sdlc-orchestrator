# PRD.md - K8s Agent Orchestration via OpenCode Subagents

**Project Name**: Agentic SDLC Orchestrator  
**Version**: 1.1.0  
**Date**: 2026-02-15

---

## 1. Problem Statement

### The Challenge

Developers need to run AI coding agents on remote Kubernetes infrastructure while maintaining visibility and control from their local development environment.

### Current State

- OpenCode runs locally only
- No way to leverage remote compute for async tasks
- No visibility into remote agent progress

### Desired State

- Run [ASYNC] tasks in K8s pods
- See all agent activity from one CLI
- Autonomous execution with human oversight
- Secure, production-ready deployment

---

## 2. User Stories

### Story 1: Run Async Task in K8s

**As a** developer  
**I want** to run an [ASYNC] task in a Kubernetes pod  
**So that** I can leverage remote compute for well-defined tasks

**Acceptance Criteria**:
- Task from tasks.md spawns a K8s pod
- Pod runs opencode with task context
- Changes are committed and pushed

### Story 2: Visibility from Main Session

**As a** developer  
**I want** to see what all async agents are doing from my main OpenCode session  
**So that** I have full visibility without switching tools

**Acceptance Criteria**:
- Pod logs stream back to main session
- Human sees all agent activity in one place
- Can monitor multiple agents simultaneously

### Story 3: Parallel Execution

**As a** developer  
**I want** multiple [ASYNC] tasks to run in parallel  
**So that** I can speed up feature implementation

**Acceptance Criteria**:
- Multiple pods spawn for parallel [ASYNC] tasks
- All pods visible from main session
- Resources don't block each other

### Story 4: Git-Based Workflow

**As a** developer  
**I want** changes to be committed and pushed automatically  
**So that** my work is tracked and reviewable

**Acceptance Criteria**:
- Agent commits on completion
- Changes pushed to remote branch
- Human can review before merging

### Story 5: Secure Secret Management

**As a** security engineer  
**I want** secrets managed via External Secrets Operator  
**So that** there are no hardcoded credentials

**Acceptance Criteria**:
- No secrets in ConfigMaps or code
- Integration with External Secrets Operator
- Support for cloud secret managers (GCP, AWS, Azure)

---

## 3. Success Criteria

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F1 | Subagent spawns K8s pod for [ASYNC] task | Must |
| F2 | Pod logs stream back to main session | Must |
| F3 | Agent autonomously implements task | Must |
| F4 | Changes committed and pushed automatically | Must |
| F5 | Integration with spec-kit /implement command | Must |
| F6 | Parallel execution of multiple [ASYNC] tasks | Must |
| F7 | Helm-based deployment | Must |
| F8 | External Secrets Operator integration | Must |
| F9 | Multi-environment support (dev/stg/prod) | Must |

### Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NF1 | **Security**: No hardcoded secrets, ESO integration | Must |
| NF2 | **Visibility**: All agent activity visible from main CLI | Must |
| NF3 | **Integrability**: Works with existing spec-kit workflow | Must |
| NF4 | **Autonomy**: Agents work without human intervention | Must |
| NF5 | **GitOps**: ArgoCD deployment support | Should |
| NF6 | **Workload Identity**: GKE/EKS support | Should |

---

## 4. Requirements

### Must Have

1. **Helm Chart** - Standard Kubernetes deployment
   - Chart.yaml, values.yaml, templates/
   - _helpers.tpl for template functions
   - External Secrets integration
   - RBAC configuration

2. **Multi-Environment Releases** - Dev, staging, production
   - Separate values files per environment
   - ArgoCD Application manifests
   - Namespace isolation

3. **Helper Scripts** - Simplified pod management
   - `spawn-pod.sh` - Creates pods via Helm templates
   - `tail-logs.sh` - Streams pod logs
   - Environment-aware (dev/stg/prod)
   - SSH secret support

4. **OpenCode Docker image** - Container with OpenCode + git

5. **Integration with spec-kit** - Works with /implement command

### Should Have

1. Auto-cleanup of completed pods
2. Timeout handling
3. Error reporting to main session
4. GKE Workload Identity support

### Out of Scope

1. External orchestrator/controller
2. K-Agent framework integration
3. Beads issue tracking
4. Web dashboard
5. Mayor pattern (Gastown)

---

## 5. Architecture

### Pattern: Subagent-Based Orchestration with Helm

```
Main Session → Subagent → scripts/spawn-pod.sh → K8s Pod
                    ↓
              scripts/tail-logs.sh → streams to main
                    ↓
              git commit/push → completion
```

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Helm Chart                                │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│   │ Namespace    │  │ ServiceAccount│  │ RBAC         │          │
│   │              │  │ + Workload ID │  │ Role/Binding │          │
│   └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐                            │
│   │ ExternalSecret│  │ ConfigMap   │                            │
│   │ (password)    │  │ (config)    │                            │
│   └──────────────┘  └──────────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Agent Pods (dynamic)                         │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│   │ Pod: Task 1  │  │ Pod: Task 2  │  │ Pod: Task N  │          │
│   │ git clone    │  │ git clone    │  │ git clone    │          │
│   │ opencode run │  │ opencode run │  │ opencode run │          │
│   │ git push     │  │ git push     │  │ git push     │          │
│   └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Pattern?

- **Simple**: No complex controller needed, just Helm + kubectl
- **Native**: Uses OpenCode's built-in subagent capability
- **Visible**: All activity streams to main session
- **Git-based**: No separate state management
- **Secure**: External Secrets Operator manages credentials
- **Standard**: Follows ai-directives K8s standards

### Alternative Approaches Considered

| Approach | Why Not Chosen |
|----------|----------------|
| External K8s controller | Overkill for our use case |
| K-Agent framework | Too complex, not needed |
| Gastown Mayor | We have structured workflow via spec-kit |
| Beads issue tracking | Git-branch pattern solves same problems |
| Raw YAML manifests | Not scalable, replaced with Helm |

---

## 6. Timeline

### Phase 1: Foundation (Week 1)

| Task | Description |
|------|-------------|
| T1.1 | Create Helm chart structure |
| T1.2 | Create templates (namespace, RBAC, serviceaccount) |
| T1.3 | Create External Secret template |
| T1.4 | Test Helm deployment manually |

**Milestone**: Helm chart deploys successfully

### Phase 2: Integration (Week 2)

| Task | Description |
|------|-------------|
| T2.1 | Build OpenCode Docker image |
| T2.2 | Create pod template |
| T2.3 | Create multi-environment releases (dev/stg/prod) |
| T2.4 | Create helper scripts (spawn-pod.sh, tail-logs.sh) |
| T2.5 | Test pod creation via scripts and kubectl |

**Milestone**: Can create pod via scripts and see logs

### Phase 3: E2E & GitOps (Week 3)

| Task | Description |
|------|-------------|
| T3.1 | Test git clone + opencode run in pod |
| T3.2 | Test git commit + push from pod |
| T3.3 | Create ArgoCD Application manifests |
| T3.4 | Integrate with spec-kit /implement |

**Milestone**: End-to-end autonomous execution works

### Phase 4: Polish (Week 4)

| Task | Description |
|------|-------------|
| T4.1 | Error handling and reporting |
| T4.2 | Cleanup logic for completed pods |
| T4.3 | Documentation (README, SPEC, PRD) |
| T4.4 | User testing |

**Milestone**: Production-ready

---

## 7. Open Questions

### Q1: Git Authentication

**Options**:
- SSH key (mounted as secret)
- Git token (via External Secrets Operator)
- Workload identity (GKE/EKS specific)

**Decision**: Support all three via Helm values configuration

### Q2: Completion Detection

**Options**:
- Log parsing (detect "git push" in logs)
- Git webhook (external service)
- Polling (check pod status)

**Decision**: Log parsing for simplicity

### Q3: Pod Timeout

**Options**:
- No timeout (run until done)
- Fixed timeout (e.g., 2 hours)
- Configurable timeout

**Decision**: Configurable via Helm values, default 2 hours

### Q4: Cleanup Policy

**Options**:
- Always delete after completion
- Keep for debugging
- Configurable

**Decision**: Configurable via Helm values

### Q5: Secret Store Provider

**Options**:
- GCP Secret Manager
- AWS Secrets Manager
- Azure Key Vault
- HashiCorp Vault

**Decision**: Generic External Secrets Operator, user configures provider

---

## 8. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| External Secrets Operator not installed | High | Document prerequisite |
| Pod fails to clone repo | High | Test git credentials early |
| OpenCode run fails in pod | Medium | Proper error logging |
| Pod hangs indefinitely | Medium | Implement timeout |
| Git push conflicts | Low | Each task has own branch |

---

## 9. Success Metrics

| Metric | Target |
|--------|--------|
| Pod creation success rate | >95% |
| Task completion rate | >90% |
| Time from spawn to completion | <2 hours average |
| Human visibility | 100% of agent activity visible |
| Security audit pass | No hardcoded secrets |

---

## 10. Appendix

### Related Documents

- [SPEC.md](./SPEC.md) - Technical specification
- [README.md](./README.md) - User documentation
- [agentic-sdlc-spec-kit](https://github.com/tikalk/agentic-sdlc-spec-kit) - Spec-driven development toolkit
- [agentic-sdlc-team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives) - Team AI directives

### Terminology

| Term | Definition |
|------|------------|
| [ASYNC] task | Task that can be delegated to autonomous agent |
| [SYNC] task | Task requiring human interaction |
| Subagent | OpenCode's built-in agent spawning capability |
| ESO | External Secrets Operator |
| Workload Identity | Cloud-native identity for K8s workloads |
| GitOps | Declarative continuous deployment using git |

### Deployment Commands

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
