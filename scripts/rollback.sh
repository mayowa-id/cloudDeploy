#!/usr/bin/env bash
set -euo pipefail

exec 9>/run/clouddeploy-deployment.lock
flock -n 9 || { echo 'A CloudDeploy deployment or rollback is already running.' >&2; exit 1; }

k3s kubectl -n clouddeploy rollout undo deployment/clouddeploy-api
k3s kubectl -n clouddeploy rollout status deployment/clouddeploy-api --timeout=150s
