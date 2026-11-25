#!/usr/bin/env bash
set -euo pipefail

manifest=${1:?Usage: ssm-release.sh MANIFEST GIT_SHA}
release=${2:?Usage: ssm-release.sh MANIFEST GIT_SHA}
[[ -s "$manifest" && "$release" =~ ^[0-9a-f]{40}$ ]] || exit 2
: "${AWS_REGION:?}" "${AWS_ACCOUNT_ID:?}" "${ARTIFACT_BUCKET:?}" "${INSTANCE_ID:?}" "${SSM_DOCUMENT:?}" "${LOG_GROUP:?}"

export AWS_PAGER=""
export AWS_MAX_ATTEMPTS=3
aws s3api put-object --region "$AWS_REGION" --bucket "$ARTIFACT_BUCKET" \
  --expected-bucket-owner "$AWS_ACCOUNT_ID" --key "releases/$release/manifests.yaml" \
  --content-type application/yaml --body "$manifest" >/dev/null
parameters=$(jq -nc --arg release "$release" '{ReleaseId: [$release]}')
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/ssm-command.sh" "$parameters"
