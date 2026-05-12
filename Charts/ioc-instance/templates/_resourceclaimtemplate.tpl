{{- /*
ResourceClaimTemplate generation for USB devices. Generates one ResourceClaimTemplate per entry in .usbDevices.
*/ -}}
{{- define "ioc-instance.resourceclaimtemplate" -}}

{{ with get .Values "ioc-instance" }}

{{- $usbKey := $.Values.global.usbKey | required "ERROR - You must supply global.usbKey when usbDevices are declared" -}}

{{- range $i, $device := .usbDevices }}

{{- $attrKeys := keys $device | sortAlpha }}
---
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: {{ $.Release.Name }}-usb-{{ printf "%02d" (add1 $i) }}
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
