#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# This is intentionally destructive only to the named demo container/volume.
docker compose down -v
docker compose up -d
docker compose ps
