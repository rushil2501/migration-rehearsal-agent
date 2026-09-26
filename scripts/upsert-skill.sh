#!/usr/bin/env bash
set -euo pipefail

# Register the public, git-backed runbook in local TrueForge. Publish changes to
# main before running this script so the skill source is available to the harness.
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi
: "${TRUEFORGE_URL:=http://localhost:8790}"

payload="$(jq -cn \
  --arg name 'migration-rehearsal-evidence' \
  --arg url 'https://github.com/rushil2501/migration-rehearsal-agent' \
  --arg path 'skills/migration-rehearsal-evidence' \
  --arg ref 'main' \
  --arg description 'Use for PostgreSQL column-rename rehearsals to classify source references and report staging evidence before production approval.' \
  '{manifest: {type: "git", name: $name, url: $url, path: $path, ref: $ref, description: $description}}')"

curl --fail --silent --show-error -X PUT "$TRUEFORGE_URL/api/v1/settings/skills" \
  -H 'Content-Type: application/json' \
  --data "$payload"
echo
echo 'Registered migration-rehearsal-evidence skill.' >&2
