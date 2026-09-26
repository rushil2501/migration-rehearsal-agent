#!/usr/bin/env bash
set -euo pipefail

# Create the two logical aliases required for distinct approval policies. They
# intentionally share one remote MCP URL and hold no credentials.
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi
: "${TRUEFORGE_URL:=http://localhost:8790}"
: "${NGROK_MCP_URL:?Set NGROK_MCP_URL in .env (include the /sse path).}"

settings_url="$TRUEFORGE_URL/api/v1/settings/mcp-servers"
for connector_name in postgres-staging postgres-production; do
  payload="$(jq -cn \
    --arg name "$connector_name" \
    --arg url "$NGROK_MCP_URL" \
    --arg description "PostgreSQL MCP alias for the migration rehearsal demo." \
    '{manifest: {type: "remote", name: $name, url: $url, description: $description}}')"
  curl --fail --silent --show-error -X POST "$settings_url" \
    -H 'Content-Type: application/json' \
    --data "$payload" >/dev/null
  echo "Created $connector_name."
done
