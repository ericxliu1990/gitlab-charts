{{/* ######### Spamcheck related templates */}}

{{- define "gitlab.spamcheck.mountSecrets" -}}
{{- if (or .Values.global.spamcheck.enabled .Values.global.appConfig.gitlab_spamcheck.enabled) -}}
# mount secret for spamcheck
- secret:
    name: {{ template "gitlab.spamcheck.secret" . }}
    items:
      - key: {{ template "gitlab.spamcheck.key" . }}
        path: spamcheck/.gitlab_spamcheck_secret
{{- end -}}
{{- end -}}{{/* "gitlab.spamcheck.mountSecrets" */}}

{{/*
Returns the Spamcheck hostname
If the hostname is set in `global.hosts.spamcheck.name`, that will be returned,
otherwise the hostname will be assembed using `spamcheck` as the prefix, and the `gitlab.assembleHost` function.
*/}}
{{- define "gitlab.spamcheck.hostname" -}}
{{- coalesce $.Values.global.hosts.spamcheck.name (include "gitlab.assembleHost"  (dict "name" "spamcheck" "context" . )) -}}
{{- end -}}

{{/*
Return the Spamcheck service name
*/}}
{{- define "gitlab.spamcheck.serviceName" -}}
{{- include "gitlab.other.fullname" (dict "context" . "chartName" "spamcheck") -}}
{{- end -}}
