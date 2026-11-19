#!/usr/bin/env bash
set -euo pipefail

release=${1:-}
if [[ ! "$release" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Usage: clouddeploy-deploy <40-character lowercase Git SHA>' >&2
  exit 2
fi

timeout 180 cloud-init status --wait
exec 9>/run/clouddeploy-deployment.lock
flock -n 9 || { echo 'A CloudDeploy deployment or rollback is already running.' >&2; exit 1; }

config=/etc/clouddeploy/config.json
bucket=$(jq -er '.bucket' "$config")
region=$(jq -er '.region' "$config")
manifest=$(mktemp)
trap 'rm -f -- "$manifest"' EXIT

aws s3api get-object --bucket "$bucket" --key "releases/$release/manifests.yaml" \
  --region "$region" "$manifest" >/dev/null
printf 'Applying release %s\n' "$release"
k3s kubectl apply -f "$manifest"
k3s kubectl -n clouddeploy rollout status deployment/clouddeploy-api --timeout=150s
