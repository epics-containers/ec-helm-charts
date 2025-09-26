{{- define "iocInstance.statefulset" -}}
{{- /*
Default the derivable substitution values.

This keeps the length of the values.txt file for each individual IOC
to a minimum
*/ -}}
{{- $location := default .Values.global.location .Values.iocInstance.location | required "ERROR - You must supply location or global.location" -}}
{{- $ioc_group := default .Values.global.ioc_group .Values.iocInstance.ioc_group | required "ERROR - You must supply ioc_group or global.ioc_group" -}}
{{- $opisClaim := default (print $ioc_group "-opi-claim") .Values.iocInstance.opisClaim -}}
{{- $runtimeClaim := default (print $ioc_group "-runtime-claim") .Values.iocInstance.runtimeClaim -}}
{{- $autosaveClaim := default (print $ioc_group "-autosave-claim") .Values.iocInstance.autosaveClaim -}}
{{- $image := .Values.iocInstance.image | required "ERROR - You must supply image." -}}

{{- $enabled := eq .Values.global.enabled false | ternary false true -}}

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
    location: {{ $location }}
    ioc_group: {{ $ioc_group }}
    enabled: {{ $enabled | quote }}
    is_ioc: "true"
spec:
  replicas: {{ $enabled | ternary 1 0 }}
  podManagementPolicy: Parallel  # force rollout from a failing state
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
        location: {{ $location }}
        ioc_group: {{ $ioc_group }}
        is_ioc: "true"
        # re-deploy in case the configMap has changed - use a random value
        # unless the Commit Hash is supplied (by ArgoCD or helm command line)
        configHash: {{ .Values.iocInstance.configFolderHash | default "noConfigMap" | quote }}
    spec:
      {{- with .Values.iocInstance.runtimeClassName }}
      runtimeClassName: {{ . }}
      {{- end }}
      {{- with .Values.iocInstance.serviceAccountName }}
      serviceAccountName: {{ . | quote }}
      {{- end }}
      hostNetwork: {{ .Values.iocInstance.hostNetwork }}
      terminationGracePeriodSeconds: 3 # nice to have quick restarts on IOCs
      volumes:
        - name: runtime-volume
          persistentVolumeClaim:
            claimName: {{ $runtimeClaim }}
        - name: opis-volume
          persistentVolumeClaim:
            claimName: {{ $opisClaim }}
        - name: autosave-volume
          persistentVolumeClaim:
            claimName: {{ $autosaveClaim }}
        {{- with .Values.iocInstance.nfsv2TftpClaim }}
        - name: nfsv2-tftp-volume
          persistentVolumeClaim:
            claimName: {{ . }}
        {{- end }}
        {{- if .Values.iocInstance.dataVolume.pvc }}
        - name: {{ .Release.Name }}-data
          persistentVolumeClaim:
            claimName: {{ .Release.Name }}-data
        {{- else }}
        {{- with .Values.iocInstance.dataVolume.hostPath }}
        - name: {{ $.Release.Name }}-data
          hostPath:
            path: {{ . }}
            type: Directory
        {{- end }}
        {{- end }}
        - name: config-volume
          configMap:
            name: {{ .Release.Name }}-config
        {{- with .Values.iocInstance.volumes }}
{{  toYaml . | indent 8}}
        {{- end }}
      containers:
      - name: {{ .Release.Name }}
        image: {{ .Values.iocInstance.image }}
        command:
        {{- if (kindIs "string" .Values.iocInstance.startCommand) }}
        - {{ .Values.iocInstance.startCommand }}
        {{- else if (kindIs "slice" .Values.iocInstance.startCommand) }}
        {{- .Values.iocInstance.startCommand | toYaml | nindent 8 }}
        {{- end }}
        args:
        {{- if (kindIs "string" .Values.iocInstance.startArgs) }}
        - {{ .Values.iocInstance.startArgs }}
        {{- else if (kindIs "slice" .Values.iocInstance.startArgs) }}
        {{- .Values.iocInstance.startArgs | toYaml | nindent 8 }}
        {{- end }}
        livenessProbe:
          exec:
            command:
            {{- if (kindIs "string" .Values.iocInstance.liveness) }}
            - /bin/bash
            - {{ .Values.iocInstance.liveness }}
            {{- else if (kindIs "slice" .Values.iocInstance.liveness) }}
            {{- .Values.iocInstance.liveness | toYaml | nindent 12 }}
            {{- end }}
          initialDelaySeconds: 120
          periodSeconds: 10
        lifecycle:
          preStop:
            exec:
              command:
              {{- if (kindIs "string" .Values.iocInstance.stop) }}
              - /bin/bash
              - {{ .Values.iocInstance.stop }}
              {{- else if (kindIs "slice" .Values.iocInstance.stop) }}
              {{- .Values.iocInstance.stop | toYaml | nindent 14 }}
              {{- end }}
        volumeMounts:
        - name: config-volume
          mountPath: {{ .Values.iocInstance.iocConfig }}
        {{- if or (.Values.iocInstance.dataVolume.pvc) (.Values.iocInstance.dataVolume.hostPath)  }}
        - name: {{ .Release.Name }}-data
          mountPath: {{ .Values.iocInstance.dataVolume.hostPath }}
          {{- if .Values.iocInstance.dataVolume.hostPath }}
          mountPropagation: HostToContainer
          {{- end}}
        {{- end }}
        {{- if .Values.iocInstance.nfsv2TftpClaim }}
        - name: nfsv2-tftp-volume
          mountPath: /nfsv2-tftp
          subPath: "{{ $ioc_group }}/{{ .Release.Name }}"
        {{- end }}
        - name: runtime-volume
          mountPath: /epics/runtime
          subPath: "{{ .Release.Name }}"
        - name: opis-volume
          mountPath: /epics/opi
          subPath: "{{ .Release.Name }}"
        - name: autosave-volume
          mountPath: /autosave
          subPath: "{{ .Release.Name }}"
        {{- with .Values.iocInstance.volumeMounts }}
{{  toYaml . | indent 8}}
        {{- end }}
        stdin: true
        tty: true
        {{- with .Values.iocInstance.securityContext }}
        securityContext:
{{  toYaml . | indent 10}}
        {{- end }}
        {{- with .Values.iocInstance.resources }}
        resources:
{{  toYaml . | indent 10}}
        {{- end }}
        imagePullPolicy: Always
        env:
        - name: IOCSH_PS1
          value: "{{ .Release.Name }} > "
        - name: IOC_NAME
          value: {{ .Release.Name }}
        - name: IOC_PREFIX
          value: {{ or .Values.iocInstance.prefix .Release.Name | quote }}
        - name: IOC_LOCATION
          value: {{ $location | quote }}
        - name: IOC_GROUP
          value: {{ $ioc_group | quote }}
        {{- with .Values.iocInstance.globalEnv }}
{{  toYaml . | indent 8}}
        {{- end }}
        {{- with .Values.iocInstance.iocEnv }}
{{  toYaml . | indent 8}}
        {{- end }}
      {{- with .Values.iocInstance.nodeName }}
      nodeName: {{ . }}
      {{- else }}
      {{- with .Values.iocInstance.affinity }}
      affinity:
{{  toYaml . | indent 8}}
      {{- end }}
      {{- end }}
      {{- with .Values.iocInstance.tolerations }}
      tolerations:
{{  toYaml . | indent 8}}
      {{- end }}

{{ if .Values.iocInstance.dataVolume.pvc }}
---
# This IOC uses a data volume, so we will create a PVC for it
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ .Release.Name }}-data
  labels:
    app: {{ .Release.Name }}
    location: {{ $location }}
    ioc_group: {{ $ioc_group }}
    is_ioc: "true"
spec:
{{- if .Values.iocInstance.dataVolume.spec }}
{{  toYaml .Values.iocInstance.dataVolume.spec | indent 2 }}
{{ else }}
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1000Mi
{{- end }}
{{ else }}
# This IOC has no data volume, so we will mount the host filesystem
{{- end }}

{{- end -}}
