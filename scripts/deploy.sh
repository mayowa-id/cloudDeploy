#!/usr/bin/env bash
set -euo pipefail

is_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]]
}

release=${1:-}
if [[ $# != 1 ]] || { [[ "$release" != --rollback ]] && ! is_sha "$release"; }; then
  echo 'Usage: clouddeploy-deploy <40-character lowercase Git SHA | --rollback>' >&2
  exit 2
fi

umask 077
exec 9>/run/clouddeploy-deployment.lock
flock -n 9 || { echo 'A CloudDeploy deployment or rollback is already running.' >&2; exit 1; }
timeout 180 cloud-init status --wait

state_dir=/var/lib/clouddeploy/releases
mkdir -p -- "$state_dir"
current=
previous=
if [[ -e "$state_dir/verified" ]]; then
  mapfile -t verified < "$state_dir/verified"
  current=${verified[0]:-}
  previous=${verified[1]:-}
  if ! is_sha "$current" || [[ ! -s "$state_dir/$current.yaml" ]] ||
    { [[ -n "$previous" ]] && { ! is_sha "$previous" || [[ ! -s "$state_dir/$previous.yaml" ]]; }; }; then
    echo 'CloudDeploy release state is invalid. Inspect it before deploying.' >&2
    exit 1
  fi
fi

temporary_dir=$(mktemp -d -- "$state_dir/.pending.XXXXXX")
cleanup() {
  rm -f -- "$temporary_dir/manifest.yaml" "$temporary_dir/verified"
  rmdir -- "$temporary_dir"
}
trap cleanup EXIT
if [[ "$release" == --rollback ]]; then
  if [[ -z "$previous" ]]; then
    echo 'No previous verified release is available for rollback.' >&2
    exit 1
  fi
  release=$previous
elif [[ "$release" != "$current" && "$release" != "$previous" ]]; then
  config=/etc/clouddeploy/config.json
  bucket=$(jq -er '.bucket' "$config")
  region=$(jq -er '.region' "$config")
  timeout 45 aws s3api get-object --bucket "$bucket" --key "releases/$release/manifests.yaml" \
    --region "$region" "$temporary_dir/manifest.yaml" >/dev/null
  [[ -s "$temporary_dir/manifest.yaml" ]] || { echo 'Release manifest is empty.' >&2; exit 1; }
  mv -T -- "$temporary_dir/manifest.yaml" "$state_dir/$release.yaml"
fi

apply_and_verify() {
  local target=$1 service_ip
  printf 'Applying release %s\n' "$target"
  timeout 45 k3s kubectl apply -f "$state_dir/$target.yaml" || return 1
  timeout 165 k3s kubectl -n clouddeploy rollout status deployment/clouddeploy-api --timeout=150s || return 1
  service_ip=$(timeout 15 k3s kubectl -n clouddeploy get service clouddeploy-api -o jsonpath='{.spec.clusterIP}') || return 1
  [[ -n "$service_ip" && "$service_ip" != None ]] || return 1
  timeout 80 /usr/local/bin/clouddeploy-smoke-test "http://$service_ip:3000" "$target"
}

# Prepare the new release record before making cluster changes.
if [[ "$release" != "$current" ]]; then
  printf '%s\n%s\n' "$release" "$current" > "$temporary_dir/verified"
fi
if apply_and_verify "$release"; then
  if [[ "$release" == "$current" ]] || mv -T -- "$temporary_dir/verified" "$state_dir/verified"; then
    printf 'Verified release %s\n' "$release"
    exit 0
  fi
fi

printf 'Release %s failed.\n' "$release" >&2
if [[ -z "$current" ]]; then
  echo 'No verified release is available to restore.' >&2
elif apply_and_verify "$current"; then
  printf 'Restored and verified release %s.\n' "$current" >&2
else
  printf 'Recovery of release %s failed. Inspect the cluster.\n' "$current" >&2
fi
exit 1
