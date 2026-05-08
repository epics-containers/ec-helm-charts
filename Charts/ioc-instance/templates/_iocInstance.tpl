{{ define "ioc-instance" }}

{{- include "ioc-instance.configmap" . }}
---
{{ include "ioc-instance.statefulset" . }}
---
{{ include "ioc-instance.service" . }}
---
{{ include "ioc-instance.datavolume" . }}

{{- with get .Values "ioc-instance" }}
{{- if .usbDevices }}
{{ include "ioc-instance.resourceclaimtemplate" $ }}
{{- end }}
{{- end }}

{{- end }}
