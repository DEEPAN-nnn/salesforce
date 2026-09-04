#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/sf/bin:${HOME}/.local/sf/bin:${PATH}"

cd "$(dirname "$0")/.."

echo "==> Verifying Salesforce CLI"
sf --version

echo "==> Installing Salesforce Code Analyzer plugin"
if sf plugins inspect code-analyzer >/dev/null 2>&1; then
  echo "code-analyzer plugin already installed"
else
  sf plugins install @salesforce/plugin-code-analyzer
fi

echo "==> Validating SFDX project structure"
test -f sfdx-project.json
sf project list ignored 2>/dev/null || true

echo "==> Running static analysis on metadata"
sf code-analyzer run \
  --workspace force-app \
  --rule-selector Recommended \
  --view table

echo "==> Install complete"
