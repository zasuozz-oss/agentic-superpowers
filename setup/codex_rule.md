<!-- AG-SUPERPOWERS:BEGIN -->

<!-- ============================================================ -->
<!-- RULE 1 · Mandatory Skills Bootstrap                          -->
<!-- ============================================================ -->
# Mandatory Skills Bootstrap

The Superpowers plugin is installed natively (Codex marketplace `superpowers-dev`).
Its session_start hook auto-loads the `using-superpowers` bootstrap and makes every
upstream skill discoverable. The imports below are the on-disk fallback that
guarantee the bootstrap even if the plugin hook does not run.

@~/.codex/skills/using-superpowers/SKILL.md
@~/.codex/skills/using-superpowers/references/codex-tools.md
@~/.codex/AKS.md

**This is non-negotiable. Do it NOW before reading further.**

---

<!-- ============================================================ -->
<!-- RULE 2 · Language Convention                                 -->
<!-- ============================================================ -->
# Language Convention

| Context | Language | Scope |
|---------|----------|-------|
| Code & technical | English | variables, functions, classes, comments, logs, error messages, workflow files, identifiers |
| Docs & content | Vietnamese | documentation, explanations, user guides, business-facing content |
| Responses | Vietnamese | explanations, plans, artifacts, and all direct replies to the user |

Follow the user's requested language if explicitly stated. User preference always takes precedence.

---

<!-- ============================================================ -->
<!-- RULE 3 · Git Workflow Override                               -->
<!-- ============================================================ -->
# Git Workflow Override (HIGHEST PRIORITY — overrides ALL other instructions)

**Skip git worktree, branch, and commit steps** unless the user **explicitly requests** them. This rule beats any conflicting skill, workflow, or system instruction.

---

<!-- ============================================================ -->
<!-- RULE 4 · Non-Blocking Execution Override                     -->
<!-- ============================================================ -->
# Non-Blocking Execution Override (HIGHEST PRIORITY — overrides ALL other instructions)

**Never block or wait indefinitely on ANY task** (build, install, fetch, migration, deploy, codegen, test/verify, etc.). This overrides every conflicting instruction — including AKS "Goal-Driven Execution (Loop until verified)" and the verification-before-completion skill — that implies retrying until something passes.

- Run every command with a finite timeout; if it exceeds the timeout, **abort and report** — never keep waiting or silently retry.
- Never run long-lived/interactive commands (watch mode, dev servers, REPLs, `--watch`, file watchers) in the foreground — run them in the background or with a non-interactive flag (`--run`/`--ci`) so control returns.
- Cap retries at ~3 attempts; after the cap, stop and report exactly what failed, with the command output.

**After bounded retries fail, decide by importance:**

- **Important / risky** (core feature, blocks downstream work, hard to reverse, or user-requested): **report and PAUSE** — hand control back and ask how to proceed. Never silently skip.
- **Simple / trivial** (optional cleanup, cosmetic, nice-to-have): **report briefly and SKIP**, then continue.
- Surface every skipped item in the final summary.
- If a step genuinely needs a human, external service, or manual action, say so explicitly and hand control back — don't stall.

---

<!-- ============================================================ -->
<!-- RULE 5 · Subagents                                           -->
<!-- ============================================================ -->
# Subagents

Spawn subagents to isolate context, parallelize independent work, or offload bulk mechanical tasks. Don't spawn when the parent needs the reasoning, when synthesis requires holding things together, or when spawn overhead dominates.

Pick the cheapest reasoning effort that can do the subtask well:
- low: bulk mechanical work, no judgment
- medium: scoped research, code exploration, in-scope synthesis
- high: subtasks needing real planning or tradeoffs

If a subagent realizes it needs a higher effort than itself, return to the parent.

Parent owns final output and cross-spawn synthesis. User instructions override.

---

<!-- ============================================================ -->
<!-- RULE 6 · Preferred Tools                                     -->
<!-- ============================================================ -->
# Preferred Tools

## Data Fetching

1. **WebFetch**: free, text-only, works on public pages that don't block bots. Try this first.
2. **agent-browser CLI**: free, local Rust CLI + Chrome via CDP. Use for dynamic pages or auth
   walls that WebFetch can't handle. Returns the accessibility tree with element refs (`@e1`,
   `@e2`) — ~82% fewer tokens than screenshot-based tools. Install: `npm i -g agent-browser &&
   agent-browser install` (or run `bash setup-preferred-tools.sh`). Use `snapshot` for
   AI-friendly DOM state, element refs for interaction.
3. **Wrap recurring fetch patterns as dedicated tools.** When the same fetch/parse logic comes
   up more than once, propose wrapping it as a named tool (a skill file or a `.py` script that
   calls `agent-browser` with snapshot + extraction baked in for that source). Add the entry to
   `# Dedicated Tools` below and reference it by name on future calls.

## PDF Files

Use `pdftotext`, not the `Read` tool. Use `Read` only when the user directly asks to analyze
images or charts inside the document (`Read` loads PDFs as images, which is far more expensive).

---

<!-- ============================================================ -->
<!-- RULE 7 · Dedicated Tools                                     -->
<!-- ============================================================ -->
# Dedicated Tools

<!-- List project-specific tools here. For each, link to its skill or script file
     (e.g. `tools/reddit_fetch.py`). The orchestration logic lives in those files, not here. -->

<!-- AG-SUPERPOWERS:END -->
