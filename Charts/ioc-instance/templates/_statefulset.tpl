{{- define "ioc-instance.statefulset" -}}


{{/*
  Use 'with' to access ioc-instance key via Values dictionary.
  Required because kebab-case .ioc-instance is illegal as a variable name.
*/}}
{{ with get .Values "ioc-instance" }}
# Preserve the root of ioc-instance for use in sub contexts
{{- $root := . }}

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
{{- $enabled := eq $.Values.global.enabled false | ternary false true }}
{{- $customLabels := $.Values.global.labels }}
{{- /* context for the container helpers in _containers.tpl */}}
{{- $containerCtx := dict "top" $ "ioc" $root "domain" $domain "location" $location }}


apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ $.Release.Name }}
  labels:
    app: {{ $.Release.Name }}
    location: {{ $location }}
    domain: {{ $domain }}
    enabled: {{ $enabled | quote }}
    ioc: "true"
    {{- if .rebootEveryCommit }}
    commitHash: {{ $.Values.global.commitHash | quote }}
    {{- end }}
    {{- with $customLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  replicas: {{ $enabled | ternary 1 0 }}
  podManagementPolicy: Parallel  # force rollout from a failing state
  selector:
    matchLabels:
      app: {{ $.Release.Name }}
  template:

    {{- /* pod metadata *****************************************************/}}
    metadata:
      {{- with .podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        app: {{ $.Release.Name }}
        location: {{ $location }}
        domain: {{ $domain }}
        ioc: "true"
        {{- with .podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        # re-deploy if the configMap has changed
        configHash: {{ $.Values.configFolderHash | default "noConfigMap" | quote }}
        {{- with $customLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    {{- /* pod specification ************************************************/}}
    spec:
      {{- with .runtimeClassName }}
      runtimeClassName: {{ . }}
      {{- end }}
      {{- with .serviceAccountName }}
      serviceAccountName: {{ . | quote }}
      {{- end }}
      {{- with .hostNetwork }}
      hostNetwork: {{ . }}
      {{- end }}
      terminationGracePeriodSeconds: 3 # nice to have quick restarts on IOCs
      {{- with .podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .nodeName }}
      nodeName: {{ . }}
      {{- else }}
      {{- with .affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      {{- with .tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{- /* resource claims ************************************************/}}
      {{- if .usbDevices }}
      resourceClaims:
        - name: {{ $.Release.Name }}
          resourceClaimTemplateName: {{ $.Release.Name }}
      {{- end }}

      {{- /* volumes ********************************************************/}}
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
        {{- if .dataVolume.enabled }}
        {{- if .dataVolume.pvc }}
        - name: {{ $.Release.Name }}-data
          persistentVolumeClaim:
            claimName: {{ $.Release.Name }}-data
        {{- else }}
        - name: {{ $.Release.Name }}-data
          hostPath:
            path: {{ .dataVolume.hostPath | required "ERROR - dataVolume.hostPath is required when dataVolume.enabled is true and dataVolume.pvc is false" }}
            type: Directory
        {{- end }}
        {{- end }}
        {{ if ne $.Values.configFolderConfigMap "{}" }}
        - name: config-volume
          configMap:
            name: {{ $.Release.Name }}-config
        {{- end }}
        {{- with .volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

      {{- /* Main IOC container *********************************************/}}
      containers:
      - name: {{ $.Release.Name }}
        image: {{ .image }}
        imagePullPolicy: {{ .imagePullPolicy }}
        {{- with .command }}
        command:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{- with .args }}
        args:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{/* supply a complete startup probe object */}}
        {{- with .startupProbe }}
        startupProbe:
          {{- . | toYaml | nindent 10 }}
        {{- else }}
        {{/* or just the executable for default startupProbe behaviour */}}
        {{- with .startupExecutable }}
        startupProbe:
          exec:
            command:
              - /bin/bash
              - {{ . }}
          initialDelaySeconds: 0
          periodSeconds: 1
          failureThreshold: 2600000 # ~ a month if period kept at 1s
          timeoutSeconds: 1300000 # ~ half a month
        {{- end }}
        {{- end }}
        {{/* supply a complete readiness probe object */}}
        {{- with .readinessProbe }}
        readinessProbe:
          {{- . | toYaml | nindent 10 }}
        {{- else }}
        {{/* or just the executable for default readinessProbe behaviour */}}
        {{- with .readinessExecutable }}
        readinessProbe:
          exec:
            command:
              - /bin/bash
              - {{ . }}
          initialDelaySeconds: 20
          periodSeconds: 30
        {{- end }}
        {{- end }}
        {{/* supply a complete liveness probe object */}}
        {{- with .livenessProbe }}
        livenessProbe:
          {{- . | toYaml | nindent 10 }}
        {{- else }}
        {{/* or just the executable for default livenessProbe behaviour */}}
        {{- with .livenessExecutable }}
        livenessProbe:
          exec:
            command:
              - /bin/bash
              - {{ . }}
          initialDelaySeconds: 120
          periodSeconds: 30
        {{- end }}
        {{- end }}
        {{/* supply a complete lifecycle object */}}
        {{- with .lifecycle }}
        lifecycle:
          {{- . | toYaml | nindent 10 }}
        {{- else }}
        {{/* or just the stop executable for default lifecycle behaviour */}}
        {{- with .preStopExecutable }}
        lifecycle:
          preStop:
            exec:
              command:
                - /bin/bash
                - {{ . }}
        {{- end }}
        {{- end }}
        volumeMounts:
          {{- include "ioc-instance.volumeMounts" $containerCtx | trim | nindent 10 }}
        stdin: true
        tty: true
        {{- with .securityContext }}
        securityContext:
          {{-  toYaml . | nindent 10 }}
        {{- end }}
        {{- $usbDevices := .usbDevices }}
        {{- with .resources }}
        resources:
          {{- toYaml . | nindent 10 }}
          {{- if $usbDevices }}
          claims:
            - name: {{ $.Release.Name }}
          {{- end }}
        {{- end }}
        env:
          {{- include "ioc-instance.env" $containerCtx | nindent 10 }}


      {{- /* Additional ad hoc containers ***********************************/}}
      {{- /* see "ioc-instance.container" in _containers.tpl for the defaults */}}
      {{- range .extraContainers }}
      {{- include "ioc-instance.container" (merge (dict "c" .) $containerCtx) | nindent 6 }}
      {{- end }}

      {{- /* Init containers ************************************************/}}
      {{- with .initContainers }}
      initContainers:
        {{- range . }}
        {{- include "ioc-instance.container" (merge (dict "c" .) $containerCtx) | nindent 8 }}
        {{- end }}
      {{- end }}

      {{/* End of containers ************************************************/}}

{{- end }} {{/* end with .ioc-instance */}}
{{- end }} {{/* end define "statefulset" */}}
