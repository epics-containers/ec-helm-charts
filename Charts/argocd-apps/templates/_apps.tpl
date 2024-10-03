{{- define "ec-helm-charts.argocd-apps" -}}
{{- range $index, $services := list .Values.ec_services .Values.services }}
{{- range $service, $settings := $services }}
{{- /* Make sure settings is an empty dict if it is currently nil */ -}}
{{ $settings := default dict $settings -}}
{{ if ne $settings.removed true }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $service }}
  namespace: {{ $.Release.Namespace }}
  labels:
    ec_service: {{ eq $index 0 | ternary true false | quote }}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{ default $.Release.Namespace $.Values.project }}
  destination:
    namespace: {{ $.Values.destination.namespace }}
    name: {{ $.Values.destination.name }}
  source:
    repoURL: {{ default $.Values.source.repoURL $settings.repoURL }}
    path: services/{{ $service }}
    targetRevision: {{ default $.Values.source.targetRevision $settings.targetRevision }}
    helm:
      version: v3
      {{- if eq $index 0 }}
      parameters:
        - name: global.enabled
          value: {{ eq $settings.enabled false | ternary false true | quote }}
      {{- end }}
      valueFiles:
        - ../values.yaml
        - values.yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      # don't restart pods unless there has been a change
      - ApplyOutOfSyncOnly=true
      - RespectIgnoreDifferences=true
---
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
