#!/usr/bin/env bash
set -euo pipefail

image=${1:-}
release=${2:-}
if [[ ! "$image" =~ ^ghcr\.io/[a-z0-9._-]+/[a-z0-9._-]+@sha256:[0-9a-f]{64}$ ]] ||
   [[ ! "$release" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Usage: render-release.sh ghcr.io/owner/image@sha256:<digest> <40-character Git SHA>' >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cp "$root"/kubernetes/{namespace,configmap,deployment,service,hpa}.yaml "$work/"

cat >"$work/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - hpa.yaml
images:
  - name: clouddeploy
    newName: ${image%@*}
    digest: ${image#*@}
patches:
  - target:
      kind: ConfigMap
      name: clouddeploy-api
    patch: |-
      - op: replace
        path: /data/APP_ENV
        value: aws
  - target:
      kind: Deployment
      name: clouddeploy-api
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: APP_COMMIT
          value: "$release"
EOF
kubectl kustomize "$work"
