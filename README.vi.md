# Agentic Superpowers

Framework skills & rules đa nền tảng cho **Claude Code**, **Codex**, và **Antigravity (Gemini)** — một lần cài đặt cấu hình toàn cục + skills cho cả ba. Xây trên [Superpowers](https://github.com/obra/superpowers).

🌐 [English](README.md) · [Bắt Đầu Nhanh](#-bắt-đầu-nhanh) · [Tính Năng](#-bao-gồm-gì) · [Báo Lỗi](https://github.com/zasuozz-oss/agentic-superpowers/issues)

---

## 📋 Yêu Cầu

- Một hoặc nhiều harness được hỗ trợ: [Claude Code](https://claude.com/claude-code), Codex, hoặc [Google Antigravity](https://antigravity.google) (macOS / Windows / Linux)
- Git
- Bash (macOS/Linux) hoặc PowerShell (Windows)

---

## 🎯 Giới Thiệu

Framework skills & rules đa nền tảng, xây trên thư viện skills [Superpowers](https://github.com/obra/superpowers). Một lần cài đặt sẽ cài skills + các block hướng dẫn toàn cục cho **Claude Code** (`~/.claude/`), **Codex** (`~/.codex/`), và **Antigravity / Gemini** (`~/.gemini/`).

**Bổ sung so với bản gốc:**
- ✅ Cài đa harness — Claude Code, Codex, Antigravity chỉ trong một setup
- ✅ Các block rule toàn cục: Git Workflow & Non-Blocking Execution override, Subagents, Language Convention, Preferred Tools
- ✅ AKS (Karpathy guidelines) cùng các skill bổ sung (gitnexus, normalize-task, Unity)
- ✅ Tự tạo file hướng dẫn cho từng harness (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`) kèm bootstrap skill `using-superpowers`
- ✅ Đồng bộ thư viện skills upstream khi cập nhật

---

## ⚡ Bắt Đầu Nhanh

### 1. Cài Đặt Toàn Cục (Chạy 1 lần)

**Cài nhanh (khuyến nghị):**
```bash
npx @zasuo/agentic-superpowers
```

<details>
<summary>Cách khác: Cài thủ công</summary>

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

### 2. Bắt Đầu Sử Dụng

Mở Antigravity trong bất kỳ project nào. Skills tự động load qua `~/.gemini/GEMINI.md`.

---

## 📚 Bao Gồm Gì

### Tổng quan bộ Skills

| Loại | Skills |
|------|--------|
| **Cốt lõi** | brainstorming, test-driven-development, systematic-debugging |
| **Cộng tác** | writing-plans, executing-plans |
| **Review** | requesting-code-review, receiving-code-review |
| **Git** | finishing-a-development-branch |
| **Meta** | using-superpowers, writing-skills, verification-before-completion |

---

## 📁 Cấu Trúc

```
agentic-superpowers/
├── bin/cli.mjs                  # npx installer
├── scripts/                     # Script cài đặt & cập nhật
│   ├── setup-global.sh
│   ├── setup-global.ps1
│   └── update-superpowers.sh
├── skills/                      # Các skill từ Superpowers & Gitnexus
└── workflows/                   # Pre-made workflows
```

**Sau khi cài đặt:**
```
~/.gemini/
├── GEMINI.md                    # Global config (tự tạo)
└── antigravity/
    ├── skills/                  # Các skills đã cài đặt
    └── scripts/                 # Setup scripts
```

---

## 🔄 Cập Nhật

```bash
bash ~/.gemini/antigravity/scripts/update-superpowers.sh
```

Tự động pull skills từ upstream, cập nhật bản cài đặt, và đồng bộ ngược vào fork repo.

---

## 🔗 Liên Kết

- **Bản gốc:** [obra/superpowers](https://github.com/obra/superpowers)
- **Google Antigravity:** [antigravity.google](https://antigravity.google)

---

## 📝 Giấy Phép

MIT — Xem [LICENSE-SUPERPOWERS](LICENSE-SUPERPOWERS) để biết chi tiết.
