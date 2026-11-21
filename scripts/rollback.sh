#!/usr/bin/env bash
set -euo pipefail

exec /usr/local/bin/clouddeploy-deploy --rollback
