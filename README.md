# Agentic Superpowers

Cross-platform agent skills & rules framework for **Claude Code**, **Codex**, and **Antigravity (Gemini)** — one setup installs global config and skills for all three. Built on [Superpowers](https://github.com/obra/superpowers).

🌐 [Tiếng Việt](README.vi.md) · [Quick Start](#-quick-start) · [Features](#-whats-inside) · [Report Bug](https://github.com/zasuozz-oss/agentic-superpowers/issues)

---

## 📋 Requirements

- One or more supported harnesses: [Claude Code](https://claude.com/claude-code), Codex, or [Google Antigravity](https://antigravity.google) (macOS / Windows / Linux)
- Git
- Bash (macOS/Linux) or PowerShell (Windows)

---

## 🎯 What Is This?

A cross-platform agent skills & rules framework, built on the [Superpowers](https://github.com/obra/superpowers) skills library. One setup installs skills and global instruction blocks for **Claude Code** (`~/.claude/`), **Codex** (`~/.codex/`), and **Antigravity / Gemini** (`~/.gemini/`).

**What it adds on top of upstream:**
- ✅ Multi-harness install — Claude Code, Codex, and Antigravity from a single setup
- ✅ Global rule blocks: Git Workflow & Non-Blocking Execution overrides, Subagents, Language Convention, Preferred Tools
- ✅ AKS (Karpathy guidelines) plus extra skills (gitnexus, normalize-task, Unity)
- ✅ Auto-generates each harness's instruction file (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`) with a `using-superpowers` skill bootstrap
- ✅ Syncs the upstream skills library on update

---

## ⚡ Quick Start

### 1. Install Globally (One-time)

**Quick Install (recommended):**
```bash
npx @zasuo/agentic-superpowers
```

<details>
<summary>Alternative: Manual Install</summary>

**macOS / Linux:**
```bash
git clone https://github.com/zasuozz-oss/agentic-superpowers.git
cd agentic-superpowers
bash scripts/setup-global.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/zasuozz-oss/agentic-superpowers.git
cd agentic-superpowers
powershell -ExecutionPolicy Bypass -File scripts/setup-global.ps1
```

</details>

### 2. Start Using

Open Antigravity in any project. Skills auto-load via `~/.gemini/GEMINI.md`.

---

## 📚 What's Inside

### Core Skills

| Category | Skills |
|----------|--------|
| **Core** | brainstorming, test-driven-development, systematic-debugging |
| **Collaboration** | writing-plans, executing-plans |
| **Review** | requesting-code-review, receiving-code-review |
| **Git** | finishing-a-development-branch |
| **Meta** | using-superpowers, writing-skills, verification-before-completion |

---

## 📁 Structure

```
agentic-superpowers/
├── bin/cli.mjs                  # npx installer
├── scripts/                     # Setup & Update scripts
│   ├── setup-global.sh
│   ├── setup-global.ps1
│   └── update-superpowers.sh
├── skills/                      # Superpowers + Gitnexus skills
└── workflows/                   # Pre-made workflows
```

**After installation:**
```
~/.gemini/
├── GEMINI.md                    # Global config (auto-generated)
└── config/
    ├── skills/                  # Installed skills
    └── setup/                   # Setup scripts

---

## 🔄 Updating

```bash
bash ~/.gemini/config/setup/update-superpowers.sh
```

Updates installed skills from upstream and auto-syncs back to fork repo.

---

## 🔗 Links

- **Upstream:** [obra/superpowers](https://github.com/obra/superpowers)
- **Google Antigravity:** [antigravity.google](https://antigravity.google)

---

## 📝 License

MIT — See [LICENSE-SUPERPOWERS](LICENSE-SUPERPOWERS) for details.
