{{- define "ec-helm-charts.argocd-apps" -}}
{{- range $service, $settings := .Values.services }}
{{- /* Make sure settings is an empty dict if it is currently nil */ -}}
{{ $settings := default dict $settings -}}
{{ if ne $settings.removed true }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $service }}
  namespace: {{ $.Release.Namespace }}
  {{- with $settings.description }}
  annotations:
    epics-containers.github.io/description: {{ . | quote }}
  {{- end }}
  labels:
    {{- if eq $settings.enabled false }}
    STOPPED: "1"
    {{- end }}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{ default $.Release.Namespace $.Values.project }}
  {{- $settingsDestination := default dict $settings.destination }}
  destination:
    namespace: {{ default $.Values.destination.namespace $settingsDestination.namespace }}
    name: {{ default $.Values.destination.name $settingsDestination.name }}
  source:
    repoURL: {{ default $.Values.source.repoURL $settings.repoURL }}
    path: services/{{ default $service $settings.serviceChart }}
    targetRevision: {{ default $.Values.source.targetRevision $settings.targetRevision }}
    helm:
      version: v3
      parameters:
        - name: global.enabled
          value: {{ eq $settings.enabled false | ternary false true | quote }}
        # pass the synced commit hash as a global value
        - name: global.commitHash
          value: $ARGOCD_APP_REVISION_SHORT
        - name: global.sourceRepo
          value: $ARGOCD_APP_SOURCE_REPO_URL
        - name: global.sourcePath
          value: $ARGOCD_APP_SOURCE_PATH
      {{- /* Merge labels into valuesObject.global.labels. Rendering the two
             separately would emit two sibling global: keys and YAML would
             silently keep only the last. The dedicated labels key wins on a
             clash: it is the narrower, schema-validated setting, like a
             parameter overriding valuesObject. */ -}}
      {{- $valuesObject := deepCopy (default dict $settings.valuesObject) }}
      {{- with $settings.labels }}
      {{- $valuesObject = mergeOverwrite $valuesObject (dict "global" (dict "labels" .)) }}
      {{- end }}
      {{- with $valuesObject }}
      valuesObject:
      {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $settings.valuesFiles }}
      valueFiles:
      {{- toYaml . | nindent 8 }}
      {{- else }}
      valueFiles:
        - ../values.yaml
        - values.yaml
      {{- end }}
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
