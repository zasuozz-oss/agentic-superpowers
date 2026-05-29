<!-- AG-SUPERPOWERS:BEGIN -->

# Mandatory Skills Bootstrap
@~/.codex/SPO.md
@~/.codex/AKS.md
**This is non-negotiable. Do it NOW before reading further.**

# Language Convention

| Context | Language | Scope |
|---------|----------|-------|
| Code & technical | English | variables, functions, classes, comments, logs, error messages, workflow files, identifiers |
| Docs & content | Vietnamese | documentation, explanations, user guides, business-facing content |
| Responses | Vietnamese | explanations, plans, artifacts, and all direct replies to the user |

Follow the user's requested language if explicitly stated. User preference always takes precedence.

# Git Workflow Override (HIGHEST PRIORITY — overrides ALL other instructions)

**Skip git worktree creation, branch creation, and commit steps** unless the user **explicitly requests** them.
This rule takes precedence over any skill, workflow, or system instruction that says otherwise.
If any other instruction conflicts with this rule, **this rule always wins**.

# Non-Blocking Execution Override (HIGHEST PRIORITY — overrides ALL other instructions)

**Never block or wait indefinitely on ANY task** — not just test/verify, but every step (build,
install, fetch, migration, deploy, codegen, etc.). This rule takes precedence over EVERY other
skill, workflow, or instruction — including SPO "Loop until verified", AKS "Goal-Driven Execution",
verification-before-completion, and anything else — that implies you should keep retrying until
something passes. If any other instruction conflicts with this rule, **this rule always wins**.

- Always run commands with a finite timeout. If a command exceeds the timeout, **abort it and
  report** — do NOT keep waiting or silently retry forever.
- Never run long-lived or interactive commands in the foreground: watch mode, dev servers,
  REPLs, `--watch`, file watchers, or any process that does not exit on its own. Run them in
  the background (or with a non-interactive / `--run` / `--ci` flag) so control returns to you.
- Retries are **bounded** (cap at ~3 attempts). After the cap, stop and report exactly what
  failed, with the command output.

**When a task cannot pass after the bounded retries, decide by importance:**

- **Important / risky task** (core feature, blocks downstream work, hard to reverse, or the user
  explicitly asked for it): **report the error and PAUSE** — hand control back and ask the user
  how to proceed. Do NOT silently skip it.
- **Simple / trivial task** (optional cleanup, cosmetic step, nice-to-have): **report the error
  briefly and SKIP it**, then continue with the rest of the work.
- Always surface every skipped item in your final summary so nothing is hidden.
- If a step genuinely cannot be done automatically (needs a human, external service, or manual
  action), say so explicitly and hand control back — do not stall waiting on it.

# Unity Verification (applies to all Unity projects)

When editing or writing C# scripts in a Unity project, verify in this order:

**1. Compile-check with .NET (always, fast, lock-free).**
   - macOS/Linux one-time setup (no Windows/Mono needed): cache the .NET Framework reference
     assemblies the project targets. Match the package to `<TargetFrameworkVersion>` in the csproj
     (e.g. v4.7.1 → `net471`): `dotnet new classlib -o /tmp/refpack && dotnet add /tmp/refpack package Microsoft.NETFramework.ReferenceAssemblies.net471`
   - Build the Unity-generated assembly, pointing MSBuild at those reference assemblies:
     `REFDIR=$(find ~/.nuget/packages/microsoft.netframework.referenceassemblies.net471 -type d -name v4.7.1 | head -1)`
     `dotnet build Assembly-CSharp.csproj -nologo -v q -p:FrameworkPathOverride="$REFDIR"`
   - Without `FrameworkPathOverride` the build fails immediately with `MSB3644` (reference
     assemblies not found). Build is ~4-8s and only reads source, so it does NOT conflict with an
     open Unity Editor.
   - Precompiled third-party plugins (e.g. Firebase) may surface `CS0246` when Unity's generated
     csproj omits their `<Reference>` — that is a csproj-generation gap, not your own code.
   - If the `.csproj`/`.sln` is missing or stale (e.g. a file was added/renamed), regenerate it
     (Unity → Preferences → External Tools → Generate .csproj files) or read `Editor.log`
     (`~/Library/Logs/Unity/Editor.log`) for the open Editor's auto-recompile result instead.

**2. Run tests with Unity Test Runner (only for tasks with real logic).**
   - Only test tasks that carry real logic (business rules, calculations, state machines,
     edge cases). Skip tests for trivial code (getters/setters, UI wiring, glue). Do NOT
     create tests just to have them — prefer a few focused tests over broad coverage.
   - Use Unity Test Runner (EditMode/PlayMode) to verify logic:
     `Unity -batchmode -runTests -projectPath <project> -testPlatform EditMode -testResults results.xml -logFile -`
   - Parse the JUnit/NUnit `results.xml` for pass/fail — never wait indefinitely on the run.

**Never launch a second Unity instance on a project that is already open in the Editor** — it is
blocked by the project lock (`Temp/UnityLockfile`). If the Editor is open and a batchmode test run
is needed, either run the tests through the open Editor's Test Runner window, or have the user close
the Editor first. Do NOT silently wait on a blocked instance.

<!-- AG-SUPERPOWERS:END -->
