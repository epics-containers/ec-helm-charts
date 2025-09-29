{{- define "ioc-instance.service" -}}

{{/*
  Use with to access ioc-instance key.
  Required because .ioc-instance is illegal because of the hyphen.
*/}}
{{ with get .Values "ioc-instance" }}

# when not using hostNetwork, create a service to give the IOC a fixed cluster IP
# TODO - we could introduce this service to hostNetwork IOCs too: for review.
{{- if not .hostNetwork }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $.Release.Name }}
  labels:
    app: {{ $.Release.Name }}
    location: {{ $.Values.global.location }}
    domain: {{ $.Values.global.domain }}
    is_ioc: "true"
spec:
  selector:
    app: {{ $.Release.Name }}
  type: ClusterIP
  {{- $alloc_args := dict "name" $.Release.Name "namespace" $.Release.Namespace "baseIp" .baseIp "startIp" .startIp }}
  clusterIP: {{ .clusterIP | default (include "allocateIpFromName" $alloc_args) }}
  ports:
    - name: ca-server-tcp
      port: {{ .ca_server_port | default 5064 }}
      targetPort: {{ .ca_server_port | default 5064 }}
      protocol: TCP
    - name: ca-server-udp
      port: {{ .ca_server_port | default 5064 }}
      targetPort: {{ .ca_server_port | default 5064 }}
      protocol: UDP
    - name: ca-repeater-tcp
      port: {{ add1 (.caServerPort | default 5064) }}
      targetPort: {{ add1 (.caServerPort | default 5064) }}
      protocol: TCP
    - name: ca-repeater-udp
      port: {{ add1 (.caServerPort | default 5064) }}
      targetPort: {{ add1 (.caServerPort | default 5064) }}
      protocol: UDP
    - name: pva-server-tcp
      port: {{ .pva_server_port | default 5075 }}
      targetPort: {{ .pva_server_port | default 5075 }}
      protocol: TCP
    - name: pva-server-udp
      port: {{ .pva_server_port | default 5075 }}
      targetPort: {{ .pva_server_port | default 5075 }}
      protocol: UDP
    - name: pva-broadcast-tcp
      port: {{ add1 (.pvaServerPort | default 5075) }}
      targetPort: {{ add1 (.pvaServerPort | default 5075) }}
      protocol: TCP
    - name: pva-broadcast-udp
      port: {{ add1 (.pvaServerPort | default 5075) }}
      targetPort: {{ add1 (.pvaServerPort | default 5075) }}
      protocol: UDP
{{- end }} {{/* end if not .hostNetwork */}}

{{- end -}} {{/* end with .ioc-instance */}}
{{- end -}} {{/* end define "statefulset" */}}
