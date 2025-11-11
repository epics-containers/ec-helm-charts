{{- define "ioc-instance.configmap" -}}
{{- $_ := set .Values "configFolderConfigMap" (.Files.Glob "config/*").AsConfig -}}
{{- $_ := set .Values "configFolderHash" (.Values.configFolderConfigMap | sha1sum) -}}
{{ if ne .Values.configFolderConfigMap "{}" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name:  {{ .Release.Name }}-config
  labels:
    app: {{ .Release.Name }}
  annotations:
    argocd.argoproj.io/sync-options: Replace=true
# contents of the ioc instance config folder
data:
{{ .Values.configFolderConfigMap | indent 2 }}
{{ end -}}
{{- end -}}
