{{/*
Adds `ingress.class` annotation based on the API version of Ingress.
*/}}
{{- define "ingress.class.annotation" -}}
{{-   $className := .global.class | default (printf "%s-nginx" .parent.Release.Name) -}}
{{-   if and (not (.parent.Capabilities.APIVersions.Has "networking.k8s.io/v1/Ingress")) (not (.parent.Capabilities.APIVersions.Has "networking.k8s.io/v1beta1/Ingress")) -}}
kubernetes.io/ingress.class: {{ $className }}
{{-   end -}}
{{- end -}}

{{/*
Sets `ingressClassName` based on the API version of Ingress.
*/}}
{{- define "ingress.class.spec" -}}
{{-   $className := .global.class | default (printf "%s-nginx" .parent.Release.Name) -}}
{{-   if .parent.Capabilities.APIVersions.Has "networking.k8s.io/v1/Ingress" -}}
ingressClassName: {{ $className }}
{{-   else if .parent.Capabilities.APIVersions.Has "networking.k8s.io/v1beta1/Ingress" -}}
ingressClassName: {{ $className }}
{{-   end -}}
{{- end -}}
