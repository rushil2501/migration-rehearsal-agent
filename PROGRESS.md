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
- The staging verification runs direct SQL against the renamed table and the
  actual cloned view separately. Direct `o.status` SQL errors; PostgreSQL
  rewrites the dependent view and retains its output column `status`. This
  corrects the original spec's mistaken claim that the view itself must fail.
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
  sandbox capability enabled, and has OpenAI models configured.
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
- Read-only database validation passed: `users` had 300 rows, `orders` had 500
  rows, and the starting `orders_view` selected `o.status`. The staging rename
  later demonstrated the direct-query failure and preserved view output.
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
- The next user-run rehearsal reported a complete code scan of 3/3 fixture
  files, with actual file/line findings, plus the expected staging migration,
  direct-query failure, and cloned-view success. This confirms the Code Mode
  source retrieval path worked in that run. Review found one classification
  error: `sql/report_queries.sql:7` was marked a high-confidence direct
  unqualified table reference, but its SQL statement is `SELECT ... status ...
  FROM orders_view;` and therefore uses the view output. The separate
  `src/orders_view_queries.py:4` finding was correctly identified as a view
  output reference. The direct table findings at `sql/report_queries.sql:2,4`
  and `src/orders_queries.py:14,25` are valid. Updated the prompt to split SQL
  into statements, bind aliases and unqualified columns only within each
  statement, and keep view-output references distinct from direct breakages.
  The current reported recommendation to update direct application SQL before
  production apply remains correct. No approval was given in this review.
- Updated the project model setting to TrueForge's configured
  `openai/gpt-5-6-sol` ID in ignored `.env` and tracked `.env.example`, then
  republished the saved agent manifest. New sessions should use this model;
  existing sessions retain their original agent configuration.
- The latest user-run report after the statement-level classification update
  showed 4 repository files enumerated and 3 in-scope source files read, with
  no unreadable or limit-skipped source. It correctly separated 3 affected
  direct SQL statements from 2 `orders_view` output references and classified
  `status: str` as ambiguous. The `staging` rename succeeded, the direct query
  failed with SQLSTATE 42703, the cloned view passed, and the production
  approval gate was reached. The user has not reported approving that gate.
  Minor report precision issues remain: the `src/orders_queries.py` SELECT
  was cited at line 13 (opening string) instead of line 14 (the actual
  `o.status`), and "three references" should say "three affected statements,
  four old-column occurrences" because the SQL report query uses `o.status`
  in both SELECT and WHERE.
- Published the project as a PUBLIC GitHub repository at
  `https://github.com/rushil2501/migration-rehearsal-agent` with `main` as its
  default branch. Verified the remote `main` commit matches local `d356511`
  immediately after creation. `.env` is ignored, has never been tracked, and
  a history scan found no GitHub token, OpenAI key, or ngrok tunnel URL pattern.

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
    ├── upsert-connectors.sh
    └── upsert-agent.sh
```

## Remaining work

1. Optional report precision: ask the agent to anchor each finding to the
   exact line containing the old column and to count affected statements
   separately from individual old-column occurrences.
2. For demo evidence, confirm the TrueForge UI visibly shows a PostgreSQL MCP
   call, sandbox script execution, and the enforced production approval pause
   as distinct events. The latest report text alone does not prove UI events.
3. Reset the fixture before another identical run. The original submission
   checklist calls for two full end-to-end rehearsals before the live demo;
   the latest user-run report stopped at the approval gate, while an earlier
   configuration did complete a production apply.
4. Submission packaging: the project repository is public, but the default
   GitHub code-scan fixture is private. A stranger following the README cannot
   access that fixture without being granted permission. Make the fixture
   publicly accessible or include a self-contained way to create an equivalent
   fixture before claiming the README works from a fresh clone. Changing the
   fixture's visibility requires the user's decision.

## Assumptions and risks to verify

- The original spec's sample AgentManifest shape differs from the installed
  TrueForge API. `upsert-agent.sh` uses the accepted nested `manifest` wrapper
  and has successfully updated the saved agent repeatedly.
- `crystaldba/postgres-mcp` exposes `execute_sql`, already verified in the
  connector tool list and live runs.
- The sandbox has no direct network egress in this workflow. Code Mode routes
  read-only GitHub MCP calls through the TrueForge harness; it must never call
  the PostgreSQL connector from the sandbox or receive the GitHub token.
- The container image may require a platform pull on the first Docker run.
- The live ngrok URL is in ignored `.env`; do not commit it. The saved agent
  has run multiple rehearsals, including one approved production apply under
  an earlier configuration.

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
