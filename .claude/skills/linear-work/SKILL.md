---
name: linear-work
description: >-
  Structure work in Linear (Team → Initiative → Project → Issue) so it's
  trackable, auditable, and lands in the right roadmap column. Use whenever
  creating, breaking down, grouping, reorganizing, or classifying
  product/engineering work into initiatives, projects, or issues — even when the
  user names the work by domain (feature, workflow, spike, cleanup, backlog) and
  never says "Linear". Concrete triggers: split a feature into a project with
  issues; set up initiatives/projects; log a spike so it doesn't read as
  committed delivery; tag capitalizable vs maintenance / decide if it's a Paper
  Cut; fix orphaned issues or tidy the backlog; work out what status/dates/owner
  land an item in Now/Next/Later or unstick one stuck in Ideas. Do NOT use to
  merely read/report an existing item, or for Jira, GitHub issues, or writing
  PRDs/planning docs.
---

# Creating work in Linear

Work in Linear exists so that (a) nothing gets done untracked, (b) auditors and
leadership can see what was worked on, and (c) it renders correctly on the
product roadmap. The roadmap is a custom website that pulls live from Linear, so
the way work is structured and dated in Linear *is* how it appears to the board.
Sloppy structure or a vague description doesn't just look untidy — it makes real
work invisible or misleading on the roadmap.

## The hierarchy

Always use four levels:

**Team → Initiative → Project → Issue**

- **Issue** — a concrete, actionable task. If work is being done, it lives in an issue.
- **Project** — the main unit of grouping; a distinct deliverable or work package.
- **Initiative** — the top-level workstream or major delivery phase, grouping related projects.
- **Team** — the owning group.

Two rules that are never bent:
1. Every piece of work belongs to an **Issue**.
2. Every Issue belongs to a **Project** — no standalone issues.

## How to use each level

### Initiative
The broad outcome; a roadmap heading. Groups related projects. Give it a clear
description written in customer/outcome language — this is the text that appears
on the roadmap, so a vague description makes the whole swimlane read poorly.

- Good: `Account Charges V1` — desc: "Customer-facing portal to access institute account charges"
- Bad: `Mark's Work`, `July Tasks`

### Project
A specific deliverable within an initiative. Understandable to engineering,
leadership, and auditors. Focused and clearly named.

Examples inside `Account Charges V1`:
- `Show users their charges`
- `Dispute raising workflow`
- `Wayfinder data sanitization`
- `Consolidation support investigation`

Name by the deliverable/workstream, not the technical area:
- Good: `Show users their charges`, `Dispute raising workflow`
- Bad: `Frontend work`, `Random fixes`

### Issue
A specific task needed to complete a project. Actionable and concrete — someone
reading the issues should see exactly what work was done.

Examples inside `Show users their charges`:
- `Build charges overview screen`
- `Add per-student and per-course views`
- `Add plain-language field descriptions`
- `Connect charges UI to staging data`

Name by the exact task:
- Good: `Add per-student charge view`, `Strip margin fields from browser-bound dataset`
- Bad: `Charges work`, `Do UI`

## Project types (chargeability)

Every project should be clearly one type. This classification drives
investor/board reporting and capitalization treatment, so keep types unmixed —
mixing them makes the accounting ambiguous.

- **Capitalizable** — builds a saleable asset, product capability, or operational
  improvement that increases business value (new customer-facing features,
  automation that removes manual ops work, deliverable functionality).
- **R&D** — research/spike work to explore options or validate an approach with
  no deliverable output yet (comparing approaches, testing architectures,
  feasibility investigation before committing).
- **Expense / Maintenance** — routine work to operate, support, or maintain the
  system (bug fixes, cleanup, pen-test remediation, small operational fixes).

Do not mix types in one project unless the boundary is genuinely inseparable.
Never mix capitalizable build work with maintenance.

### Paper Cuts
Group small maintenance/cleanup into a dedicated **Paper Cuts** project rather
than polluting a delivery project. Paper Cuts is Expense/Maintenance work.

- Naming: `Paper Cuts July - Account Charges`, `Paper Cuts August - Connect Portal`
- Use for: minor bug fixes, low-level cleanup, support-driven fixes, maintenance, non-strategic small changes.
- Do NOT use for: a major feature, a clearly scoped deliverable, R&D/spike work, or strategic product development.

## Making work land in the right roadmap column

The roadmap has one swimlane per **initiative**; columns are derived from each
item's Linear **status and dates**. The company fiscal year Q1 starts in
**November**. Columns (with the roadmap's own definitions):

| Column | Roadmap meaning | Comes from Linear |
|---|---|---|
| **Shipped / Completed** | delivered | done within the last two fiscal quarters |
| **Now** (~90%) | "Committed and in-flight this quarter" | in progress, or any status with a target/start date this quarter |
| **Next** (~60%) | "Planned, or still to be planned — likely but not yet committed" | target date falls next quarter |
| **Later** (~30%) | "Directional; further out and less certain" | no date set, and not idea status |
| **Ideas** | not yet committed | idea status in Linear |
| **Inactive** | paused / not doing | can be hidden from the board |

So a common failure — "my initiative isn't showing up well" — is almost always
one of: projects still in **idea** status (stuck in Ideas), **no target dates**
set (stuck in Later), no owner, or a vague/empty initiative description. To place
work deliberately:

- **Assign** the project/issue to an owner.
- **Set target dates** (and start dates) so it falls in the intended column.
- **Move status out of `idea`** once the work is actually committed.
- **Write a clear initiative description** in outcome/customer terms.
- **Post project updates** with a health indicator (on track / at risk / off
  track) — leadership monitors these on the roadmap.

## Linear tips

- Linear has no native epics — use **milestones** as epics.
- **RICE** scoring is available in the roadmap tool for prioritization.
- Roadmap admin (in the roadmap website): `Cmd+Opt+A` opens admin mode with a
  "How It Works" doc; `Cmd+Opt+H` hard-refreshes the server-side cache (use after
  Linear changes aren't reflected yet).

## Decision procedure

When asked to create or organize work:

1. **Initiative** = the broad outcome/phase. Create or reuse one.
2. **Project** = the specific deliverable within it. Create or reuse one.
3. **Issue** = the concrete implementation task.
4. If the work is small maintenance/cleanup/bug-fixing → a **Paper Cuts** project.
5. If exploratory and not yet committed to delivery → an **R&D-style** project.
6. If building real product capability → a **delivery-focused (capitalizable)** project.
7. Set owner, status, and dates so each item lands in the correct roadmap column,
   and give the initiative a clear roadmap-facing description.

**Example structure**
- **Initiative:** `Account Charges V1` — "Customer-facing portal to access institute account charges"
  - **Project:** `Show users their charges` (capitalizable)
    - Issue: `Build charges overview screen`
    - Issue: `Add per-student and per-course views`
    - Issue: `Add plain-language field descriptions`
    - Issue: `Connect UI to staging data`
    - Issue: `Validate charge data against source data`
  - **Project:** `Dispute raising workflow` (capitalizable)
  - **Project:** `Wayfinder data sanitization` (capitalizable)
  - **Project:** `Consolidation support investigation` (R&D)
  - **Project:** `Paper Cuts July - Account Charges` (expense/maintenance)
