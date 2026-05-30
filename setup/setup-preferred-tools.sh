#!/bin/bash
# Setup script for the "Preferred Tools" listed in the AI rules.
# Auto-installs the external helpers used for data fetching and PDF handling:
#   - agent-browser  (dynamic pages / auth walls; needs npm)
#   - pdftotext      (poppler; cheap text extraction from PDFs)
# WebFetch is a built-in Claude Code tool and needs no installation.
#
# Usage: bash setup-preferred-tools.sh
# Compatible with: macOS, Linux, Windows Git Bash
#
# Idempotent: tools already on PATH are skipped. A failure on one tool is
# reported but does NOT abort the rest (no `set -e`).

# ─── OS detection ───
OS="unknown"
case "$(uname -s)" in
    Darwin*)                 OS="mac" ;;
    Linux*)                  OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*)    OS="windows" ;;
esac

# ─── helpers ───
have() { command -v "$1" >/dev/null 2>&1; }

INSTALLED=""
SKIPPED=""
FAILED=""

mark_installed() { INSTALLED="$INSTALLED\n   ✓ $1"; }
mark_skipped()   { SKIPPED="$SKIPPED\n   • $1"; }
mark_failed()    { FAILED="$FAILED\n   ✗ $1"; }

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Preferred Tools Setup                                  ║"
echo "║     Install external data-fetching & PDF helpers           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🖥️  Detected OS: $OS"
echo ""

# ─── 1. agent-browser (needs npm) ───
echo "🌐 1/2: agent-browser (dynamic pages / auth walls)..."
if have agent-browser; then
    echo "   • Already installed: $(command -v agent-browser)"
    mark_skipped "agent-browser (already installed)"
elif have npm; then
    echo "   → npm install -g agent-browser"
    if npm install -g agent-browser; then
        # Downloads a headless Chrome via CDP; allowed to fail (large download / offline)
        echo "   → agent-browser install (fetching Chrome)..."
        if agent-browser install; then
            mark_installed "agent-browser (+ Chrome)"
        else
            echo "   ⚠️  'agent-browser install' failed (Chrome download). The CLI is installed;"
            echo "       re-run 'agent-browser install' later when online."
            mark_installed "agent-browser (Chrome pending — run 'agent-browser install')"
        fi
    else
        echo "   ✗ npm install failed."
        mark_failed "agent-browser (npm install failed)"
    fi
else
    echo "   ✗ npm not found. Install Node.js first: https://nodejs.org"
    mark_failed "agent-browser (npm missing — install Node.js)"
fi
echo ""

# ─── 2. pdftotext (poppler) ───
echo "📄 2/2: pdftotext (poppler — PDF text extraction)..."
if have pdftotext; then
    echo "   • Already installed: $(command -v pdftotext)"
    mark_skipped "pdftotext (already installed)"
else
    POPPLER_OK=false
    case "$OS" in
        mac)
            if have brew; then
                echo "   → brew install poppler"
                brew install poppler && POPPLER_OK=true
            else
                echo "   ✗ Homebrew not found. Install brew: https://brew.sh"
            fi
            ;;
        linux)
            if have apt-get; then
                echo "   → sudo apt-get install -y poppler-utils"
                sudo apt-get update -y && sudo apt-get install -y poppler-utils && POPPLER_OK=true
            elif have dnf; then
                echo "   → sudo dnf install -y poppler-utils"
                sudo dnf install -y poppler-utils && POPPLER_OK=true
            elif have pacman; then
                echo "   → sudo pacman -S --noconfirm poppler"
                sudo pacman -S --noconfirm poppler && POPPLER_OK=true
            else
                echo "   ✗ No supported package manager (apt-get/dnf/pacman) found."
            fi
            ;;
        windows)
            # Try the common Windows package managers in order.
            if have scoop; then
                echo "   → scoop install poppler"
                scoop install poppler && POPPLER_OK=true
            elif have choco; then
                echo "   → choco install poppler -y"
                choco install poppler -y && POPPLER_OK=true
            elif have winget; then
                echo "   → winget install --id oschwartz10612.Poppler -e"
                winget install --id oschwartz10612.Poppler -e --accept-source-agreements --accept-package-agreements && POPPLER_OK=true
            else
                echo "   ✗ No package manager (scoop/choco/winget) found."
                echo "     Install scoop (https://scoop.sh) then re-run, or grab poppler from:"
                echo "     https://github.com/oschwartz10612/poppler-windows/releases"
            fi
            ;;
        *)
            echo "   ✗ Unsupported OS for automatic install."
            ;;
    esac

    if [ "$POPPLER_OK" = true ]; then
        mark_installed "pdftotext (poppler)"
    else
        mark_failed "pdftotext (poppler — see instructions above)"
    fi
fi
echo ""

# ─── Summary ───
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Summary                                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
[ -n "$INSTALLED" ] && { echo "Installed:"; printf "%b\n" "$INSTALLED"; }
[ -n "$SKIPPED" ]   && { echo "Skipped:";   printf "%b\n" "$SKIPPED"; }
[ -n "$FAILED" ]    && { echo "Failed:";    printf "%b\n" "$FAILED"; }
echo ""
echo "ℹ️  WebFetch is a built-in tool — no installation needed."
echo ""

if [ -n "$FAILED" ]; then
    echo "⚠️  Some tools could not be installed automatically. See messages above."
    exit 1
fi
echo "✅ Done!"
