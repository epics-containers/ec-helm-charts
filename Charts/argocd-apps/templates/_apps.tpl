{{- define "ec-helm-charts.argocd-apps" -}}
{{- $currentScope := . -}}
{{- range $service, $settings := .Values.services }}
{{- /* Make sure settings is an empty dict if it is currently nil */ -}}
{{ $settings := default dict $settings -}}
{{ if ne $settings.removed true }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $service }}
  namespace: {{ $currentScope.Release.Namespace }}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{ default $currentScope.Release.Namespace $currentScope.Values.project }}
  destination:
    namespace: {{ $currentScope.Values.destination.namespace }}
    name: {{ $currentScope.Values.destination.name }}
  source:
    repoURL: {{ default $currentScope.Values.source.repoURL $settings.repoURL }}
    path: services/{{ $service }}
    targetRevision: {{ default $currentScope.Values.source.targetRevision $settings.targetRevision }}
    helm:
      version: v3
      valueFiles:
        - ../values.yaml
        - values.yaml
      parameters:
        - name: global.enabled
          value: {{ eq $settings.enabled false | ternary false true | quote }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      # don't restart pods unless there has been a change
      - ApplyOutOfSyncOnly=true
      - RespectIgnoreDifferences=true
---
{{ end }}
{{- end -}}
{{- end -}}