#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/sf/bin:${HOME}/.local/sf/bin:${PATH}"

cd "$(dirname "$0")/.."

if [[ -n "${SFDX_AUTH_URL:-}" ]]; then
  echo "==> Authorizing Salesforce org from SFDX_AUTH_URL"
  printf '%s' "$SFDX_AUTH_URL" | sf org login sfdx-url \
    --sfdx-url-stdin \
    --alias cloud-agent \
    --set-default
  sf org display --target-org cloud-agent
else
  echo "==> No SFDX_AUTH_URL secret set; deploy commands require org authorization"
  echo "    Add SFDX_AUTH_URL to enable sf project deploy start"
fi

echo "==> Start complete"
