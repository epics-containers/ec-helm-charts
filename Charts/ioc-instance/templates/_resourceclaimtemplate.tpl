{{- /*
ResourceClaimTemplate generation for USB devices. Generates one ResourceClaimTemplate per entry in .usbDevices.
*/ -}}
{{- define "ioc-instance.resourceclaimtemplate" -}}

{{ with get .Values "ioc-instance" }}

{{- $usbKey := $.Values.global.usbKey | required "ERROR - You must supply global.usbKey when usbDevices are declared" -}}


{{- range $device := .usbDevices }}

{{- /* --- validate - must have name and at least one selector attribute --- */ -}}
{{- $attrKeys := list -}}
{{- range $key, $_ := $device -}}
  {{- if ne $key "name" -}}
    {{- $attrKeys = append $attrKeys $key -}}
  {{- end -}}
{{- end -}}
{{- if eq (len $attrKeys) 0 -}}
  {{- fail (printf "ERROR - usbDevices entry '%s' must have at least one selector attribute [vendor, product, serial, host, bus]" $device.name) -}}
{{- end }}
---
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: {{ $device.name }}
spec:
  spec:
    devices:
      requests:
      - name: req-0
        firstAvailable:
        - name: device-0
          deviceClassName: usbip
          allocationMode: ExactCount
          count: 1
          selectors:
            {{- range $key := ($attrKeys | sortAlpha) }}
            - cel:
                expression: "device.attributes[\"{{ $usbKey }}\"].{{ $key }} == \"{{ index $device $key }}\""
            {{- end }}
{{- end }}
{{- end }}
{{- end -}}
