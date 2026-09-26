# Migration Rehearsal Agent

A focused TrueForge hackathon demo. It inventories PostgreSQL dependencies,
rehearses one schema migration in a disposable `staging` schema, checks both
direct dependent SQL and the actual cloned view, creates the report through
actual TrueForge sandbox execution, and lets TrueForge pause for human approval
before it changes `public`.

> TrueForge owns the agent loop, MCP tool-calling, the sandbox, and the
> approval-gate mechanism. This repository supplies the migration-rehearsal
> domain logic: what to clone, what check proves the migration is safe, and
> which single step needs a human sign-off.

## Fixed scenario

The production schema contains `users`, `orders`, and `orders_view`.
`orders_view` selects `orders.status`. The agent rehearses:

```sql
ALTER TABLE orders RENAME COLUMN status TO order_status;
```

PostgreSQL accepts the rename. A direct dependent query against
`staging.orders` then fails because `status` no longer exists. PostgreSQL can
rewrite the actual view dependency to `order_status` while preserving the
view's output name as `status`, so the agent checks and reports those two cases
separately before requesting approval to run the same statement against
`public.orders`.

## Prerequisites

- Docker Desktop and Docker Compose
- [ngrok](https://ngrok.com/) authenticated locally
- Node.js 22.14 or later for TrueForge
- `curl`, [`jq`](https://jqlang.org/), and Ruby (bundled with current macOS)
- A model provider configured in TrueForge

## Start the demo database and MCP server

```bash
cd migration-rehearsal-agent
cp .env.example .env
docker compose up -d
docker compose ps
ngrok http 8000 --request-header-add "ngrok-skip-browser-warning: true"
```

Keep ngrok running and copy its HTTPS forwarding URL into `NGROK_MCP_URL` in
`.env`. Do not commit `.env`: its ngrok URL changes on every restart.

The Compose fixture initializes exactly 300 `users`, 500 `orders`, and the
dependent view. To recreate it from a known state before a rehearsal:

```bash
./scripts/reset-demo.sh
```

That command removes only the Compose-managed `migration-demo` fixture and its
volume, then creates a fresh fixture from `db/init.sql`.

## Configure TrueForge

Start TrueForge in a second terminal:

```bash
npx @truefoundry/trueforge@latest --port 8790
```

At `http://localhost:8790` configure a model provider, then add **two Remote
MCP Server connectors** under **Settings → Connectors**. Both use the same
HTTPS ngrok URL and require no authentication:

| Connector name | URL | Agent use |
| --- | --- | --- |
| `postgres-staging` | `${NGROK_MCP_URL}` | disposable clone, rehearsal, verification |
| `postgres-production` | `${NGROK_MCP_URL}` | final public-schema apply only |

The duplicate connectors are intentional. They point at the same physical
MCP server but let the agent manifest give the production alias a distinct,
enforced approval rule.

Set `TRUEFORGE_MODEL` in `.env` to the configured model identifier shown by
`GET http://localhost:8790/api/v1/models`. Register the git-backed migration
evidence skill from this public repository, then apply the agent manifest:

```bash
./scripts/upsert-skill.sh
./scripts/upsert-agent.sh
```

The script checks whether the saved agent exists, then creates or updates it
through the TrueForge API. The manifest attaches `execute_sql` to the
`postgres-production` alias with `require_approval_for_tools: [execute_sql]`.
This setting is preserved in source because it needs API-level configuration.
The attached [migration evidence skill](skills/migration-rehearsal-evidence/SKILL.md)
contains reusable source-classification and report rules. TrueForge loads it
through the sandbox when relevant; the manifest keeps the ordered workflow and
approval policy.

Also connect the built-in **GitHub** connector with read access to the source
repository. The agent enables only `get_file_contents`; it does not receive
GitHub write tools. For the included test
fixture, authorize access to
`rushil2501/migration-rehearsal-code-scan-fixture` on its `main` branch.

If your installed TrueForge exposes a newer API shape, open
`http://localhost:8790/api/v1/docs`, compare the Create/Update Agent request
schema, and adjust only the outer request wrapper in `scripts/upsert-agent.sh`.
The nested `manifest` is the source of truth.

## Run the agent

Open the **migration-rehearsal-agent** in the TrueForge chat UI and send:

```text
Rehearse the fixed migration: ALTER TABLE orders RENAME COLUMN status TO order_status;
```

The visible sequence must be:

1. The agent loads its migration evidence skill, parses the requested rename,
   and derives the old table/column
   identifiers. A TrueForge Code Mode script walks the configured repository
   through the authenticated GitHub MCP connector, reads the source bodies,
   and reports file/line findings plus scan coverage. It marks missing source
   or exceeded scan limits as partial or unavailable.
2. `postgres-staging` MCP inventories dependencies, clones, and alters the
   staging tables.
3. The staging MCP checks both direct `o.status` SQL and the actual cloned view.
4. TrueForge runs a generated Python report script in its sandbox. It uses the
   code-scan results and database MCP results gathered earlier; it never has
   database credentials or direct network access. Code Mode GitHub calls are
   bridged through the TrueForge harness, which holds the connector credential.
5. The agent repeats the sandbox report visibly in chat, including the
   GitHub findings, dependency list, direct-query error, actual view result, and
   recommendation.
6. TrueForge pauses on the `postgres-production.execute_sql` approval request.
7. Approving it applies the exact rename to `public.orders`.

Everything before the production apply is disposable: a staging clone and a
sandboxed check. The production apply is the only irreversible step, so it is
the only one that pauses.

## Demo notes

In the TrueForge segment, point to three separate UI events: the staging MCP
call, the sandbox script execution, and the approval pause. If you approve on
the disposable fixture, reset it before repeating the demo.

For a three-minute video, open the self-contained
[90-second slide deck](demo/presentation.html) and follow the
[video run-of-show](demo/README.md). The deck covers the problem, architecture,
and observed result in three slides; the remaining 90 seconds show the actual
TrueForge session.

## Repository layout

| Path | Purpose |
| --- | --- |
| `compose.yaml` | PostgreSQL and `crystaldba/postgres-mcp` local stack |
| `db/init.sql` | exact schema and deterministic 300/500-row seed |
| `manifests/agent-manifest.yaml` | source-controlled TrueForge agent configuration and instructions |
| `scripts/upsert-agent.sh` | API create/update helper for the approval configuration |
| `scripts/upsert-skill.sh` | register the git-backed migration evidence skill |
| `scripts/reset-demo.sh` | fresh demo fixture reset |
| `skills/migration-rehearsal-evidence/SKILL.md` | reusable evidence classification and reporting runbook |
| `demo/presentation.html` | self-contained three-slide video presentation |
| `demo/README.md` | three-minute recording sequence and presenter instructions |
| `PROGRESS.md` | complete handoff context and current implementation state |

## AI-assistant disclosure

This project was implemented with OpenAI Codex as an AI coding assistant.
The author reviewed the generated configuration, prompts, and documentation.
