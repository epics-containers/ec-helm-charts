{{ define "ioc-instance" }}

{{- include "ioc-instance.configmap" . }}
---
{{ include "ioc-instance.statefulset" . }}
---
{{ include "ioc-instance.service" . }}

{{- end }}
