#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

cluster=clouddeploy-ci
context="kind-$cluster"
node_image=${CLOUDDEPLOY_KIND_NODE_IMAGE:-kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed}
if kind get clusters | grep -Fxq "$cluster"; then
  echo "Cluster $cluster already exists." >&2
  exit 1
fi

port_forward_pid=
work=$(mktemp -d)
export KUBECONFIG="$work/kubeconfig"
port_forward_log="$work/port-forward.log"
cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" 2>/dev/null || true
    wait "$port_forward_pid" 2>/dev/null || true
  fi
  kind delete cluster --name "$cluster" || true
  rm -rf -- "$work"
}
trap cleanup EXIT

k() { kubectl --context "$context" "$@"; }
kind create cluster --name "$cluster" --image "$node_image" --wait 120s
kind load docker-image clouddeploy:local --name "$cluster"
k apply -f kubernetes/namespace.yaml
k apply --dry-run=server -f kubernetes/
k apply -f kubernetes/configmap.yaml -f kubernetes/deployment.yaml -f kubernetes/service.yaml
k -n clouddeploy rollout status deployment/clouddeploy-api --timeout=120s

k -n clouddeploy port-forward --address 127.0.0.1 service/clouddeploy-api :3000 >"$port_forward_log" 2>&1 &
port_forward_pid=$!
port=
for attempt in {1..30}; do
  port=$(sed -nE 's/^Forwarding from 127\.0\.0\.1:([0-9]+) -> .*/\1/p' "$port_forward_log")
  [[ -n "$port" ]] && break
  kill -0 "$port_forward_pid" 2>/dev/null || break
  sleep 1
done
if [[ -z "$port" ]]; then
  cat "$port_forward_log" >&2
  exit 1
fi
bash scripts/smoke-test.sh "http://127.0.0.1:$port" local
