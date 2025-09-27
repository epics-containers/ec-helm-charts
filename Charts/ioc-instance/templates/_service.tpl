{{- define "ioc-instance.service" -}}

{{/* Use with, set to move the iocInstance namespace to the root namespace. */}}
{{ with .Values.iocInstance }}
{{- $_ := set . "Values" . -}}

# when not using hostNetwork, create a service to give the IOC a fixed cluster IP
# TODO - we could introduce this service to hostNetwork IOCs too: for review.
{{- if not .Values.hostNetwork }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $.Release.Name }}
  labels:
    app: {{ $.Release.Name }}
    location: {{ $.Values.global.location }}
    ioc_group: {{ $.Values.global.ioc_group }}
    is_ioc: "true"
spec:
  selector:
    app: {{ $.Release.Name }}
  type: ClusterIP
  {{- $alloc_args := dict "name" $.Release.Name "namespace" $.Release.Namespace "baseIp" .Values.baseIp "startIp" .Values.startIp }}
  clusterIP: {{ .Values.clusterIP | default (include "allocateIpFromName" $alloc_args) }}
  ports:
    - name: ca-server-tcp
      port: {{ .Values.ca_server_port | default 5064 }}
      targetPort: {{ .Values.ca_server_port | default 5064 }}
      protocol: TCP
    - name: ca-server-udp
      port: {{ .Values.ca_server_port | default 5064 }}
      targetPort: {{ .Values.ca_server_port | default 5064 }}
      protocol: UDP
    - name: ca-repeater-tcp
      port: {{ add1 (.Values.ca_server_port | default 5064) }}
      targetPort: {{ add1 (.Values.ca_server_port | default 5064) }}
      protocol: TCP
    - name: ca-repeater-udp
      port: {{ add1 (.Values.ca_server_port | default 5064) }}
      targetPort: {{ add1 (.Values.ca_server_port | default 5064) }}
      protocol: UDP
    - name: pva-server-tcp
      port: {{ .Values.pva_server_port | default 5075 }}
      targetPort: {{ .Values.pva_server_port | default 5075 }}
      protocol: TCP
    - name: pva-server-udp
      port: {{ .Values.pva_server_port | default 5075 }}
      targetPort: {{ .Values.pva_server_port | default 5075 }}
      protocol: UDP
    - name: pva-broadcast-tcp
      port: {{ add1 (.Values.pva_server_port | default 5075) }}
      targetPort: {{ add1 (.Values.pva_server_port | default 5075) }}
      protocol: TCP
    - name: pva-broadcast-udp
      port: {{ add1 (.Values.pva_server_port | default 5075) }}
      targetPort: {{ add1 (.Values.pva_server_port | default 5075) }}
      protocol: UDP
{{- end }} {{/* end if not .Values.hostNetwork */}}

{{- end -}} {{/* end with .Values.iocInstance */}}
{{- end -}} {{/* end define "statefulset" */}}
