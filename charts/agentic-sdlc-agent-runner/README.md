# Agentic SDLC Runner Helm Chart

This Helm chart deploys the Agentic SDLC Runner on Kubernetes.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- External Secrets Operator (for secret management)

## Installation

### Development Environment

```bash
cd releases/agentic-sdlc-agent-runner-dev
helm dependency update
helm upgrade --install agentic-sdlc-agent-runner-dev . -n agent-runner-dev --create-namespace
```

### Staging Environment

```bash
cd releases/agentic-sdlc-agent-runner-stg
helm dependency update
helm upgrade --install agentic-sdlc-agent-runner-stg . -n agent-runner-stg --create-namespace
```

### Production Environment

```bash
cd releases/agentic-sdlc-agent-runner-prod
helm dependency update
helm upgrade --install agentic-sdlc-agent-runner-prod . -n agent-runner-prod --create-namespace
```

## Configuration

See `values.yaml` for the full list of configurable parameters.

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Namespace for resources | Release namespace |
| `serviceAccount.annotations` | ServiceAccount annotations (for Workload Identity) | `{}` |
| `externalSecret.enabled` | Enable External Secrets Operator integration | `true` |
| `externalSecret.secretStore.name` | SecretStore name | `secret-store` |
| `pod.image.tag` | Image tag | `0.1.0` |
| `pod.resources` | Resource limits and requests | See values.yaml |

### External Secrets

This chart uses External Secrets Operator to manage sensitive data. You must configure:

1. A `ClusterSecretStore` or `SecretStore` in your cluster
2. The secret referenced in `externalSecret.remoteRef.key`

Example secret structure:
```
agentic-sdlc/prod/server-password
  - server-password: <your-password>
```

### GKE Workload Identity

To use GKE Workload Identity, annotate the service account:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: agent-runner@project-id.iam.gserviceaccount.com
```

## GitOps with ArgoCD

Each environment includes an `argocd.yaml` file for GitOps deployment.

Example ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: agentic-sdlc-agent-runner-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tikalk/agentic-sdlc-agent-runner.git
    targetRevision: main
    path: releases/agentic-sdlc-agent-runner-prod
  destination:
    server: https://kubernetes.default.svc
    namespace: agent-runner-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Migration from Legacy k8s/ Directory

The legacy `k8s/` directory with flat YAML files is deprecated. Use Helm for all new deployments.

Key differences:
- **Secrets**: Moved from hardcoded ConfigMap to External Secrets Operator
- **Templating**: Moved from bash `sed` to Helm templates
- **Multi-environment**: Use separate releases in `releases/` directory
- **GitOps**: Use ArgoCD Application manifests

## Uninstallation

```bash
helm uninstall agentic-sdlc-agent-runner-dev -n agent-runner-dev
helm uninstall agentic-sdlc-agent-runner-stg -n agent-runner-stg
helm uninstall agentic-sdlc-agent-runner-prod -n agent-runner-prod
```
