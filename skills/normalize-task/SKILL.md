---
name: normalize-task
description: >
  Auto-trigger immediately — without being asked — whenever the user describes any concrete
  development work: a bug to fix, a feature to add, a refactor to do, code to write or change,
  an integration to build, or a UI element to update. Fire at the very start of the response,
  before planning or implementing anything.

  SKIP entirely for: questions ("how does X work?"), quick lookups, explanations, theory,
  code reviews with no change requested, clarification questions, reference answers, or
  anything where no code will be written or modified.
argument-hint: "[raw task description, or leave empty to enter interactively]"
user-invocable: true
---

# Normalize Task

Convert raw user requirements into structured task blocks usable for AgentMemory storage and agent execution.

**Announce at start:** "Normalizing task..."

## Process

1. **Extract the raw requirement** from `$ARGUMENTS` or ask: "Briefly describe the task you need done."

2. **Identify gaps** — if any of these are missing, ask ONE clarifying question per turn:
   - What is the expected outcome? (if vague)
   - Which files/area of codebase? (if no file context and project is large)
   - Is this a bug fix, feature, or refactor? (if unclear)
   
   Stop asking once you have enough to produce testable criteria. Don't ask for information you can infer.

3. **Produce the normalized block** (see format below).

## Output Format

```markdown
## Task: [verb + object, under 10 words]

**Type**: bug-fix | feature | refactor | investigation | chore
**File**: `path/to/file.cs`
**Goal**: [One sentence: what to change and the intended result.]
**Tags**: [tag1, tag2, tag3]
```

## Rules

- Title in English regardless of input language
- **Goal is one sentence only** — what to do, not why, not how
- Do NOT include scope, acceptance criteria, context paragraphs, or depends-on
- If multiple files, list them; if unknown write `TBD`
- Tags: lowercase, comma-separated, 3–6 keywords max

## Example

**Input**: "UserService.cs — login and analytics calls are running in parallel, need to be sequential"

**Output**:
```markdown
## Task: Separate user login and analytics initialization in UserService

**Type**: refactor
**File**: `src/Services/UserService.cs`
**Goal**: Run `Login()` to completion before triggering analytics calls.
**Tags**: login, analytics, sequential, refactor, UserService
```
