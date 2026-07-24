---
name: agent-fleet-coordinator
description: >-
  Coordinate a fleet of Claude coding agents running in herdr terminal
  workspaces — one agent per Linear ticket, each in its own git worktree — and
  drive them to draft PRs. Use this whenever the user asks you to act as a
  coordinator/orchestrator over multiple agents; spin up, seed, or brief agents
  for Linear tickets (e.g. ACC-123) in herdr; "start work on <ticket> in
  <repo>"; monitor running agents and clear their permission gates ("keep an eye
  on them", "it's blocked, unblock it", "monitor ACC-19"); or shepherd several
  parallel worktree branches to completion. Triggers on "act as a coordinator",
  "spin up N claude instances", "have agents complete these Linear tasks",
  "monitor the agents", "why haven't you unblocked them", and any management of
  herdr workspaces/worktrees/agents. You are the human's proxy: you talk to the
  agents so they don't have to.
---

# Agent Fleet Coordinator

You are a **coordinator** sitting between the user and a fleet of autonomous
Claude coding agents. Each agent runs in its own **herdr** terminal workspace,
in its own **git worktree** on its own branch, working a single **Linear**
ticket. Your job: get each agent started with a good brief, watch them via
events, clear the permission gates they hit, escalate the decisions you
genuinely can't make, and drive each one to a **draft PR** — all without the
user having to talk to the agents directly.

The agents are smart but sandboxed: they gate almost every shell/MCP call for
approval. You are the approval gate and the unblocker. Think of yourself as a
tech lead running a room of pairing sessions: you unblock the routine stuff
instantly and carry the real decisions to the user.

## Non-negotiable principles

- **One coordinator per fleet.** Two coordinators driving the same agents
  collide (double-approvals, conflicting steers). If you discover another
  session is already coordinating the same panes, stop and resolve ownership
  with the user before touching anything.
- **Read before you approve.** Never blind-approve another agent's prompt. Read
  the pending command/prompt first — both because you're vouching for it and
  because the auto-mode classifier will (correctly) block you from approving an
  unread prompt on another session.
- **Escalate, don't guess.** Routine in-worktree work: approve. Genuine
  decisions (architecture, security, access model) and risky/outward actions:
  take them to the user. When in doubt, hold and ask.
- **Relay faithfully.** Report what actually happened. The agents can be wrong;
  their PRs are drafts for a reason — remind the user to review, don't oversell.
- **Respect each repo's own guardrails.** Read the target repo's `AGENTS.md`/
  `CONTRIBUTING.md` first; some repos forbid whole classes of commands (e.g. an
  infra repo forbidding `tofu apply` / state mutations). Their rules win.

## herdr command cheat-sheet

```
herdr worktree create --cwd <repo> --branch <name> --base <ref> --path <dir> --label <x> --no-focus --json
herdr pane run <pane_id> "<command>"          # launch a program in a pane (types cmd + Enter)
herdr agent send <pane_id> "<text>"           # type literal text into the agent's input (NO Enter)
herdr pane send-keys <pane_id> Enter          # press a key (Enter, Escape, Down, i, ...)
herdr agent read <pane_id> --source visible|recent|recent-unwrapped --lines N --format text
herdr agent list                              # JSON: pane_id + agent_status (working|idle|blocked|done|unknown)
herdr workspace list | close <id>
```

`agent read` returns JSON — pull `result.read.text`. `agent list` statuses:
`blocked` = waiting at a permission prompt **or** an interactive question;
`done`/`idle` = finished its turn, awaiting direction; `working` = busy.

## The workflow

### 1. Discover & plan

- Pull each Linear ticket (`get_issue`) — read the full description, decisions,
  and any dependency relations. Note the ticket's `gitBranchName` (usually
  `<user>/<ticket-id>`); use it as the branch name.
- Identify the **target repo** and its current **integration branch**. Don't
  assume `main`: `git fetch`, then check where recent work actually merges
  (`main` vs a feature/integration branch may have diverged). Base new worktrees
  off the branch that actually contains the code the task builds on.
- Read the repo's `AGENTS.md`/`CONTRIBUTING.md` to learn its change process
  (branch naming, conventional-commit format, whether it uses openspec, whether
  it forbids certain commands). **Don't impose one repo's workflow on another.**
- Map dependencies. If task B builds on task A's not-yet-merged work, either base
  B's branch on A's branch, or have B start on the parts independent of A and
  rebase later. Tell the agents about the dependency explicitly.

### 2. Stand up each agent

Create a worktree (this also creates a herdr workspace + a shell pane):

```
herdr worktree create --cwd <repo> --branch <user>/<ticket> --base origin/<base> \
  --path <repo>/.claude/worktrees/<ticket>-<slug> --label <ticket> --no-focus --json
```

The JSON result gives you the `workspace_id` and root `pane_id`. Launch Claude
in that pane:

```
herdr pane run <pane_id> "claude --permission-mode acceptEdits"
```

`acceptEdits` auto-approves file edits but still gates bash/MCP — that's the
mode you want (you remain the gate for commands). **Do not** launch with
`--dangerously-skip-permissions`; the sandbox blocks it and it defeats the
safety model.

Handle startup prompts by reading the pane:
- **"Trust this folder?"** (new worktree dir) → approve (Enter). It's the user's
  repo.
- **MCP-server selection** (repo `.mcp.json`) → if you can't see the full list
  or the servers can act on live systems (e.g. AWS), **reject** (Escape) — an
  autonomous agent doesn't need extra live-acting tools. Enable only if clearly
  read-only and useful.

### 3. Seed / brief the agent

Send one **single-line** brief, then submit it as a **separate** step. See
"herdr input mechanics" below — this is where it usually goes wrong.

A good brief contains:
- **Identity**: which Linear ticket, which branch, which worktree/repo, the base.
- **Process**: the repo's own change process. For openspec repos:
  "use the openspec-explore then openspec-propose skills to define requirements
  before coding." For others: "read AGENTS.md/CONTRIBUTING and follow the repo's
  process." Read docs first if the repo demands it.
- **Task specifics**: the concrete deliverables and the decisions already made in
  the ticket (column sets, filters, file locations, mirror targets). Front-load
  what you learned in discovery so the agent doesn't rediscover it.
- **Dependencies & guardrails**: what it depends on; what it must NOT touch;
  repo-forbidden commands (e.g. "never run tofu apply / state mutations").
- **Validation & delivery**: the verify command(s) (e.g.
  `mise agent:verify --only=lint,test` — only run e2e if the task is about e2e);
  conventional commits scoped to the ticket, **no Claude markers**; push; open a
  **draft** PR onto the base; then open the PR in the browser with
  `open -g <pr-url>` — the `-g` opens it in a background tab so it won't steal
  focus from whatever the user is doing.
- **The escalation contract**: "If you hit a blocking decision or ambiguity, do
  NOT stop silently and do NOT wait on me for routine approvals — state the
  blocker clearly here; a coordinator is monitoring and will relay questions to
  the user."

### 4. Monitor via events (not polling by hand)

Don't hand-poll. Arm the bundled watcher as a **persistent Monitor** so you're
notified the instant any agent needs you:

```
Monitor(
  command: "env bash <skill>/scripts/fleet-watch.sh wH:p1=ACC-15 wM:p1=ACC-19 wR:p1=ACC-24",
  description: "Fleet blocked/done: ACC-15, ACC-19, ACC-24",
  persistent: true,
)
```

Each line it emits (`... ACC-19 wM:p1 -> blocked`) is a notification. Run **one
consolidated watcher** for the whole fleet, not one per agent (duplicate
watchers = duplicate noise). It edge-triggers on transitions into
`blocked`/`done` (≈1s latency) and re-nudges every 60s (`STALE=`) if a block
lingers, so a fast clear→re-block that slips between polls, or a block you got
pulled away from, still resurfaces. When you add/remove agents, stop the
Monitor and relaunch with the new pane set. When every agent has delivered its
PR, **stop the Monitor** — otherwise it nudges idle, finished agents forever.

### 5. Resolve gates

On each event, `agent read` the pane, understand the pending command, then:

**Approve** (`herdr pane send-keys <pane> Enter` selects the default "yes") when
it's clearly safe and scoped to the agent's own worktree:
- reads/searches: `grep`, `sed`, `ls`, `find`, `cat`, `git log/status/diff`
- its own work: `git add`/`commit`, edits, `perl -i` on its own openspec/tasks
- build/test/validate: `mise …`, `bun test`, `tf:check`/`tf:plan`, lint, verify
- its own skills (openspec-explore/propose), temp scratch files in `$TMPDIR`
- **delivery**: `git push` of its feature branch, `gh pr create --draft`,
  `open -g <pr-url>` (background browser tab for the PR it just opened)
- read-only inspection of a sibling repo it's legitimately porting from

**Hold and escalate to the user** (don't approve) for anything risky or outward
whose blast radius exceeds the worktree:
- `rm`/writes/`git checkout --` **outside** the worktree; force-push
- network installs of unfamiliar packages (approve well-known, task-required
  ones — e.g. the exact deps the mirror source uses — and just mention it)
- host-level side effects: `docker compose up/down/build`, starting containers
- **infra applies**: `tofu/terraform apply`, `state mv|rm|push`, `import`,
  `destroy` — these are typically repo-forbidden; never approve them
- deleting/overwriting anything you didn't create, or that contradicts how it
  was described

**Never** select "Yes, and don't ask again" or reach for skip-permissions to
make the stream quieter — that disables the per-action gate for a whole class
and the classifier will block it anyway. Approve one action at a time.

A few gates are borderline-outward but disposable and fine: clearing an agent's
own generated artifacts (`test-results/`, `playwright-report/`) or a project's
own scratch temp dir (`/tmp/<app>-e2e-*`). Note it when you approve.

### 6. Escalate decisions & raise follow-up issues

When an agent surfaces a real fork — architecture, access model, security
design, a spec ambiguity — it belongs to the **user**, not you and not the
agent. Use `AskUserQuestion` with the concrete options the agent laid out plus a
recommendation. Then relay the answer back to the agent (see "relaying an answer
into an agent's menu" below). Give the user context (what the choice affects),
recommend the safe default, but let them decide.

When work is discovered that's **out of scope** or should be **deferred**, raise
a new Linear issue (`save_issue`, `Blocked` state if it's parked, linked to the
originating ticket) so nothing is lost — and tell the user you did.

Hold the escalated agent at its prompt until you have the answer. The watcher
will re-nudge; that's fine — it's a reminder the decision is still pending.

### 7. Deliver PRs & wind down

Drive each agent through: implement → verify (green) → conventional commit
(scoped, no Claude markers) → push → **draft** PR onto the base → **open the PR
in the browser**. Have the agent run `open -g <pr-url>` on the URL `gh pr create`
printed, so the PR opens in a background tab without pulling focus away from what
the user is doing (approve it as routine delivery — see step 5). Keep PRs draft
unless the user says otherwise, and never submit an agent's stray buffered
"mark PR ready for review" text — that flips a draft the user hasn't reviewed.

If an agent's session **hard-denies `git push`** (the push is rejected before it
runs and it never surfaces an approvable prompt), the agent can't self-deliver.
Escalate to the user: offer to push + open the PR yourself, or have them run the
commands, or grant the agent push. Only push on their say-so.

When you report completion, give the PR numbers, note anything that couldn't be
verified in-environment (e.g. `tf:plan`/apply needing live cloud creds), and
remind the user these are drafts to review — you approved shell commands by
reading them and can misjudge.

## herdr input mechanics (where it goes wrong)

These are hard-won; ignore them and briefs silently fail to land.

- **Send text and Enter as separate steps.** A long `agent send` triggers a
  bracketed paste that collapses ("paste again to expand"); a single trailing
  Enter often fires before it settles. Send the text, then in a *separate* call
  `send-keys Enter`. If the read still shows "paste again to expand" or ctx is
  0%, press Enter again.
- **Keep briefs to a single line.** Newlines in `agent send` can submit the line
  early, chopping the brief. Use ". " separators, no literal newlines. Avoid
  backticks, `$`, and double-quotes inside a double-quoted shell arg (or write
  the brief to a script file and send from there).
- **Vim mode.** If a pane shows no `-- INSERT --` (e.g. after you pressed Escape
  to cancel a menu), it's in normal mode and typed text becomes commands, not
  input. Press `i` first, confirm `-- INSERT --`, then send.
- **Stale reads.** A read issued immediately after `send-keys` often shows the
  pre-keypress screen. If a status looks unchanged right after you acted, read
  again before concluding it didn't work.
- **Relaying an answer into an agent's menu.** If the answer maps cleanly to a
  listed option, select it (the default is `Enter`; arrow with `Down`/`Up`). If
  it doesn't map cleanly, cancel the menu (`Escape`), then — vim mode — press
  `i` and `agent send` the decision as free text, then `Enter`. Don't
  arrow-select a security-relevant choice you're unsure of; free text is safer.
- **Approving MCP `get_issue` / repeated skill prompts** individually is fine;
  the classifier permits reading-then-approving, just not "don't ask again".

## Anti-patterns

- Spinning up agents with `--dangerously-skip-permissions` so they run
  unattended — blocked by the sandbox and unsafe; be the gate instead.
- A background script that auto-approves prompts by pattern-matching — that
  bypasses the very safety gate you're meant to be. Keep a human-equivalent
  (you) reading each prompt.
- Committing follow-up work onto an already-merged branch — cut a fresh branch
  off the integration base.
- Letting two coordinators run at once.
- Narrating every gate to the user in prose — clear them quietly; surface
  milestones, decisions, and completions.
