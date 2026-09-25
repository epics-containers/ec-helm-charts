{{- /*
Helpers shared by the main IOC container, initContainers and extraContainers.

Each helper takes a context dict:
  top:      the chart root context ($)
  ioc:      the ioc-instance values
  domain:   the derived domain
  location: the derived location
  c:        (ioc-instance.container only) one initContainers/extraContainers entry
*/ -}}


{{- /*
The volumeMounts of the main IOC container, as a YAML list at column 0.
*/ -}}
{{- define "ioc-instance.volumeMounts" -}}
{{- $top := .top -}}
{{- $ioc := .ioc -}}
{{- if ne $top.Values.configFolderConfigMap "{}" }}
- name: config-volume
  mountPath: {{ $ioc.iocConfig }}
{{- end }}
{{- if or $ioc.dataVolume.pvc $ioc.dataVolume.hostPath }}
- name: {{ $top.Release.Name }}-data
  mountPath: {{ $ioc.dataVolume.mountPath | default $ioc.dataVolume.hostPath | default "/data" }}
  mountPropagation: HostToContainer
{{- end }}
{{- if $ioc.nfsv2TftpClaim }}
- name: nfsv2-tftp-volume
  mountPath: /nfsv2-tftp
  subPath: "{{ .domain }}/{{ $top.Release.Name }}"
{{- end }}
- name: runtime-volume
  mountPath: /epics/runtime
  subPath: "{{ $top.Release.Name }}"
- name: opis-volume
  mountPath: /epics/opi
  subPath: "{{ $top.Release.Name }}"
- name: autosave-volume
  mountPath: /autosave
  subPath: "{{ $top.Release.Name }}"
{{- with $ioc.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }} {{/* end define "ioc-instance.volumeMounts" */}}


{{- /*
The env of the main IOC container, as a YAML list at column 0.
*/ -}}
{{- define "ioc-instance.env" -}}
{{- $top := .top -}}
{{- $ioc := .ioc -}}
- name: ARGOCD_SOURCE_REPO
  value: {{ $top.Values.global.sourceRepo | quote }}
- name: ARGOCD_SOURCE_Path
  value: {{ $top.Values.global.sourcePath | quote }}
{{- if $ioc.rebootEveryCommit }}
- name: ARGOCD_COMMIT_HASH
  value: {{ $top.Values.global.commitHash | quote }}
{{- end }}
- name: IOCSH_PS1
  value: "{{ $top.Release.Name }} > "
- name: IOC_NAME
  value: {{ $top.Release.Name | quote }}
- name: IOC_PREFIX
  value: {{ or $ioc.prefix $top.Release.Name | quote }}
- name: IOC_LOCATION
  value: {{ .location | quote }}
- name: IOC_DOMAIN
  value: {{ .domain | quote }}
- name: HOME
  value: /tmp
- name: TERM
  value: xterm-256color
{{- /* Add in the global and instance additional environment vars */}}
{{- range $ioc.env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- range $top.Values.global.env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end }} {{/* end define "ioc-instance.env" */}}


{{- /*
One initContainers or extraContainers entry, as a YAML list item at column 0.

Each field defaults to the main IOC container's setting:
  volumeMounts     the main container mounts, replaced if the entry sets volumeMounts
  env              the main container env, with the entry's env appended
  securityContext  the IOC securityContext unless the entry sets its own
  resources        the IOC resources unless the entry sets its own. The USB
                   device claims stay with the main container only.
  workingDir       /tmp, a writable place to have cwd
  imagePullPolicy  omitted unless the entry sets it
*/ -}}
{{- define "ioc-instance.container" -}}
{{- $c := .c -}}
{{- $ioc := .ioc -}}
- name: {{ $c.name }}
  image: {{ $c.image }}
  {{- with $c.imagePullPolicy }}
  imagePullPolicy: {{ . }}
  {{- end }}
  # a writable place to have cwd
  workingDir: {{ $c.workingDir | default "/tmp" }}
  {{- with $c.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $c.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if hasKey $c "volumeMounts" }}
  {{- with $c.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else }}
  volumeMounts:
    {{- include "ioc-instance.volumeMounts" . | trim | nindent 4 }}
  {{- end }}
  env:
    {{- include "ioc-instance.env" . | nindent 4 }}
    {{- with $c.env }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with (hasKey $c "securityContext" | ternary $c.securityContext $ioc.securityContext) }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (hasKey $c "resources" | ternary $c.resources $ioc.resources) }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }} {{/* end define "ioc-instance.container" */}}
