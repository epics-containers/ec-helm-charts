{{ define "ioc-instance.datavolume" }}

{{ with get .Values "ioc-instance" }}

{{- $location := default $.Values.global.location .location | required "ERROR - You must supply location or global.location" -}}
{{- $domain := default $.Values.global.domain .domain | required "ERROR - You must supply domain or global.domain" -}}

{{- if .dataVolume.pvc }}
# This IOC uses a data volume, so we will create a PVC for it
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ $.Release.Name }}-data
  labels:
    app: {{ $.Release.Name }}
    location: {{ $location }}
    domain: {{ $domain }}
    ioc: "true"
spec:
{{- if .dataVolume.spec }}
  {{- toYaml .dataVolume.spec | nindent 2 }}
{{ else }}
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1000Mi
{{- end }}
{{ else }}
# This IOC has no data volume, so we will mount the host filesystem
{{- end }}  {{/* end if .dataVolume.pvc */}}
{{- end }}  {{/* end with get .Values "ioc-instance" */}}
{{- end }}  {{/* end define ioc-instance.datavolume */}}
