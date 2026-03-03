{{/*
Expand the name of the chart.
*/}}
{{- define "agentic-sdlc-runner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "agentic-sdlc-runner.fullname" -}}
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
{{- define "agentic-sdlc-runner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "agentic-sdlc-runner.labels" -}}
helm.sh/chart: {{ include "agentic-sdlc-runner.chart" . }}
{{ include "agentic-sdlc-runner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "agentic-sdlc-runner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agentic-sdlc-runner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "agentic-sdlc-runner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "agentic-sdlc-runner.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the namespace name
*/}}
{{- define "agentic-sdlc-runner.namespace" -}}
{{- if .Values.namespace.name }}
{{- .Values.namespace.name }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the external secret name
*/}}
{{- define "agentic-sdlc-runner.externalSecretName" -}}
{{- if .Values.externalSecret.name }}
{{- .Values.externalSecret.name }}
{{- else }}
{{- printf "%s-server-password" (include "agentic-sdlc-runner.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the configmap name
*/}}
{{- define "agentic-sdlc-runner.configMapName" -}}
{{- printf "%s-config" (include "agentic-sdlc-runner.fullname" .) }}
{{- end }}

{{/*
Get the image tag
*/}}
{{- define "agentic-sdlc-runner.imageTag" -}}
{{- if .Values.pod.image.tag }}
{{- .Values.pod.image.tag }}
{{- else }}
{{- .Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "agentic-sdlc-runner.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
{{- toYaml .Values.global.imagePullSecrets }}
{{- end }}
{{- end }}
