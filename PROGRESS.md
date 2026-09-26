# Implementation handoff

Last updated: 2026-09-26 (Asia/Kolkata)

## Goal

Implement the fixed Migration Rehearsal Agent specified in
`../migration-rehearsal-agent-implementation-spec.md`. The hackathon rubric
requires visible proof that TrueForge, rather than custom application code,
performs (1) MCP tool calling to a real PostgreSQL database, (2) generated
script execution in its sandbox, and (3) a real human approval pause before
the production database change.

## Scope constraints

- Support exactly `ALTER TABLE orders RENAME COLUMN status TO order_status;`.
- Public schema: `users`, `orders`, and `orders_view`, which selects
  `orders.status`.
- The staging verification must reproduce the view query against staging tables
  after the rename; it must error because `o.status` is absent.
- The sandbox does no direct network/database work. The Code Mode script calls
  the read-only GitHub MCP connector through TrueForge's harness bridge; MCP
  credentials stay in the harness. The report script uses already gathered
  GitHub-scan and database MCP results.
- Use two TrueForge connector aliases to the same MCP server: un-gated
  `postgres-staging` and approval-gated `postgres-production`.
- The sole gate is the final production `public.orders` ALTER. The agent must
  request it even after finding the break; the human decides with evidence.
- Do not add custom UI, arbitrary-migration support, auth, cloud deployment,
  migration history, or rollback features.

## Completed

- Created this standalone folder under `/Users/rushil/workspace`.
- Added `compose.yaml` for PostgreSQL 16 and `crystaldba/postgres-mcp` over SSE
  on port 8000. MCP connects over the Compose network, avoiding platform-
  dependent `host.docker.internal` behavior.
- Added exact schema plus deterministic 300-user/500-order fixture in
  `db/init.sql`. It retains ~5% NULL statuses.
- Added a manifest with the prescribed agent instructions, sandbox enabled,
  and the dual MCP alias approval policy.
- Added create-or-update and fixture-reset scripts.
- Added a fresh-clone README including setup, architecture, demo instructions,
  credential precautions, and AI disclosure.
- Added `.gitignore` for secrets and local data.
- Confirmed the user already has PostgreSQL 16 (`migration-demo`) and
  `crystaldba/postgres-mcp` running. The MCP server is exposed via the ngrok
  SSE endpoint recorded in the ignored `.env` file.
- Confirmed the local TrueForge instance at port 8790 is version 0.2.1, has its
  sandbox capability enabled, and has `openai/gpt-5-5` configured.
- Created the `postgres-staging` and `postgres-production` connector aliases
  through TrueForge Settings API. Both point at the same existing MCP URL and
  report `not_required` authentication.
- Confirmed the source `postgres-mcp` connector exposes `execute_sql`.
- Registered `migration-rehearsal-agent` in TrueForge with immutable ID
  `01m3e4wnjx8h6qt1gq7sfx4097`. The returned live manifest confirms sandbox
  enabled and `require_approval_for_tools: [execute_sql]` only on
  `postgres-production`.
- Updated the live agent to disable dynamic subagents and generative UI, keeping
  the fixed demo narrow. Verified both aliases discover `execute_sql`.
- Read-only database validation passed: `users` has 300 rows, `orders` has 500
  rows, and `orders_view` currently selects `o.status`; it is ready to show the
  failure after the staging rename.
- The live chat completed the rehearsal and displayed the real approval request
  for `postgres-production.execute_sql`; submitting the approval resumed the
  turn successfully.
- The approval was allowed and the production apply completed successfully.
  Both `public.orders` and `staging.orders` now contain `order_status` instead
  of `status`; `users` remains unchanged at 300 rows and `orders` at 500 rows.
  The report correctly preserved the failed dependent-query evidence even
  though the human chose to proceed.
- For a repeat rehearsal, `public.orders.order_status` was restored to
  `public.orders.status` while preserving all 500 rows. `public.orders_view`
  was verified to return rows again. `staging` remains disposable and still
  has `order_status`; the next run will recreate it from public.
- Implemented point 1: the live agent instructions now inventory column-level
  and table-level PostgreSQL dependents before rehearsal, recreate
  `staging.orders_view`, and verify direct dependent SQL separately from the
  actual view. Reports now distinguish a failed direct `o.status` query from a
  view that PostgreSQL rewrites successfully.
- Inspected session `01m3ecx08fed1my6qs2akenpkq`: the new inventory ran, the
  direct `o.status` check returned the expected missing-column error, the
  actual cloned view check passed, and the sandbox JSON contained both results.
  Added an instruction requiring the assistant to repeat that report visibly
  before the approval gate because the first updated run condensed it too much.
- Diagnosed session `01m3edj7xe51d94hsqw2ncw28z`: it is bound to an inline
  legacy agent (`agent.type = inline`) with the single `postgres-mcp` connector,
  not the saved `migration-rehearsal-agent` reference. It ran a public-schema
  transaction and rolled it back, so it did not exercise dependency inventory,
  sandbox reporting, or the production approval gate. A `try_agent_name` URL
  parameter does not rebind an existing session.
- Validated the ignored `.env` `GITHUB_TOKEN` against GitHub successfully as
  user `rushil2501` without printing the token.
- Created private fixture repository
  `https://github.com/rushil2501/migration-rehearsal-code-scan-fixture` on the
  `main` branch. It contains `src/orders_queries.py` and
  `sql/report_queries.sql` with intentional direct `orders.status` findings,
  plus `src/orders_view_queries.py` with a safe `orders_view` query. No token
  or credential was added to the repository.
- Confirmed the TrueForge `github` connector is authenticated and exposes
  `search_code`, `get_file_contents`, and `list_branches`.
- Added the authenticated read-only GitHub connector to the agent manifest.
  The intended workflow scans the fixture repository before database work and
  includes `code_scan` findings in the visible report and sandbox JSON. GitHub
  write tools remain disabled; `postgres-production.execute_sql` remains the
  only approval-gated tool.
- Removed hardcoded `orders.status`/`o.status` code-scan patterns. The agent now
  parses the requested rename migration first and derives table, old-column,
  and new-column search rules. Unsupported migration syntax is reported as
  `code_scan: unsupported_migration` rather than scanned with guessed names.
- Diagnosed session `01m3efcpby47a4dc64ntv9efm2` (saved agent reference,
  second turn pending production approval): GitHub search returned
  `incomplete_results: true` with zero items despite the fixture being
  listable. Direct `get_file_contents` of individual files put only
  `successfully downloaded text file (SHA: ...)` acknowledgments into the
  assistant-visible tool response. The agent incorrectly looked for files in
  the sandbox, where none were written, and marked the scan unavailable. The
  staging clone, migration, direct-SQL failure, and cloned-view success were
  otherwise correct. No production approval was given in this session.
- Updated the manifest to use TrueForge Code Mode for GitHub file retrieval and
  scan. A sandbox Python script calls `github.get_file_contents` through
  `mcp_client`, where the full MCP result can expose the embedded `resource`
  block containing source text. It walks repository directories instead of
  relying on GitHub search, ignores the acknowledgment and download URLs,
  records file/line findings and coverage, and marks unreadable or skipped
  source as partial/unavailable. Only `get_file_contents` is enabled on the
  GitHub connector. TrueForge documents that Code Mode MCP calls are bridged
  through the harness with credentials kept out of the sandbox:
  https://trueforge.dev/key-features/code-mode . GitHub documents the
  acknowledgment plus embedded resource response format:
  https://github.com/github/github-mcp-server/issues/607 .

## Current filesystem

```text
migration-rehearsal-agent/
├── .env.example
├── .gitignore
├── README.md
├── PROGRESS.md
├── compose.yaml
├── db/init.sql
├── manifests/agent-manifest.yaml
└── scripts/
    ├── reset-demo.sh
    └── upsert-agent.sh
```

## Outstanding execution work

1. Apply the updated manifest with `./scripts/upsert-agent.sh`. Start a NEW
   saved-agent session for the next rehearsal; existing sessions keep their
   original agent configuration. Confirm the Code Mode output includes actual
   source-backed file/line findings and `files_scanned > 0`. If it still
   reports an acknowledgment without a `resource.text` body, inspect the
   full Code Mode result shape and adapt the reader; do not claim a clean scan.
2. Confirm the sandbox execution event is visibly distinct from the staging
   MCP event in the chat transcript.
3. Reset the fixture to its original seed state before another identical run,
   then complete a second end-to-end rehearsal before the presentation.

## Assumptions and risks to verify

- The spec says an AgentManifest YAML is accepted by `GET/PUT /api/v1/agents`.
  Current TrueForge documentation also describes an API request with a `name`
  plus nested `manifest`; `upsert-agent.sh` uses that current wrapper. Inspect
  the local `/api/v1/docs` before first use. If it differs, change only the
  `payload` construction in that script.
- `crystaldba/postgres-mcp` must expose the SQL tool as `execute_sql`, as the
  specification states. Verify this in the connector tool list before applying
  the manifest.
- The sandbox has no direct network egress in this workflow. Code Mode routes
  read-only GitHub MCP calls through the TrueForge harness; it must never call
  the PostgreSQL connector from the sandbox or receive the GitHub token.
- The container image may require a platform pull on the first Docker run.
- The environment is active. The only source addition carrying its live ngrok
  URL is `.env`, which is gitignored. The agent is registered and ready for its
  first end-to-end UI run.

## Handoff commands

```bash
cd /Users/rushil/workspace/migration-rehearsal-agent
cp .env.example .env
docker compose up -d
ngrok http 8000 --request-header-add "ngrok-skip-browser-warning: true"
npx @truefoundry/trueforge@latest --port 8790
./scripts/upsert-agent.sh
```

## Key architecture statement

“TrueForge owns the agent loop, MCP tool-calling, the sandbox, and the
approval-gate mechanism. My code is the migration-rehearsal domain logic on top
of it: what to clone, what check proves the migration is safe, and which single
step — applying to production — needs a human's sign-off.”
