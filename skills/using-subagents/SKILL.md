---
name: using-subagents
description: Use when deciding whether to delegate work to a subagent, or how to dispatch one, on any agent platform (Claude Code, Codex, Gemini, Copilot) — bulk reads/search flooding context, independent tasks that could run in parallel, repetitive mechanical edits, or "should I spawn a subagent for this?"
---

# Using Subagents

Cross-platform guide for delegating work to subagents. Two parts: **when/how to dispatch** (decision guide) and **how to invoke per platform** (tool mapping + fallbacks).

**Core principle:** A subagent starts cold — no conversation context. It earns its cost only when isolating context, parallelizing independent work, or offloading bulk mechanical work outweighs the spawn overhead.

## When to Spawn

Spawn when:
- **Isolate context** — bulk reading/search that would flood the parent's window
- **Parallelize** — independent tasks with no shared state (3-5x faster)
- **Offload mechanical work** — repetitive edits needing no parent judgment

Do NOT spawn when:
- Parent needs the reasoning to continue
- Synthesis requires holding pieces together in one head
- Spawn overhead dominates a trivial task
- Task is underspecified — a cold subagent cannot ask you to clarify

## Picking the Model

Pick the cheapest **tier** that does the subtask well, then use that platform's model in the tier:

| Tier | Use for | Claude | Codex (OpenAI) | Gemini |
|------|---------|--------|----------------|--------|
| Cheap/fast | Bulk mechanical work, no judgment | Haiku | gpt-5-mini / o4-mini | Flash |
| Mid | Scoped research, code exploration, in-scope synthesis | Sonnet | gpt-5 | Pro |
| Frontier | Subtasks needing real planning or tradeoffs | Opus | gpt-5 (high reasoning) | Pro (max thinking) |

Model names drift per platform/version — match the tier, not the exact name. If a platform exposes only one model, ignore the table and just scope the task well.

If a subagent realizes it needs a higher tier, it returns to the parent instead of pushing on.

## Writing the Task

Subagents **cannot ask questions** — they run to completion on what you give them. So:

1. **Self-contained** — include all paths, constraints, and context. No "as discussed."
2. **Verifiable goal** — state success criteria the subagent checks itself (e.g. "tests pass", "returns file:line table").
3. **Bounded scope** — say what NOT to touch.
4. **Output shape** — name the format you want back (diff, table, summary).

## Parallel vs Sequential

- **Parallel** — dispatch all agents in ONE message (multiple invocations). For independent tasks. Wait for all, then synthesize.
- **Sequential** — when task N depends on task N-1's output. Each result feeds the next.

Parent always owns final output and cross-agent synthesis.

## Platform Invocation

| Platform | Native subagent | How |
|----------|-----------------|-----|
| **Claude Code** | ✅ `Task`/`Agent` tool | Call with `subagent_type`, `description`, `prompt`. Parallel = multiple `Task` calls in one message. |
| **Codex CLI** | ❌ none | **Fallback:** run subtasks inline/sequentially in the same context; or shell out to a separate `codex exec "<task>"` process and read its output. |
| **Gemini CLI** | ⚠️ experimental | **Fallback:** decompose inline/sequentially; use `activate_skill` for skill-based breakdown. No reliable parallel primitive. |
| **Copilot CLI** | ❌ none | **Fallback:** inline/sequential in the same context. |

**Fallback rule:** where no native subagent exists, do NOT fake parallelism. Run the steps yourself in order, keep each step's scope tight, and report per-step results — the *discipline* (bounded scope, verifiable goals, explicit output) carries over even without the spawn primitive.

## Checklist

- [ ] Spawn earns its cost (isolate / parallelize / offload) — else do it inline
- [ ] Cheapest capable model chosen
- [ ] Task is self-contained with a verifiable goal and output shape
- [ ] Independent → parallel in one message; dependent → sequential
- [ ] Platform supports native subagent? else use the fallback, don't fake it
- [ ] Parent synthesizes the final result
