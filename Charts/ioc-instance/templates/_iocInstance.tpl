{{ define "iocInstance" }}

{{- include "iocInstance.configmap" . }}
---
{{ include "ioc-instance.statefulset" . }}
---
{{ include "ioc-instance.service" . }}

{{- end }}
