{{- define "ioc-instance.statefulset" -}}


{{/*
  Use 'with' to access ioc-instance key.
  Required because .ioc-instance is illegal because of the hyphen.
*/}}
{{ with get .Values "ioc-instance" }}

{{- /*
Default the derivable substitution values.

This keeps the length of the values.txt file for each individual IOC
to a minimum
*/ -}}
{{- $location := default $.Values.global.location .location | required "ERROR - You must supply location or global.location" -}}
{{- $domain := default $.Values.global.domain .domain | required "ERROR - You must supply domain or global.domain" -}}
{{- $opisClaim := default (print $domain "-opi-claim") .opisClaim -}}
{{- $runtimeClaim := default (print $domain "-runtime-claim") .runtimeClaim -}}
{{- $autosaveClaim := default (print $domain "-autosave-claim") .autosaveClaim -}}
{{- $image := .image | required "ERROR - You must supply image." -}}
{{- $enabled := eq $.Values.global.enabled false | ternary false true -}}

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ $.Release.Name }}
  labels:
    app: {{ $.Release.Name }}
    location: {{ $location }}
    domain: {{ $domain }}
    enabled: {{ $enabled | quote }}
    is_ioc: "true"
spec:
  replicas: {{ $enabled | ternary 1 0 }}
  podManagementPolicy: Parallel  # force rollout from a failing state
  selector:
    matchLabels:
      app: {{ $.Release.Name }}
  template:
    metadata:
      labels:
        app: {{ $.Release.Name }}
        location: {{ $location }}
        domain: {{ $domain }}
        is_ioc: "true"
        # re-deploy in case the configMap has changed
        configHash: {{ $.Values.configFolderHash | default "noConfigMap" | quote }}
    spec:
      {{- with .runtimeClassName }}
      runtimeClassName: {{ . }}
      {{- end }}
      {{- with .serviceAccountName }}
      serviceAccountName: {{ . | quote }}
      {{- end }}
      hostNetwork: {{ .hostNetwork }}
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
        {{- with .nfsv2TftpClaim }}
        - name: nfsv2-tftp-volume
          persistentVolumeClaim:
            claimName: {{ . }}
        {{- end }}
        {{- if .dataVolume.pvc }}
        - name: {{ $.Release.Name }}-data
          persistentVolumeClaim:
            claimName: {{ $.Release.Name }}-data
        {{- else }}
        {{- with .dataVolume.hostPath }}
        - name: {{ $.Release.Name }}-data
          hostPath:
            path: {{ . }}
            type: Directory
        {{- end }}
        {{- end }}
        - name: config-volume
          configMap:
            name: {{ $.Release.Name }}-config
        {{- with .volumes }}
{{  toYaml . | indent 8}}
        {{- end }}
      containers:
      - name: {{ $.Release.Name }}
        image: {{ .image }}
        command:
        {{- if (kindIs "string" .startCommand) }}
        - {{ .startCommand }}
        {{- else if (kindIs "slice" .startCommand) }}
        {{- .startCommand | toYaml | nindent 8 }}
        {{- end }}
        args:
        {{- if (kindIs "string" .startArgs) }}
        - {{ .startArgs }}
        {{- else if (kindIs "slice" .startArgs) }}
        {{- .startArgs | toYaml | nindent 8 }}
        {{- end }}
        livenessProbe:
          exec:
            command:
            {{- if (kindIs "string" .liveness) }}
            - /bin/bash
            - {{ .liveness }}
            {{- else if (kindIs "slice" .liveness) }}
            {{- .liveness | toYaml | nindent 12 }}
            {{- end }}
          initialDelaySeconds: 120
          periodSeconds: 10
        lifecycle:
          preStop:
            exec:
              command:
              {{- if (kindIs "string" .stop) }}
              - /bin/bash
              - {{ .stop }}
              {{- else if (kindIs "slice" .stop) }}
              {{- .stop | toYaml | nindent 14 }}
              {{- end }}
        volumeMounts:
        - name: config-volume
          mountPath: {{ .iocConfig }}
        {{- if or (.dataVolume.pvc) (.dataVolume.hostPath) }}
        - name: {{ $.Release.Name }}-data
          mountPath: {{ .dataVolume.hostPath }}
          {{- if .dataVolume.hostPath }}
          mountPropagation: HostToContainer
          {{- end}}
        {{- end }}
        {{- if .nfsv2TftpClaim }}
        - name: nfsv2-tftp-volume
          mountPath: /nfsv2-tftp
          subPath: "{{ $domain }}/{{ $.Release.Name }}"
        {{- end }}
        - name: runtime-volume
          mountPath: /epics/runtime
          subPath: "{{ $.Release.Name }}"
        - name: opis-volume
          mountPath: /epics/opi
          subPath: "{{ $.Release.Name }}"
        - name: autosave-volume
          mountPath: /autosave
          subPath: "{{ $.Release.Name }}"
        {{- with .volumeMounts }}
{{  toYaml . | indent 8}}
        {{- end }}
        stdin: true
        tty: true
        {{- with .securityContext }}
        securityContext:
{{  toYaml . | indent 10}}
        {{- end }}
        {{- with .resources }}
        resources:
{{  toYaml . | indent 10}}
        {{- end }}
        imagePullPolicy: Always
        env:
        - name: IOCSH_PS1
          value: "{{ $.Release.Name }} > "
        - name: IOC_NAME
          value: {{ $.Release.Name }}
        - name: IOC_PREFIX
          value: {{ or .prefix $.Release.Name | quote }}
        - name: IOC_LOCATION
          value: {{ $location | quote }}
        - name: IOC_GROUP
          value: {{ $domain | quote }}
        {{- with $.Values.globalEnv }}
{{  toYaml . | indent 8}}
        {{- end }}
        {{- with .iocEnv }}
{{  toYaml . | indent 8}}
        {{- end }}
      {{- with .nodeName }}
      nodeName: {{ . }}
      {{- else }}
      {{- with .affinity }}
      affinity:
{{  toYaml . | indent 8}}
      {{- end }}
      {{- end }}
      {{- with .tolerations }}
      tolerations:
{{  toYaml . | indent 8}}
      {{- end }}

{{ if .dataVolume.pvc }}
---
# This IOC uses a data volume, so we will create a PVC for it
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ $.Release.Name }}-data
  labels:
    app: {{ $.Release.Name }}
    location: {{ $location }}
    domain: {{ $domain }}
    is_ioc: "true"
spec:
{{- if .dataVolume.spec }}
{{  toYaml .dataVolume.spec | indent 2 }}
{{ else }}
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1000Mi
{{- end }}
{{ else }}
# This IOC has no data volume, so we will mount the host filesystem
{{- end }}  {{/* end if .dataVolume.spec */}}
{{- end -}} {{/* end with .ioc-instance */}}
{{- end -}} {{/* end define "statefulset" */}}
