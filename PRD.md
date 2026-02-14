# PRD.md - K8s Agent Orchestration via OpenCode Subagents

**Project Name**: Agentic SDLC Orchestrator  
**Version**: 1.0.0  
**Date**: 2026-02-14

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

### Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NF1 | **Simplicity**: No external orchestrator, just scripts | Must |
| NF2 | **Visibility**: All agent activity visible from main CLI | Must |
| NF3 | **Integrability**: Works with existing spec-kit workflow | Must |
| NF4 | **Autonomy**: Agents work without human intervention | Must |

---

## 4. Requirements

### Must Have

1. `spawn-pod.sh` script - Creates K8s pod for a task
2. `tail-logs.sh` script - Streams pod logs to stdout
3. K8s manifests - namespace, RBAC, configmap
4. OpenCode Docker image
5. Integration with spec-kit

### Should Have

1. Auto-cleanup of completed pods
2. Timeout handling
3. Error reporting to main session

### Out of Scope

1. External orchestrator/controller
2. K-Agent framework integration
3. Beads issue tracking
4. Web dashboard
5. Mayor pattern (Gastown)

---

## 5. Architecture

### Pattern: Subagent-Based Orchestration

```
Main Session → Subagent → spawn-pod.sh → K8s Pod
                    ↓
              tail-logs.sh → streams to main
                    ↓
              git commit/push → completion
```

### Why This Pattern?

- **Simple**: No complex controller needed
- **Native**: Uses OpenCode's built-in subagent capability
- **Visible**: All activity streams to main session
- **Git-based**: No separate state management

### Alternative Approaches Considered

| Approach | Why Not Chosen |
|----------|----------------|
| External K8s controller | Overkill for our use case |
| K-Agent framework | Too complex, not needed |
| Gastown Mayor | We have structured workflow via spec-kit |
| Beads issue tracking | Git-branch pattern solves same problems |

---

## 6. Timeline

### Phase 1: Core (Week 1)

| Task | Description |
|------|-------------|
| T1.1 | Create spawn-pod.sh script |
| T1.2 | Create tail-logs.sh script |
| T1.3 | Create K8s manifests (namespace, RBAC, configmap) |
| T1.4 | Test pod creation manually |

**Milestone**: Can create pod and see logs

### Phase 2: Integration (Week 2)

| Task | Description |
|------|-------------|
| T2.1 | Build OpenCode Docker image |
| T2.2 | Test git clone + opencode run in pod |
| T2.3 | Test git commit + push from pod |
| T2.4 | Integrate with spec-kit /implement |

**Milestone**: End-to-end autonomous execution works

### Phase 3: Polish (Week 3)

| Task | Description |
|------|-------------|
| T3.1 | Error handling and reporting |
| T3.2 | Cleanup logic for completed pods |
| T3.3 | Documentation |
| T3.4 | User testing |

**Milestone**: Production-ready

---

## 7. Open Questions

### Q1: Git Authentication

**Options**:
- SSH key (mounted as secret)
- Git token (in environment variable)
- Workload identity (GKE/EKS specific)

**Decision needed**: Which auth method?

### Q2: Completion Detection

**Options**:
- Log parsing (detect "git push" in logs)
- Git webhook (external service)
- Polling (check pod status)

**Decision needed**: How to detect task completion?

### Q3: Pod Timeout

**Options**:
- No timeout (run until done)
- Fixed timeout (e.g., 2 hours)
- Configurable timeout

**Decision needed**: Timeout policy?

### Q4: Cleanup Policy

**Options**:
- Always delete after completion
- Keep for debugging
- Configurable

**Decision needed**: Cleanup strategy?

---

## 8. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
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

---

## 10. Appendix

### Related Documents

- [SPEC.md](./SPEC.md) - Technical specification
- [agentic-sdlc-spec-kit](https://github.com/github/agentic-sdlc-spec-kit) - Spec-driven development toolkit
- [agentic-sdlc-team-ai-directives](https://github.com/github/agentic-sdlc-team-ai-directives) - Team AI directives

### Terminology

| Term | Definition |
|------|------------|
| [ASYNC] task | Task that can be delegated to autonomous agent |
| [SYNC] task | Task requiring human interaction |
| Subagent | OpenCode's built-in agent spawning capability |
| Worktree | Git working tree for isolated work |
