{{- define "ec-helm-charts.argocd-apps" -}}
{{- range $service, $settings := list .Values.services }}
{{- /* Make sure settings is an empty dict if it is currently nil */ -}}
{{ $settings := default dict $settings -}}
{{ if ne $settings.removed true }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $service }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- if eq $settings.enabled false }}
    STOPPED: "1"
    {{- end }}
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
      parameters:
        - name: global.enabled
          value: {{ eq $settings.enabled false | ternary false true | quote }}
        # pass the synced commit hash as a global value
        - name: global.commitHash
          value: $ARGOCD_APP_REVISION_SHORT
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
