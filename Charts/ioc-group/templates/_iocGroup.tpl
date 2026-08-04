{{- /*
Render one complete ioc-instance for every entry in .Values.iocs.

Each entry is a map of NAME: value environment variables that are appended to
the shared ioc-instance.env for that instance only. Every entry MUST supply
NAME: its value is used as a suffix on the release name so that every K8S
resource in the group is unique.

Everything else - image, resources, volumes, probes - comes from the single
shared ioc-instance block, and the single config folder is shared too. The
config specialises itself per instance because ioc.yaml reads IOC_NAME, which
ioc-instance derives from the release name.
*/ -}}
{{- define "ioc-group" -}}

{{- $iocs := .Values.iocs | default list -}}
{{- if not $iocs -}}
  {{- fail "ERROR - You must supply at least one IOC in the 'iocs' list" -}}
{{- end -}}

{{- $seen := dict -}}
{{- range $index, $vars := $iocs -}}

  {{- if not (kindIs "map" $vars) -}}
    {{- fail (printf "ERROR - iocs[%d] must be a map of NAME: value environment variables" $index) -}}
  {{- end -}}

  {{- /* the mandatory NAME environment variable */ -}}
  {{- $name := $vars.NAME | default "" | toString -}}
  {{- if not $name -}}
    {{- fail (printf "ERROR - iocs[%d] must supply an environment variable named NAME" $index) -}}
  {{- end -}}
  {{- if hasKey $seen $name -}}
    {{- fail (printf "ERROR - iocs[%d] repeats the NAME '%s' - each IOC in the group must be unique" $index $name) -}}
  {{- end -}}
  {{- $_ := set $seen $name true -}}

  {{- /*
    Convert this IOC's variables to the k8s name/value list that ioc-instance
    expects. Map keys iterate in sorted order, so the resulting env is
    alphabetical rather than as written.
  */ -}}
  {{- $env := list -}}
  {{- range $key, $value := $vars -}}
    {{- $env = append $env (dict "name" $key "value" $value) -}}
  {{- end -}}

  {{- /* per instance copy of the values, with this IOC's environment appended */ -}}
  {{- $values := deepCopy $.Values -}}
  {{- $instance := get $values "ioc-instance" -}}
  {{- if not (kindIs "map" $instance) -}}
    {{- fail "ERROR - You must supply an 'ioc-instance' block, shared by every IOC in the group" -}}
  {{- end -}}
  {{- $_ := set $instance "env" (concat ($instance.env | default list) $env) -}}

  {{- /*
    Synthesise a root context carrying a per instance Release.Name. Every
    resource name in ioc-instance derives from Release.Name, so this alone
    gives each IOC its own StatefulSet, Service, ConfigMap, PVC and
    ResourceClaimTemplate, plus its own cluster IP and volume subPaths.
  */ -}}
  {{- $context := dict
        "Chart" $.Chart
        "Capabilities" $.Capabilities
        "Template" $.Template
        "Files" $.Files
        "Values" $values
        "Release" (dict
          "Name" (printf "%s-%s" $.Release.Name $name)
          "Namespace" $.Release.Namespace
          "Service" $.Release.Service
          "Revision" $.Release.Revision
          "IsInstall" $.Release.IsInstall
          "IsUpgrade" $.Release.IsUpgrade)
  -}}
  {{- /* separate instances, but do not lead the file with an empty document */ -}}
  {{- if $index }}
---
  {{- end }}
{{ include "ioc-instance" $context }}
{{- end }} {{/* end range .Values.iocs */}}
{{- end }} {{/* end define ioc-group */}}
