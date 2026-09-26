#!/usr/bin/env bash
set -euo pipefail

# This script intentionally reads the currently saved agent before replacing it,
# as required for API-only approval settings. macOS's bundled Ruby converts the
# human-readable YAML manifest to JSON, so no package installation is needed.
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi
: "${TRUEFORGE_URL:=http://localhost:8790}"
: "${TRUEFORGE_MODEL:?Set TRUEFORGE_MODEL in .env to a configured TrueForge model ID.}"

manifest_file="$project_dir/manifests/agent-manifest.yaml"
# The manifest is deliberately kept as readable YAML. Render the one local
# setting before converting it to the JSON accepted by the TrueForge API.
rendered_manifest="$(sed "s|\${TRUEFORGE_MODEL}|$TRUEFORGE_MODEL|g" "$manifest_file")"
manifest="$(printf '%s' "$rendered_manifest" | ruby -r yaml -r json -e 'puts JSON.generate(YAML.safe_load(STDIN.read))')"
agent_name="migration-rehearsal-agent"
description="Rehearses the fixed orders.status rename in a disposable staging schema and pauses for approval before production apply."
agents_url="$TRUEFORGE_URL/api/v1/agents"
existing="$(curl --fail --silent --show-error "$agents_url?agent_name=$agent_name" || true)"
agent_id="$(printf '%s' "$existing" | jq -r --arg name "$agent_name" '.data[]? | select(.name == $name) | .id' | head -n 1)"

if [[ -n "$agent_id" ]]; then
  payload="$(jq -cn --arg description "$description" --argjson manifest "$manifest" '{description: $description, manifest: $manifest}')"
  agent_url="$agents_url/$agent_id"
  curl --fail --silent --show-error -X PUT "$agent_url" \
    -H 'Content-Type: application/json' \
    --data "$payload"
  echo
  echo 'Updated migration-rehearsal-agent.' >&2
else
  payload="$(jq -cn --arg name "$agent_name" --arg description "$description" --argjson manifest "$manifest" '{name: $name, description: $description, manifest: $manifest}')"
  curl --fail --silent --show-error -X POST "$agents_url" \
    -H 'Content-Type: application/json' \
    --data "$payload"
  echo
  echo 'Created migration-rehearsal-agent.' >&2
fi
