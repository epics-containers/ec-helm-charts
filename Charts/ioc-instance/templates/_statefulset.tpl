{{- define "ioc-instance.statefulset" -}}


{{/*
  Use 'with' to access ioc-instance key via Values dictionary.
  Required because kebab-case .ioc-instance is illegal as a variable name.
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
    ioc: "true"
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
      {{- if ne .imagePullPolicy "Always"}}
      imagePullPolicy: {{ .imagePullPolicy }}
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
        - name: config-volume
          configMap:
            name: {{ $.Release.Name }}-config
        {{- with .volumes }}
          {{- toYaml . | nindent 10 }}
        {{- end }}

      {{- /* Main IOC container *********************************************/}}
      containers:
      - name: {{ $.Release.Name }}
        image: {{ .image }}
        {{- with .command }}
        command:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{- with .args }}
        args:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{- with .livenessProbe }}
        livenessProbe:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{ with .lifecycle }}
        lifecycle:
          {{- . | toYaml | nindent 10 }}
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
        env:
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
        {{- range .env }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}
        {{- range $.Values.global.env }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}

      {{- /* Additional ad hoc containers ***********************************/}}
      {{- $root := . }}
      {{- range .extraContainers }}
      - name: {{ .name }}
        image: {{ .image }}
        # a writable place to have cwd
        workingDir: /tmp
        env:
          - name: HOME
            value: /tmp
          - name: TERM
            value: xterm-256color

          {{- /* Add in additional environment vars */}}
          {{- range $root.env }}
          - name: {{ .name }}
            value: {{ .value }}
          {{- end }}
          {{- range $.Values.global.env }}
          - name: {{ .name }}
            value: {{ .value }}
          {{- end }}

        {{- with $root.securityContext }}
        securityContext:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .command }}
        command:
          {{- . | toYaml | nindent 12 }}
        {{- end }}
        {{- with .args }}
        args:
          {{- . | toYaml | nindent 12 }}
        {{- end }}
        volumeMounts:
          {{- with $root.volumeMounts }}
            {{- toYaml . | nindent 14 }}
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
          - name: config-volume
            mountPath: {{ $root.iocConfig }}
          {{- if or ($root.dataVolume.pvc) ($root.dataVolume.hostPath) }}
          - name: {{ $.Release.Name }}-data
            mountPath: {{ $root.dataVolume.hostPath }}
            {{- if $root.dataVolume.hostPath }}
            mountPropagation: HostToContainer
            {{- end}}
          {{- end }}
      {{- end }}
      {{/* End of containers ************************************************/}}

{{- end }} {{/* end with .ioc-instance */}}
{{- end }} {{/* end define "statefulset" */}}
