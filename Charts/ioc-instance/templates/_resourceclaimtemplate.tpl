{{- /*
ResourceClaimTemplate generation for USB devices. Generates one request per entry in .usbDevices.
*/ -}}
{{- define "ioc-instance.resourceclaimtemplate" -}}

{{ with get .Values "ioc-instance" }}
{{- if .usbDevices }}

{{- $usbKey := $.Values.global.usbKey | required "ERROR - You must supply global.usbKey when usbDevices are declared" -}}

apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: {{ $.Release.Name }}
spec:
  spec:
    devices:
      requests:
        {{- range $device := .usbDevices }}
        {{- range $deviceName, $attrs := $device }}
        {{- $attrKeys := keys $attrs | sortAlpha }}
        - name: {{ $deviceName }}
          exactly:
            deviceClassName: usbip
            allocationMode: ExactCount
            count: 1
            selectors:
              {{- range $key := $attrKeys }}
              - cel:
                  expression: "device.attributes[\"{{ $usbKey }}\"].{{ $key }} == \"{{ index $attrs $key }}\""
              {{- end }}
        {{- end }} {{/* end range $device := .usbDevices */}}
        {{- end }} {{/* end range $deviceName, $attrs := $device */}}

{{- end }} {{/* end if .usbDevices */}}
{{- end }} {{/* end with .ioc-instance */}}
{{- end }} {{/* end define ioc-instance.resourceclaimtemplate */}}
