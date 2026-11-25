#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:?}" "${INSTANCE_ID:?}" "${SSM_DOCUMENT:?}" "${LOG_GROUP:?}"
parameters=()
if [[ $# -gt 0 ]]; then
  parameters=(--parameters "$1")
fi
export AWS_PAGER=""
export AWS_MAX_ATTEMPTS=3
logging=$(jq -nc --arg group "$LOG_GROUP" '{CloudWatchLogGroupName: $group, CloudWatchOutputEnabled: true}')
command_id=$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" \
  --document-name "$SSM_DOCUMENT" "${parameters[@]}" --timeout-seconds 90 \
  --cloud-watch-output-config "$logging" --query 'Command.CommandId' --output text)
printf 'Waiting for SSM command %s. CloudWatch log group: %s\n' "$command_id" "$LOG_GROUP"

for attempt in {1..210}; do
  if status=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$command_id" \
    --instance-id "$INSTANCE_ID" --query Status --output text 2>&1); then
    case "$status" in
      Success) printf 'SSM command %s passed rollout and smoke checks.\n' "$command_id"; exit 0 ;;
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
