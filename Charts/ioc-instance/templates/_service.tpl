{{- define "iocInstance.service" -}}
# when not using hostNetwork, create a service to give the IOC a fixed cluster IP
# TODO - we could introduce this service to hostNetwork IOCs too: for review.
{{- if not .Values.iocInstance.hostNetwork }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
    location: {{ .Values.global.location }}
    ioc_group: {{ .Values.global.ioc_group }}
    is_ioc: "true"
spec:
  selector:
    app: {{ .Release.Name }}
  type: ClusterIP
  {{- $alloc_args := dict "name" .Release.Name "namespace" .Release.Namespace "baseIp" .Values.iocInstance.baseIp "startIp" .Values.iocInstance.startIp }}
  clusterIP: {{ .Values.iocInstance.clusterIP | default (include "allocateIpFromName" $alloc_args) }}
  ports:
    - name: ca-server-tcp
      port: {{ .Values.iocInstance.ca_server_port | default 5064 }}
      targetPort: {{ .Values.iocInstance.ca_server_port | default 5064 }}
      protocol: TCP
    - name: ca-server-udp
      port: {{ .Values.iocInstance.ca_server_port | default 5064 }}
      targetPort: {{ .Values.iocInstance.ca_server_port | default 5064 }}
      protocol: UDP
    - name: ca-repeater-tcp
      port: {{ add1 (.Values.iocInstance.ca_server_port | default 5064) }}
      targetPort: {{ add1 (.Values.iocInstance.ca_server_port | default 5064) }}
      protocol: TCP
    - name: ca-repeater-udp
      port: {{ add1 (.Values.iocInstance.ca_server_port | default 5064) }}
      targetPort: {{ add1 (.Values.iocInstance.ca_server_port | default 5064) }}
      protocol: UDP
    - name: pva-server-tcp
      port: {{ .Values.iocInstance.pva_server_port | default 5075 }}
      targetPort: {{ .Values.iocInstance.pva_server_port | default 5075 }}
      protocol: TCP
    - name: pva-server-udp
      port: {{ .Values.iocInstance.pva_server_port | default 5075 }}
      targetPort: {{ .Values.iocInstance.pva_server_port | default 5075 }}
      protocol: UDP
    - name: pva-broadcast-tcp
      port: {{ add1 (.Values.iocInstance.pva_server_port | default 5075) }}
      targetPort: {{ add1 (.Values.iocInstance.pva_server_port | default 5075) }}
      protocol: TCP
    - name: pva-broadcast-udp
      port: {{ add1 (.Values.iocInstance.pva_server_port | default 5075) }}
      targetPort: {{ add1 (.Values.iocInstance.pva_server_port | default 5075) }}
      protocol: UDP
{{- end }}

{{- end -}}
