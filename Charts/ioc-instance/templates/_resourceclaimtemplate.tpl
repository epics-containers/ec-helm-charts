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
        {{- if not $device.name -}}
          {{- fail "ERROR - each usbDevices entry must have a 'name' field" -}}
        {{- end -}}
        {{- $attrKeys := without (keys $device | sortAlpha) "name" -}}
        {{- if eq (len $attrKeys) 0 -}}
          {{- fail (printf "ERROR - usbDevices entry '%s' must have at least one selector attribute [vendor, product, serial, host, bus]" $device.name) -}}
        {{- end }}
        - name: {{ $device.name }}
          exactly:
            deviceClassName: usbip
            allocationMode: ExactCount
            count: 1
            selectors:
              {{- range $key := $attrKeys }}
              - cel:
                  expression: "device.attributes[\"{{ $usbKey }}\"].{{ $key }} == \"{{ index $device $key }}\""
              {{- end }} {{/* end range $key := $attrKeys */}}
        {{- end }} {{/* end range $device := .usbDevices */}}
        
{{- end }} {{/* end if .usbDevices */}}
{{- end }} {{/* end with .ioc-instance */}}
{{- end }} {{/* end define ioc-instance.resourceclaimtemplate */}}
