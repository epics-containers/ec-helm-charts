{{- define "iocInstance" -}}

{{- include "iocInstance.configmap" . }}
---
{{- include "iocInstance.statefulset" . }}
---
{{- include "iocInstance.service" . }}

{{- end -}}
