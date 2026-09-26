# Three-minute demo video

Open [`presentation.html`](presentation.html) in a browser. It is a single file
with no fonts, images, scripts, or network dependencies. Use a 16:9 browser
window or full screen. Click **Next**, or use the arrow keys or Space. Press
**N** for speaker notes and **F** for full screen; hide notes before recording.

## Recording sequence

| Time | Screen | What to show |
| --- | --- | --- |
| 0:00–0:30 | Slide 1 | The rename succeeds as DDL, while direct `o.status` SQL fails. The actual view still works. |
| 0:30–1:00 | Slide 2 | GitHub code scan → catalog inventory → staging clone → verification and sandbox report → human approval. Point out the two PostgreSQL MCP aliases and the credential boundary. |
| 1:00–1:30 | Slide 3 | Three affected SQL statements, two compatible view references, SQLSTATE 42703, and the recommendation. Transition to the live TrueForge tab. |
| 1:30–1:48 | TrueForge | Show the Code Mode GitHub scan: 3 of 3 in-scope files read, file/line findings. |
| 1:48–2:08 | TrueForge | Show `postgres-staging` MCP events for dependency inventory, staging clone, and rename. |
| 2:08–2:28 | TrueForge | Show the failed direct query and passing cloned view as separate checks. |
| 2:28–2:43 | TrueForge | Show the actual sandbox script execution and its structured JSON report. |
| 2:43–3:00 | TrueForge | Show the enforced `postgres-production.execute_sql` approval pause and make the human decision visible. |

The agent run takes longer than the live-site segment, so open a saved session
that has already reached the approval gate before recording. Keep the same
session visible while moving through its tool events. If you choose **Allow**
for the video, do so only on the disposable demo fixture, explain that you are
intentionally demonstrating the approval mechanism despite the warning, and
reset the fixture afterward. **Deny** is the operationally sound decision for
the unrepaired direct queries.

The notes inside the HTML deck are about 30 seconds per slide. The closing
line for the live segment is: “TrueForge made the MCP calls, ran the sandbox
code, and enforced the approval pause. Our agent supplied the migration checks
and recommendation.”
