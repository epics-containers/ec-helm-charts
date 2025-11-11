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
spec:
  replicas: {{ $enabled | ternary 1 0 }}
  podManagementPolicy: Parallel  # force rollout from a failing state
  selector:
    matchLabels:
      app: {{ $.Release.Name }}
    env:
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
        {{- end -}}

        {{/* supply a complete liveness probe object */}}
        {{- with .livenessProbe }}
        livenessProbe:
          {{- . | toYaml | nindent 10 }}
        {{- else }}
        {{/* or just the executable for default livenessProbe behaviour */}}
        {{- with .livenessExecutable -}}
        livenessProbe:
          exec:
            command:
              - /bin/bash
              - {{ . }}
          initialDelaySeconds: 120
          periodSeconds: 30
        {{- end }}
        {{- end -}}

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
        {{- end -}}

        volumeMounts: &volumeMounts
          {{ if ne $.Values.configFolderConfigMap "{}" }}
          - name: config-volume
            mountPath: {{ $root.iocConfig }}
          {{- end }}
          {{- if or ($root.dataVolume.pvc) ($root.dataVolume.hostPath) }}
          - name: {{ $.Release.Name }}-data
            mountPath: {{ $root.dataVolume.hostPath }}
            {{- if $root.dataVolume.hostPath }}
            mountPropagation: HostToContainer
            {{- end}}
          {{- end }}
          {{- if $root.nfsv2TftpClaim }}
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
          {{- with $root.volumeMounts }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
        stdin: true
        tty: true
        {{- with .securityContext }}
        securityContext:
          {{-  toYaml . | nindent 10 }}
        {{- end }}
        {{- with .resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        env: &env
        - name: ARGOCD_COMMIT_HASH
          value: {{ $.Values.global.commitHash | quote }}
        - name: ARGOCD_SOURCE_REPO
          value: {{ $.Values.global.sourceRepo | quote }}
        - name: ARGOCD_SOURCE_Path
          value: {{ $.Values.global.sourcePath | quote }}
        - name: IOCSH_PS1
          value: "{{ $.Release.Name }} > "
        - name: IOC_NAME
          value: {{ $.Release.Name }}
        - name: IOC_PREFIX
          value: {{ or .prefix $.Release.Name | quote }}
        - name: IOC_LOCATION
          value: {{ $location | quote }}
        - name: IOC_DOMAIN
          value: {{ $domain | quote }}
        - name: HOME
          value: /tmp
        - name: TERM
          value: xterm-256color

        {{- /* Add in the global and instance additional environment vars */}}
        {{- range $root.env }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}
        {{- range $.Values.global.env }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}


      {{- /* Additional ad hoc containers ***********************************/}}
      {{- range .extraContainers }}
      - name: {{ .name }}
        image: {{ .image }}
        imagePullPolicy: {{ .imagePullPolicy }}
        # a writable place to have cwd
        workingDir: /tmp
        {{- with .command }}
        command:
          {{- . | toYaml | nindent 12 }}
        {{- end }}
        {{- with .args }}
        args:
          {{- . | toYaml | nindent 12 }}
        {{- end }}
        volumeMounts: *volumeMounts
        env: *env
        {{- with $root.securityContext }}
        securityContext:
          {{- toYaml . | nindent 12 }}
        {{- end }}
      {{- end }}

      {{- /* Init containers ************************************************/}}
      {{- with .initContainers }}
      initContainers:
        {{- range . }}
        - name: {{ .name }}
          image: {{ .image }}
          imagePullPolicy: {{ .imagePullPolicy }}
          # a writable place to have cwd
          workingDir: /tmp
          {{- with .command }}
          command:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          {{- with .args }}
          args:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          volumeMounts: *volumeMounts
          env: *env
          {{- with $root.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- end }}
      {{- end }}

      {{/* End of containers ************************************************/}}

{{- end }} {{/* end with .ioc-instance */}}
{{- end }} {{/* end define "statefulset" */}}
