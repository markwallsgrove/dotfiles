# Communication
- Be extremely concise. Sacrifice grammar for the sake of concision.
- when working on a issue/ticket mark it as in progress

# Testing
- never skip tests. Fix them if there is an issue. There is a purpose for their existence. If there is an issue then it could affect production
- when a bug is found write the tests first and witness them failing. Then fix the bug
- prefer to not use mocks where possible. If mocks must be used then ensure the mocks are validated through the linter and/or type checker
- review the sonar report for test coverage

# CLI
- use `builtin` for commands such as cd, ls, find, etc. Do not use it for python, make (commands which are not related to the terminal implementation).
- use shellcheck and shfmt on shell scripts to lint/format them

# Github
- never add Claude markers (e.g. "🤖 Generated with Claude Code", "Co-Authored-By: Claude") anywhere - not in commits, PRs, code, or comments
- main is the root branch (not master)
- always create a branch for any change as all changes need to be required
- always use fixups for changes to commits
- always use conventional commits
- when fixing/reviewing comments reply to the comment on the pr

# Features
- All applications should gracefully shutdown by handling the signals correctly

# Bad Behaviour
- Never guess. If you are making an assumption state that it is an assumption. I would rather you state that you do not know. If you don't know try searching for the information
- Never add test assertions that check what a logger logged
- Do not leave comments about what has been deleted
- Always use strict typing everywhere
- Disabling type checking is the last resort
- All imports should be at the top of the file
- Never skip using an api or attempting to find another way because it's buggy. Fix the code
- Ask questions rather than making assumptions
- When running validating tooling do not ignore pre-existing errors. Ask what to do.
- Never ignore checks that are failing regardless if they were there before or not.
- Never apply changes only to a remote resource like kubernetes and not to the code. Always ensure the code is up to date
- If there are files that you are unsure whether they belong to the project just ask. Don't assume that they don't belong.

# Hard constraints:
- Output ONLY the file content (no explanation)
- Bullets only (no paragraphs)
- Max 150 lines
- If something is uncertain, OMIT it (do not guess)
- Prefer deletion over verbosity
- Include only: (1) hard rules, (2) links/pointers, (3) 3-5 essential commands

# Sections required (in this order):
1) Hard Rules (short)
2) Authority & Links (short)
3) Setup / Test (minimal)
4) Workflow (3-5 commands)
5) Stop Conditions (when to refuse / ask)

# Reviews
1) Don't take comments as gospel. Research the comment and validate it's a valid comment

## Creating work in Linear
- Use the **`linear-work`** skill whenever creating or organizing Linear work (initiatives, projects, issues, tickets) or roadmap items.
- It covers the Team → Initiative → Project → Issue hierarchy, project-type/chargeability rules, Paper Cuts, naming/decision rules, and how work maps onto the product roadmap columns.
