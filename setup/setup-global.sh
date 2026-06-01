#!/bin/bash
# Global setup script for Superpowers in Antigravity
# Installs skills and rules to ~/.gemini/config/, ~/.claude/, ~/.codex/
# Usage: bash setup-global.sh
# Compatible with: macOS, Linux, Windows Git Bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.gemini/config"
CODEX_DIR="$HOME/.codex"
GEMINI_MD="$HOME/.gemini/GEMINI.md"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CODEX_MD="$HOME/.codex/AGENTS.md"

# Detect OS for platform-specific logic
IS_WINDOWS=false
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
    IS_WINDOWS=true
fi

# Detect python command — verify it actually runs (Windows Store alias reports
# "found" but launches the Store installer instead of a real interpreter).
PYTHON_CMD=""
for _py in python3 py python; do
    if command -v "$_py" >/dev/null 2>&1 && "$_py" -c "import sys" >/dev/null 2>&1; then
        PYTHON_CMD="$_py"
        break
    fi
done

BEGIN_MARKER="<!-- AG-SUPERPOWERS:BEGIN -->"
END_MARKER="<!-- AG-SUPERPOWERS:END -->"
UNITY_BEGIN_MARKER="<!-- AG-UNITY:BEGIN -->"
UNITY_END_MARKER="<!-- AG-UNITY:END -->"

# ─── upsert_block: replace or append a marker-delimited block in a file ───
# Usage: upsert_block <target_file> <rule_source_file> [begin_marker] [end_marker]
# Markers default to the AG-SUPERPOWERS pair; pass a custom pair (e.g. AG-UNITY)
# to manage a second, independent block in the same target file.
# Preserves all content outside the given markers.
upsert_block() {
    local target_file="$1"
    local rule_file="$2"
    local begin_marker="${3:-$BEGIN_MARKER}"
    local end_marker="${4:-$END_MARKER}"

    [ -f "$rule_file" ] || return 1

    mkdir -p "$(dirname "$target_file")"
    local block_content
    block_content=$(cat "$rule_file")

    if [ -f "$target_file" ] && grep -qF "$begin_marker" "$target_file"; then
        # Replace existing block in-place
        if [ -n "$PYTHON_CMD" ]; then
            $PYTHON_CMD -c "
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
begin = sys.argv[2]
end = sys.argv[3]
block = sys.argv[4]
start_idx = content.find(begin)
end_idx = content.find(end)
if start_idx != -1 and end_idx != -1:
    end_idx += len(end)
    content = content[:start_idx] + block + content[end_idx:]
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "$target_file" "$begin_marker" "$end_marker" "$block_content"
        else
            echo "   ⚠️  Python not found. Replacing entire file instead of in-place update."
            echo "$block_content" > "$target_file"
        fi
        echo "   ✓ Updated block in: $target_file (user content preserved)"
    elif [ -f "$target_file" ] && [ -s "$target_file" ]; then
        # File exists with content but no markers — append
        printf "\n%s\n" "$block_content" >> "$target_file"
        echo "   ✓ Appended block to: $target_file (existing content preserved)"
    else
        # No file or empty — write fresh
        echo "$block_content" > "$target_file"
        echo "   ✓ Created: $target_file"
    fi
}

# ─── install_skills: sync THIS repo's skills into <dir>/skills ───
# Usage: install_skills <target_root_dir>
# Only ever creates/replaces/removes skills owned by THIS repo. Skills installed
# by other repos or plugins in the same directory are left untouched.
# A manifest (.ag-superpowers-manifest) records which skills this repo installed
# so stale ones (removed from source since last run) can be pruned without a
# blanket --delete that would wipe foreign skills.
install_skills() {
    local skills_dir="$1/skills"
    local manifest="$skills_dir/.ag-superpowers-manifest"
    mkdir -p "$skills_dir"

    # Prune skills this repo installed before but no longer ships
    if [ -f "$manifest" ]; then
        while IFS= read -r old_skill || [ -n "$old_skill" ]; do
            [ -z "$old_skill" ] && continue
            if [ ! -d "$SCRIPT_DIR/../skills/$old_skill" ]; then
                rm -rf "$skills_dir/$old_skill"
            fi
        done < "$manifest"
    fi

    # Copy/refresh current skills, rewriting the manifest
    : > "$manifest.tmp"
    for skill_path in "$SCRIPT_DIR/../skills"/*/; do
        [ -d "$skill_path" ] || continue
        local name
        name=$(basename "$skill_path")
        rm -rf "$skills_dir/$name"
        cp -R "$skill_path" "$skills_dir/$name"
        echo "$name" >> "$manifest.tmp"
    done
    mv "$manifest.tmp" "$manifest"
}




echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Superpowers Global Setup                               ║"
echo "║     Install skills & rules globally                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

read -p "Do you want to run update-superpowers.sh first to fetch the latest upstream skills? (y/n): " run_update
if [ "$run_update" = "y" ] || [ "$run_update" = "yes" ]; then
    echo "🔄 Running update-superpowers.sh..."
    if [ -f "$SCRIPT_DIR/update-superpowers.sh" ]; then
        bash "$SCRIPT_DIR/update-superpowers.sh"
    else
        echo "⚠️  update-superpowers.sh not found. Skipping update."
    fi
    echo "✅ Update step finished. Proceeding with setup..."
    echo ""
fi

# Check if source directories exist
if [ ! -d "$SCRIPT_DIR/../skills" ]; then
    echo "❌ Error: skills/ not found"
    echo "   Make sure you are running this from the repository root"
    exit 1
fi

# Step 1: Create directories & check permissions
echo "📁 Step 1/8: Creating config directories..."
mkdir -p "$GLOBAL_DIR" "$CODEX_DIR" "$(dirname "$GEMINI_MD")" "$(dirname "$CLAUDE_MD")"

PERM_ERRORS=""
for dir in "$GLOBAL_DIR" "$CODEX_DIR" "$(dirname "$GEMINI_MD")" "$(dirname "$CLAUDE_MD")"; do
    if [ ! -w "$dir" ]; then
        if [ "$IS_WINDOWS" = true ]; then
            PERM_ERRORS="$PERM_ERRORS
      icacls \"$(cygpath -w "$dir")\" /grant %USERNAME%:F /T"
        else
            PERM_ERRORS="$PERM_ERRORS
      sudo chown -R $(whoami) $dir"
        fi
    fi
done

if [ -n "$PERM_ERRORS" ]; then
    echo "   ❌ Permission denied on some directories."
    echo "   Run these commands first, then re-run setup:"
    echo "$PERM_ERRORS"
    echo ""
    exit 1
fi
echo "   ✓ All directories ready"
echo ""

# Step 2: Check for duplicate skill names
echo "🔍 Step 2/8: Checking for duplicate skills..."
DUPLICATES=$(grep -rh '^name:' "$SCRIPT_DIR/../skills/"*/SKILL.md 2>/dev/null | sed 's/^name:[[:space:]]*//' | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    echo "   ❌ Duplicate skill names found:"
    echo "$DUPLICATES" | while read -r dup; do
        echo "      - $dup"
        grep -rl "^name:[[:space:]]*$dup$" "$SCRIPT_DIR/../skills/"*/SKILL.md | while read -r f; do
            echo "        → $f"
        done
    done
    exit 1
fi
SKILL_SRC_COUNT=$(ls -1d "$SCRIPT_DIR/../skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
echo "   ✓ $SKILL_SRC_COUNT skills checked, no duplicates"
echo ""

# Step 3: Install skills
# Per-skill copy only — never touches skills owned by other repos/plugins that
# share the same skills directory.
echo "📚 Step 3/8: Installing skills..."
install_skills "$GLOBAL_DIR"
SKILL_COUNT=$(ls -1 "$GLOBAL_DIR/skills" | wc -l | tr -d ' ')
echo "   ✓ $SKILL_COUNT skills installed to $GLOBAL_DIR/skills"

# Mirror skills into ~/.codex/skills/ so Codex can read them via its own path
install_skills "$CODEX_DIR"
CODEX_SKILL_COUNT=$(ls -1 "$CODEX_DIR/skills" | wc -l | tr -d ' ')
echo "   ✓ $CODEX_SKILL_COUNT skills mirrored to $CODEX_DIR/skills"

# Mirror skills into ~/.claude/skills/ so Claude can read them via its own path
CLAUDE_DIR="$HOME/.claude"
install_skills "$CLAUDE_DIR"
CLAUDE_SKILL_COUNT=$(ls -1 "$CLAUDE_DIR/skills" | wc -l | tr -d ' ')
echo "   ✓ $CLAUDE_SKILL_COUNT skills mirrored to $CLAUDE_DIR/skills"

# Apply stubs for ignored skills
echo "🛡️  Applying stubs for ignored skills..."
if [ -f "$SCRIPT_DIR/ignore-skills.txt" ]; then
    while read -r line || [ -n "$line" ]; do
        line="$(printf '%s' "$line" | tr -d '\r')"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" || "$line" == \#* ]] && continue
        skill_name="${line%/}"
        
        stub_content=$(cat <<EOF
---
name: $skill_name
description: This skill has been disabled by the configuration in ignore-skills.txt.
---
**SKILL DISABLED**

This skill has been removed according to the user hidden configuration.
If you are instructed by another skill to use this functionality, please ignore that reference completely.
You do not need to report an error; continue performing your task based on existing tools and skills.
EOF
)
        for tgt_dir in "$GLOBAL_DIR/skills" "$CODEX_DIR/skills" "$CLAUDE_DIR/skills"; do
            if [ -d "$tgt_dir" ]; then
                rm -rf "$tgt_dir/$skill_name"
                mkdir -p "$tgt_dir/$skill_name"
                echo "$stub_content" > "$tgt_dir/$skill_name/SKILL.md"
            fi
        done
        echo "   ✓ Stubbed: $skill_name"
    done < "$SCRIPT_DIR/ignore-skills.txt"
fi

echo ""

# Step 4: Update GEMINI.md (Antigravity)
echo "📝 Step 4/7: Updating Antigravity rules (~/.gemini/GEMINI.md)..."
upsert_block "$GEMINI_MD" "$SCRIPT_DIR/gemini_rule.md"
echo ""

# Step 5: Update CLAUDE.md (Claude Code)
echo "📝 Step 5/7: Updating Claude Code rules (~/.claude/CLAUDE.md)..."
upsert_block "$CLAUDE_MD" "$SCRIPT_DIR/claude_rule.md"
echo ""

# Step 6: Update AGENTS.md (Codex)
echo "📝 Step 6/7: Updating Codex rules (~/.codex/AGENTS.md)..."
upsert_block "$CODEX_MD" "$SCRIPT_DIR/codex_rule.md"
echo ""

# Unity rule: shared block (AG-UNITY markers) appended to all three platforms.
# Lives in a single source file (unity_rule.md) instead of being duplicated per rule file.
if [ -f "$SCRIPT_DIR/unity_rule.md" ]; then
    echo "🎮 Updating shared Unity rule block (AG-UNITY)..."
    upsert_block "$GEMINI_MD" "$SCRIPT_DIR/unity_rule.md" "$UNITY_BEGIN_MARKER" "$UNITY_END_MARKER"
    upsert_block "$CLAUDE_MD" "$SCRIPT_DIR/unity_rule.md" "$UNITY_BEGIN_MARKER" "$UNITY_END_MARKER"
    upsert_block "$CODEX_MD"  "$SCRIPT_DIR/unity_rule.md" "$UNITY_BEGIN_MARKER" "$UNITY_END_MARKER"
    echo ""
fi

# Step 7: Copy AKS.md to platform directories
# NOTE: SPO.md is intentionally NOT copied. Skill bootstrap is handled by the
# `using-superpowers` skill (loaded via the rule files), matching the upstream
# superpowers plugin. The old SPO.md was a mislabeled copy of upstream's
# CLAUDE.md (contributor guidelines) and is no longer used.
echo "📄 Step 7/7: Copying AKS.md to platform directories..."
if [ -f "$SCRIPT_DIR/AKS.md" ]; then
    cp -f "$SCRIPT_DIR/AKS.md" "$HOME/.gemini/AKS.md"
    cp -f "$SCRIPT_DIR/AKS.md" "$HOME/.claude/AKS.md"
    cp -f "$SCRIPT_DIR/AKS.md" "$HOME/.codex/AKS.md"
    echo "   ✓ Copied AKS.md to ~/.gemini, ~/.claude, and ~/.codex"
else
    echo "   ⚠️  AKS.md not found in $SCRIPT_DIR!"
fi
echo ""

# Cleanup old legacy directories if present (including the old setup/ copy —
# scripts are no longer installed to GLOBAL_DIR; run them from the repo)
if [ -d "$GLOBAL_DIR/rules" ] || [ -d "$GLOBAL_DIR/global_workflows" ] || [ -d "$GLOBAL_DIR/setup" ]; then
    echo "🧹 Cleaning up legacy directories..."
    rm -rf "$GLOBAL_DIR/rules" "$GLOBAL_DIR/global_workflows" "$GLOBAL_DIR/setup"
    echo "   ✓ Removed legacy directories"
    echo ""
fi

# Verify
echo "✅ Verification..."
SKILL_TOTAL=$(ls -1 "$GLOBAL_DIR/skills" | wc -l | tr -d ' ')
echo "   Skills:        $SKILL_TOTAL"
if [ -f "$GEMINI_MD" ]; then echo "   GEMINI.md:     ✓"; else echo "   GEMINI.md:     ✗"; fi
if [ -f "$CLAUDE_MD" ]; then echo "   CLAUDE.md:     ✓"; else echo "   CLAUDE.md:     ✗"; fi
if [ -f "$CODEX_MD" ]; then echo "   AGENTS.md:     ✓"; else echo "   AGENTS.md:     ✗"; fi
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Installation Complete                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🚀 Next steps:"
echo "   1. Restart Antigravity / Claude Desktop / Codex"
echo "   2. Rules auto-load from global instruction files"
echo ""
echo "✅ Done!"
