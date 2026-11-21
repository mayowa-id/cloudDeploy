#!/usr/bin/env bash
set -euo pipefail

version=$1
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
curl_args=(--fail --silent --show-error --location --retry 5 --connect-timeout 15 --max-time 180)

# Configure the node before starting it.
printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-clouddeploy.conf
sysctl -p /etc/sysctl.d/99-clouddeploy.conf

curl "${curl_args[@]}" https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o "$work/awscliv2.zip"
unzip -q "$work/awscliv2.zip" -d "$work"
"$work/aws/install" --update
aws --version

curl "${curl_args[@]}" "https://raw.githubusercontent.com/k3s-io/k3s/$version/install.sh" -o "$work/install-k3s.sh"
INSTALL_K3S_VERSION="$version" sh "$work/install-k3s.sh" server

if systemctl cat amazon-ssm-agent.service >/dev/null 2>&1; then
  systemctl enable --now amazon-ssm-agent.service
else
  if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
    snap install amazon-ssm-agent --classic
  fi
  snap start --enable amazon-ssm-agent
fi

for attempt in $(seq 1 30); do
  if k3s kubectl get --raw='/readyz' --request-timeout=5s >/dev/null 2>&1; then
    k3s kubectl wait --for=condition=Ready node --all --timeout=180s
    exit 0
  fi
  sleep 5
done

echo 'K3s API did not become ready.' >&2
exit 1
