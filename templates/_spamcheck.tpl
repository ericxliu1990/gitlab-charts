{{/* ######### gitlab-spamcheck related templates */}}

{{/*
Return the gitlab-spamcheck secret
*/}}

{{- define "gitlab.spamcheck.secret" -}}
{{- default (printf "%s-gitlab-spamcheck-secret" .Release.Name) .Values.global.appConfig.gitlab_spamcheck.secret | quote -}}
{{- end -}}

{{- define "gitlab.spamcheck.key" -}}
{{- default "spamcheck_shared_secret" .Values.global.appConfig.gitlab_spamcheck.key | quote -}}
{{- end -}}
