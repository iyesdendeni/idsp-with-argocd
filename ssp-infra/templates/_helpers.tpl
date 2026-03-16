{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ssp-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ssp-infra.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{/*
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
*/}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{/*
{{- end -}}
*/}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ssp-infra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for RBAC APIs.
*/}}
{{- define "rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" -}}
rbac.authorization.k8s.io/v1
{{- else -}}
rbac.authorization.k8s.io/v1alpha1
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "ssp-infra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "ssp-infra.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "ssp-infra.labels" -}}
helm.sh/chart: {{ include "ssp-infra.chart" . }}
{{ include "ssp-infra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "ssp-infra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ssp-infra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Return the appropriate apiGroup for PodSecurityPolicy.
*/}}
{{- define "rbac.pspApiGroup" -}}
{{- if semverCompare "<1.14-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions" -}}
{{- else if semverCompare ">=1.14-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "policy" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for DaemonSet.
*/}}
{{- define "daemonSet.apiVersion" -}}
{{- if semverCompare "<1.9-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else -}}
{{- print "apps/v1" -}}
{{- end -}}
{{- end -}}


{{- define "db.pxcName.def" -}}
{{- $pxcname := printf "%s-ssp-db" .Values.sspReleaseName -}}
{{- $pxcname }}
{{- end -}}


{{- define "db.secretName.def" -}}
{{- $dbsecretname := printf "%s-pxc" ( include "db.pxcName.def" . ) -}}
{{- $dbsecretname }}
{{- end -}}


{{- define "db.secretName" -}}
{{- $dbsecretname := ( include "db.secretName.def" . ) -}}
{{- default ( $dbsecretname ) .Values.db.existingSecret -}}
{{- end -}}


{{- define "db-ssl.secretName.def" -}}
{{- $dbsslsecretname := printf "%s-ssl-pxc" ( include "db.pxcName.def" . ) -}}
{{- $dbsslsecretname }}
{{- end -}}


{{- define "db-ssl.secretName" -}}
{{- $dbsslsecretname := ( include "db-ssl.secretName.def" . ) -}}
{{- default ( $dbsslsecretname ) .Values.db.existingSslSecret -}}
{{- end -}}


{{- define "db-ssl-internal.secretName.def" -}}
{{- $dbsslsecretname := printf "%s-internal" ( include "db-ssl.secretName" . ) -}}
{{- $dbsslsecretname }}
{{- end -}}


{{- define "db-ssl-internal.secretName" -}}
{{- $dbsslsecretname := ( include "db-ssl-internal.secretName.def" . ) -}}
{{- default ( $dbsslsecretname ) .Values.db.existingSslInternalSecret -}}
{{- end -}}


{{/*
template expects  dict "root" . "valuesparentkey" "XXXX" "valuekey" "XXXXX" "secretkey" "XXXX"
if password value was passed into chart, return that value
otherwise, if secret exists then return password value from there
otherwise if secret does not exist then return random password
*/}}
{{- define "db.secretName.password" -}}
{{- if index .root "Values" "db" .valuesparentkey .valuekey -}}
{{- index .root "Values" "db" .valuesparentkey .valuekey | b64enc | quote -}}
{{- else -}}
{{- $dbsecretname := ( include "db.secretName.def" .root ) -}}
{{- $secret := (lookup "v1" "Secret" .root.Release.Namespace $dbsecretname ) -}}
{{- if $secret -}}
{{- index $secret "data" .secretkey -}}
{{- else -}}
{{- randAlphaNum 32 | b64enc | quote -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "db.hostName" -}}
{{- $dbhost := printf "%s-pxc" ( include "db.pxcName.def" . ) -}}
{{- $dbhost }}
{{- end -}}

{{/*
Base64 Encode Registry Credentials
*/}}
{{- define "imagePullSecret" -}}
{{- with .Values.global.registry -}}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .url .credentials.username .credentials.password .credentials.email (printf "%s:%s" .credentials.username .credentials.password | b64enc) | b64enc }}
{{- end -}}
{{- end -}}

{{- define "exists.deprecated.fluentbit.configmap" -}}
{{- $configmapname := index .Values "fluent-bit" "existingConfigMap" -}}
{{- $existingconfigmap := (lookup "v1" "ConfigMap"  .Release.Namespace   $configmapname ) -}}
{{- if not $existingconfigmap -}}
{{- "false" -}}
{{- else -}}
{{- $cmversion := index $existingconfigmap "metadata" "annotations" "configVersion" -}}
{{- if $cmversion -}}
{{- "false" -}}
{{- else -}}
{{- "true" -}}
{{- end -}}
{{- end -}}
{{- end -}}
