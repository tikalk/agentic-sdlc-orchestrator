{{/*
Expand the name of the chart.
*/}}
{{- define "agentic-sdlc-orchestrator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "agentic-sdlc-orchestrator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "agentic-sdlc-orchestrator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "agentic-sdlc-orchestrator.labels" -}}
helm.sh/chart: {{ include "agentic-sdlc-orchestrator.chart" . }}
{{ include "agentic-sdlc-orchestrator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "agentic-sdlc-orchestrator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agentic-sdlc-orchestrator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "agentic-sdlc-orchestrator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "agentic-sdlc-orchestrator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the namespace name
*/}}
{{- define "agentic-sdlc-orchestrator.namespace" -}}
{{- if .Values.namespace.name }}
{{- .Values.namespace.name }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the external secret name
*/}}
{{- define "agentic-sdlc-orchestrator.externalSecretName" -}}
{{- if .Values.externalSecret.name }}
{{- .Values.externalSecret.name }}
{{- else }}
{{- printf "%s-server-password" (include "agentic-sdlc-orchestrator.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the configmap name
*/}}
{{- define "agentic-sdlc-orchestrator.configMapName" -}}
{{- printf "%s-config" (include "agentic-sdlc-orchestrator.fullname" .) }}
{{- end }}

{{/*
Get the image tag
*/}}
{{- define "agentic-sdlc-orchestrator.imageTag" -}}
{{- if .Values.pod.image.tag }}
{{- .Values.pod.image.tag }}
{{- else }}
{{- .Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "agentic-sdlc-orchestrator.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
{{- toYaml .Values.global.imagePullSecrets }}
{{- end }}
{{- end }}
