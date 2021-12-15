{{/*
Adds `ingress.class` annotation based on the API version of Ingress.

It expects a dictionary with two entries:
  - `global` which contains global ingress settings, e.g. .Values.global.ingress
  - `parent` which is the parent context (either `.` or `$`)
*/}}
{{- define "ingress.class.annotation" -}}
{{-   $apiVersion := include "gitlab.ingress.apiVersion" . -}}
{{-   $className := .global.class | default (printf "%s-nginx" .parent.Release.Name) -}}
{{-   if and (not (eq $apiVersion "networking.k8s.io/v1")) (not (eq $apiVersion "networking.k8s.io/v1beta1")) -}}
kubernetes.io/ingress.class: {{ $className }}
{{-   end -}}
{{- end -}}

{{/*
Sets `ingressClassName` based on the API version of Ingress.

It expects a dictionary with two entries:
  - `global` which contains global ingress settings, e.g. .Values.global.ingress
  - `parent` which is the parent context (either `.` or `$`)
*/}}
{{- define "ingress.class.spec" -}}
{{-   $apiVersion := include "gitlab.ingress.apiVersion" . -}}
{{-   $className := .global.class | default (printf "%s-nginx" .parent.Release.Name) -}}
{{-   if or (eq $apiVersion "networking.k8s.io/v1") (eq $apiVersion "networking.k8s.io/v1beta1") -}}
ingressClassName: {{ $className }}
{{-   end -}}
{{- end -}}
