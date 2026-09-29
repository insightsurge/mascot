---
name: handoff
description: Start, update, check or close handoffs in dev/handoffs/ (local, gitignored working notes that let a fresh session or another agent resume). Supports long-lived areas (e.g. content, site, design) with an overview, and short-lived features. Use when the user says /handoff, "start/update/close the handoff", "check the handoffs", before opening a PR, before a context compaction, or when ending a session.
argument-hint: init | start <name> | update [<name>...] | status | check [<name>] | close <name>
---

# /handoff

Handoffs are curated working notes so the next session (or another agent) resumes from a few small
files instead of a long transcript. They live in `dev/handoffs/`, which must be gitignored; they are not
backed up by git. The tracker (issues, PRs), ADRs and docs are the source of truth; handoffs point to them.

## Layout
```
dev/handoffs/
├── README.md          root index: which folder covers what, the file convention, the rules
├── overview/          optional, for projects with several areas: priorities, decisions, delivered index
└── <name>/            one folder per area (long-lived) or feature (short-lived)
    ├── README.md        Status (dated), Next step, Read order, Last session  (≤ 60 lines)
    ├── 01-feature.md    what and why, scope, acceptance, source of truth
    ├── 02-code-map.md   where things live (delete if the folder has no code)
    ├── 03-open-issues.md open work (pointers to the tracker) and gotchas
    ├── 04-plan.md       next steps, how work runs, verification
    ├── 05-questions.md  decisions waiting (question, options, recommendation)
    ├── 06-delivered.md  finished work, newest first, with links (keeps the README short)
    └── <extras>         named files or folders when useful: ops.md, pipeline.md, research/, …
```
The numbered files mean the same thing in every folder and every project. Delete the ones a folder
doesn't need; don't renumber. Folders starting with `_` (e.g. `_archive/`) are ignored by the script.

**Areas or features?** Use areas when work is ongoing (a product, a content programme, a design system);
use a feature folder for a bounded piece of work and close it when done. Many projects need only one.

## Commands
The helper is `bash .claude/skills/handoff/scripts/handoff.sh`. It always resolves the **main checkout's**
`dev/handoffs/`, also from a git worktree, so every worktree shares one set of handoffs.

### init
For a new project: `handoff.sh init` creates the root `README.md` and `overview/` (with `decisions.md`).
Add each area to the root index's table as you create it.

### start <name>
`handoff.sh start <name>` (kebab-case) copies the templates. Then fill `01-feature.md` from the issue or
the conversation (ask only for what you can't infer), set the README's **Status (date)**, **Next step**
and **Read order**, and add the folder to the root index.

### update [<name>...]
Update every folder the session touched (not only one), and `overview/` only when a shared priority or
decision changed.
1. **Verify before you write.** Check the real state of what the README claims: the linked issues and
   PRs (open, merged, closed), the branch, the latest commit on main. Never copy a status forward unchecked.
2. README: **Status (today's date)**, **Next step** as a concrete first action (file or issue to open),
   **Last session** (1–3 bullets). Keep it ≤ 60 lines.
3. Move finished items from the README, `03` and `04` into `06-delivered.md` (one or two lines each,
   with links). Remove answered questions from `05` and record the decision (overview `decisions.md` or an ADR).
4. Update the code map, open issues and plan where they changed. Link; don't paste code or logs.
5. Anything durable (a decision, a standard, a reusable brief, a script others will run) belongs in
   git (ADR, `docs/`, `tools/`, an issue). Keep only session state here.
6. Run `handoff.sh check` and fix what it reports.

### status
`handoff.sh status` prints each folder's Status and Next step on one screen: use it to orient a new
session, then read only the folder the task needs.

### check [<name>]
`handoff.sh check` warns about a missing root index or README, a README over 60 lines, a Status with no
date or older than 14 days (`HANDOFF_STALE_DAYS`), and file paths in backticks that don't exist
under any of the folder, `dev/handoffs/` or the repository root (so an area named like a repo folder,
e.g. `brand/`, doesn't hide the repo's files). Paths that match only at the repository root are checked
with `HANDOFF_CHECK_REPO_PATHS=1`. It exits 1 on warnings.

### close <name>
Final `update`, then set the README to `**Status (date):** Closed. Historical reference.`, list where the
durable outcomes live (PRs, ADRs, docs), and remove the live Next step. Don't delete the folder unless
asked.

## When to run it
Before opening a PR, before a context compaction, when handing work to another agent, and at the end of
a session. A fresh session reads the root index, then `status`, then only the relevant folder.

## Rules
- Never write secrets, credentials, employer or client names, or real personal/client data.
- Absolute dates (`2026-09-28`), never "yesterday".
- The templates in `templates/` are the source of truth for structure; change them there.
- Paths in handoffs are written from the repository root or relative to the folder, so `check` can
  verify them.
