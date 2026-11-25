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

work=$(mktemp -d)
export KUBECONFIG="$work/kubeconfig"
cleanup() {
  kind delete cluster --name "$cluster" || true
  rm -rf -- "$work"
}
trap cleanup EXIT

k() { kubectl --context "$context" "$@"; }
kind create cluster --name "$cluster" --image "$node_image" --wait 120s
kind load docker-image clouddeploy:local --name "$cluster"
k apply -f kubernetes/namespace.yaml
k apply --dry-run=server -f kubernetes/
k apply -f kubernetes/configmap.yaml -f kubernetes/service.yaml

export CLOUDDEPLOY_TEST_WORK="$work" CLOUDDEPLOY_TEST_CONTEXT="$context"
export CLOUDDEPLOY_STATE_DIR="$work/state" CLOUDDEPLOY_LOCK_FILE="$work/deploy.lock"
export CLOUDDEPLOY_CONFIG="$work/config.json" CLOUDDEPLOY_SMOKE_TEST="$work/bin/smoke"
mkdir "$work/bin"
printf '%s\n' '{"bucket":"kind-fixture","region":"kind-fixture"}' > "$CLOUDDEPLOY_CONFIG"

# Adapt the AWS host boundaries while keeping apply, rollout, and HTTP checks real.
cat > "$work/bin/cloud-init" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$work/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == s3api && $2 == get-object && $5 == --key ]]
key=$6
cp -- "$CLOUDDEPLOY_TEST_WORK/${key#releases/}" "${@: -1}"
EOF
cat > "$work/bin/k3s" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == kubectl ]]
shift
exec kubectl --context "$CLOUDDEPLOY_TEST_CONTEXT" "$@"
EOF
cat > "$CLOUDDEPLOY_SMOKE_TEST" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="$CLOUDDEPLOY_TEST_WORK/port-forward.log"
kubectl --context "$CLOUDDEPLOY_TEST_CONTEXT" -n clouddeploy port-forward \
  --address 127.0.0.1 service/clouddeploy-api :3000 > "$log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for attempt in {1..15}; do
  port=$(sed -nE 's/^Forwarding from 127\.0\.0\.1:([0-9]+) -> .*/\1/p' "$log")
  if [[ -n "$port" ]]; then
    bash scripts/smoke-test.sh "http://127.0.0.1:$port" "$2"
    exit
  fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
cat "$log" >&2
exit 1
EOF
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

good=$(printf 'a%.0s' {1..40})
bad=$(printf 'b%.0s' {1..40})
mkdir "$work/$good" "$work/$bad"
k patch --local -f kubernetes/deployment.yaml --type strategic -o yaml \
  --patch "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"api\",\"env\":[{\"name\":\"APP_COMMIT\",\"value\":\"$good\"}]}]}}}}" \
  > "$work/$good/manifests.yaml"
k patch --local -f "$work/$good/manifests.yaml" --type strategic -o yaml \
  --patch "{\"spec\":{\"progressDeadlineSeconds\":20,\"template\":{\"spec\":{\"containers\":[{\"name\":\"api\",\"env\":[{\"name\":\"APP_COMMIT\",\"value\":\"$bad\"}],\"readinessProbe\":{\"httpGet\":{\"path\":\"/invalid-readiness\"}}}]}}}}" \
  > "$work/$bad/manifests.yaml"

bash scripts/deploy.sh "$good"
if bash scripts/deploy.sh "$bad" > "$work/recovery.log" 2>&1; then
  cat "$work/recovery.log"
  echo 'The broken release unexpectedly succeeded.' >&2
  exit 1
fi
cat "$work/recovery.log"
grep -Fq 'exceeded its progress deadline' "$work/recovery.log"
grep -Fxq "Restored and verified release $good." "$work/recovery.log"
diff -u <(printf '%s\n\n' "$good") "$CLOUDDEPLOY_STATE_DIR/verified"
actual=$(k -n clouddeploy get deployment clouddeploy-api \
  -o 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="APP_COMMIT")].value}')
[[ "$actual" == "$good" ]]
"$CLOUDDEPLOY_SMOKE_TEST" '' "$good"
