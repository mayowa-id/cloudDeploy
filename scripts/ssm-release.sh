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
logging=$(jq -nc --arg group "$LOG_GROUP" '{CloudWatchLogGroupName: $group, CloudWatchOutputEnabled: true}')
command_id=$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" \
  --document-name "$SSM_DOCUMENT" --parameters "$parameters" --timeout-seconds 90 \
  --cloud-watch-output-config "$logging" --query 'Command.CommandId' --output text)
printf 'Waiting for SSM command %s. CloudWatch log group: %s\n' "$command_id" "$LOG_GROUP"

for attempt in {1..150}; do
  if status=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$command_id" \
    --instance-id "$INSTANCE_ID" --query Status --output text 2>&1); then
    case "$status" in
      Success) printf 'Release %s passed rollout and smoke checks.\n' "$release"; exit 0 ;;
      Pending|InProgress|Delayed|Cancelling) ;;
      *) printf 'SSM command %s ended with status %s. See CloudWatch.\n' "$command_id" "$status" >&2; exit 1 ;;
    esac
  elif [[ "$status" != *InvocationDoesNotExist* ]]; then
    printf 'Unable to query SSM command %s. See CloudWatch for command output.\n' "$command_id" >&2
    exit 1
  fi
  sleep 5
done
printf 'Timed out waiting for SSM command %s. See CloudWatch for command output.\n' "$command_id" >&2
exit 1
