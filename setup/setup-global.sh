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

# ─── Custom skill filtering ─────────────────────────────────────────────────
# custom-skill.txt lists local-only skills (not from upstream) to deploy.
# Skills absent from both upstream and custom-skill.txt are skipped.
CUSTOM_SKILLS_FILE="$SCRIPT_DIR/custom-skill.txt"
UPSTREAM_SKILLS_DIR="$SCRIPT_DIR/../superpowers/skills"
CUSTOM_SKILL_NAMES=()
if [ -f "$CUSTOM_SKILLS_FILE" ]; then
    while read -r _cs_line || [ -n "$_cs_line" ]; do
        _cs_line="$(printf '%s' "$_cs_line" | tr -d '\r')"
        _cs_line="$(echo "$_cs_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$_cs_line" || "$_cs_line" == \#* ]] && continue
        CUSTOM_SKILL_NAMES+=("${_cs_line%/}")
    done < "$CUSTOM_SKILLS_FILE"
fi

_should_deploy_skill() {
    local _name="$1"
    [ -d "$UPSTREAM_SKILLS_DIR/$_name" ] && return 0
    for _cs in "${CUSTOM_SKILL_NAMES[@]}"; do
        [ "$_cs" = "$_name" ] && return 0
    done
    [ ! -f "$CUSTOM_SKILLS_FILE" ] && return 0
    return 1
}

# Copy only the skills Claude/Codex need ON DISK alongside the native plugin:
#   - using-superpowers : required by the @import bootstrap in the rule files
#   - every name in custom-skill.txt : local-only skills not provided by upstream
# Replaces ONLY those specific folders — never wipes the whole skills dir, so a
# user's own skills in ~/.claude/skills or ~/.codex/skills are preserved.
# Also removes stale upstream skill copies left by older full-copy setups: any
# folder whose name matches an upstream skill (now served by the native plugin)
# and is NOT in the keep-list is deleted to avoid duplicate skill discovery.
_install_custom_skills() {
    local _dest="$1"
    mkdir -p "$_dest"
    local _keep=("using-superpowers" "${CUSTOM_SKILL_NAMES[@]}")

    # Cleanup: drop redundant on-disk copies of upstream skills.
    local _up _upn _k _is_kept
    for _up in "$SCRIPT_DIR/../superpowers/skills"/*/; do
        [ -d "$_up" ] || continue
        _upn="$(basename "$_up")"
        _is_kept=false
        for _k in "${_keep[@]}"; do
            [ "$_upn" = "$_k" ] && { _is_kept=true; break; }
        done
        if [ "$_is_kept" = false ] && [ -d "$_dest/$_upn" ]; then
            rm -rf "$_dest/$_upn"
        fi
    done

    # Install the keep-list folders (sourced from the repo's skills/).
    local _n
    for _n in "${_keep[@]}"; do
        if [ -d "$SCRIPT_DIR/../skills/$_n" ]; then
            rm -rf "$_dest/$_n"
            cp -R "$SCRIPT_DIR/../skills/$_n" "$_dest/$_n"
        fi
    done
}

# Convert a Git Bash (/c/...) path to a native Windows path so the Node/Rust
# CLIs (claude, codex) receive a path they can resolve. No-op off Windows.
_winpath() {
    if [ "$IS_WINDOWS" = true ] && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

# Run a command with a finite timeout when `timeout` is available; never hang.
_run_bounded() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 180 "$@"
    else
        "$@"
    fi
}

# Check if a directory and all its contents are writable.
_is_writable_recursive() {
    local _dir="$1"
    [ -d "$_dir" ] || return 0
    [ ! -w "$_dir" ] && return 1
    # Only DIRECTORY write permission governs creating/replacing/deleting files
    # inside it — a read-only file (e.g. a 0444 git pack) can still be removed
    # via its writable parent dir. So we check directories only, and prune
    # subtrees the setup never writes into that legitimately contain read-only
    # entries (git internals, code-signed .app bundles, dependency caches).
    # Scanning every file used to misreport those as "permission denied".
    local _d
    while IFS= read -r -d '' _d; do
        if [ ! -w "$_d" ]; then
            return 1
        fi
    done < <(find "$_dir" \( -name '.git' -o -name '*.app' -o -name 'node_modules' \) -prune -o -type d -print0 2>/dev/null)
    return 0
}

# Install the upstream superpowers plugin natively (marketplace add + install)
# for Claude or Codex — the "install via hook" path: the plugin provides all
# upstream skills (and, on Claude, the SessionStart bootstrap hook), so no skills
# are copied. The two CLIs read DIFFERENT marketplace manifests:
#   Claude → superpowers/.claude-plugin/marketplace.json  (plugin source "./")
#   Codex  → <repo-root>/.agents/plugins/marketplace.json (plugin source "./superpowers";
#            Codex requires the plugin in a SUBDIR, so the repo root is the market root)
# Codex does NOT consume the Claude-format hooks.json, so its bootstrap comes from
# the @import in AGENTS.md (the on-disk fallback) rather than a native hook.
# $1 = claude | codex
_install_plugin() {
    local _tool="$1"
    local _repo_root="$SCRIPT_DIR/.."

    case "$_tool" in
        claude)
            if [ ! -f "$_repo_root/superpowers/.claude-plugin/marketplace.json" ]; then
                echo "   ⚠️  claude: superpowers/.claude-plugin/marketplace.json missing — run update-superpowers.sh first. Skipping."
                return 0
            fi
            if ! command -v claude >/dev/null 2>&1; then
                echo "   ⚠️  'claude' CLI not found — skipping native plugin install"
                return 0
            fi
            local _src
            _src="$(_winpath "$_repo_root/superpowers")"
            _run_bounded claude plugin marketplace add "$_src" --scope user >/dev/null 2>&1 \
                || _run_bounded claude plugin marketplace update superpowers-dev >/dev/null 2>&1 || true
            if _run_bounded claude plugin install superpowers@superpowers-dev --scope user >/dev/null 2>&1; then
                echo "   ✓ Claude: superpowers plugin installed (hook + upstream skills)"
            else
                echo "   ⚠️  Claude plugin install failed. Run manually:"
                echo "        claude plugin marketplace add \"$_src\" && claude plugin install superpowers@superpowers-dev"
            fi
            ;;
        codex)
            if [ ! -f "$_repo_root/.agents/plugins/marketplace.json" ]; then
                echo "   ⚠️  codex: .agents/plugins/marketplace.json missing at repo root. Skipping."
                return 0
            fi
            if ! command -v codex >/dev/null 2>&1; then
                echo "   ⚠️  'codex' CLI not found — skipping native plugin install"
                return 0
            fi
            local _src
            _src="$(_winpath "$_repo_root")"
            # Local marketplaces don't refresh via `upgrade` (Git-only) — remove + re-add
            # to pick up a changed manifest snapshot.
            _run_bounded codex plugin marketplace remove superpowers-dev >/dev/null 2>&1 || true
            _run_bounded codex plugin marketplace add "$_src" >/dev/null 2>&1 || true
            if _run_bounded codex plugin add superpowers@superpowers-dev >/dev/null 2>&1; then
                echo "   ✓ Codex: superpowers plugin installed (upstream skills; bootstrap via AGENTS.md @import)"
            else
                echo "   ⚠️  Codex plugin add failed. Run manually:"
                echo "        codex plugin marketplace add \"$_src\" && codex plugin add superpowers@superpowers-dev"
            fi
            ;;
    esac
}

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

# Check if source directories exist
if [ ! -d "$SCRIPT_DIR/../skills" ]; then
    echo "❌ Error: skills/ not found"
    echo "   Make sure you are running this from the repository root"
    exit 1
fi

# Step 1/8: Create directories & check permissions
echo "📁 Step 1/8: Creating config directories & checking permissions..."
mkdir -p "$GLOBAL_DIR" "$CODEX_DIR" "$(dirname "$GEMINI_MD")" "$(dirname "$CLAUDE_MD")"

PERM_ERRORS=""
for dir in "$GLOBAL_DIR" "$CODEX_DIR" "$(dirname "$GEMINI_MD")" "$(dirname "$CLAUDE_MD")" "$SCRIPT_DIR/../skills" "$SCRIPT_DIR/../superpowers"; do
    if [ -d "$dir" ] && ! _is_writable_recursive "$dir"; then
        if [ "$IS_WINDOWS" = true ]; then
            PERM_ERRORS="$PERM_ERRORS
      icacls \"$(cygpath -w "$dir")\" /grant %USERNAME%:F /T"
        else
            PERM_ERRORS="$PERM_ERRORS
      sudo chown -R \$(whoami) \"$dir\""
        fi
    fi
done

if [ -n "$PERM_ERRORS" ]; then
    echo "   ❌ Permission denied on some directories or files."
    echo "   Run these commands first to fix ownership, then re-run setup:"
    echo "$PERM_ERRORS"
    echo ""
    exit 1
fi
echo "   ✓ All directories ready"
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
#   Antigravity (Gemini): NO plugin/hook system → gets a FULL copy of every skill.
#   Claude + Codex: install the upstream superpowers PLUGIN natively (ships the
#     SessionStart bootstrap hook + all upstream skills) and copy only the custom
#     skills (+ using-superpowers for the @import bootstrap) onto disk.
echo "📚 Step 3/8: Installing skills..."
CLAUDE_DIR="$HOME/.claude"

# Warn about orphan skills (not upstream and not in custom-skill.txt)
_orphans=()
for _sp in "$SCRIPT_DIR/../skills"/*/; do
    [ -d "$_sp" ] || continue
    _sn="$(basename "$_sp")"
    _should_deploy_skill "$_sn" || _orphans+=("$_sn")
done
[ ${#_orphans[@]} -gt 0 ] && echo "   ℹ️  Orphan skills skipped (add to custom-skill.txt to deploy): ${_orphans[*]}"

# ── Antigravity: full copy of all skills (manifest-based, foreign-skill safe) ─
install_skills "$GLOBAL_DIR"
SKILL_COUNT=$(ls -1 "$GLOBAL_DIR/skills" | wc -l | tr -d ' ')
echo "   ✓ Antigravity: $SKILL_COUNT skills copied to $GLOBAL_DIR/skills"

# ── Claude + Codex: native plugin install (upstream via hook) ──────────────
echo "   🔌 Installing upstream superpowers plugin (Claude & Codex)..."
_install_plugin claude
_install_plugin codex

# ── Claude + Codex: custom skills (+ using-superpowers bootstrap) on disk ───
_install_custom_skills "$CODEX_DIR/skills"
_install_custom_skills "$CLAUDE_DIR/skills"
echo "   ✓ Custom skills copied to ~/.claude/skills and ~/.codex/skills: using-superpowers ${CUSTOM_SKILL_NAMES[*]}"

# Apply stubs for ignored skills.
# Only the Antigravity full copy and the repo source need stubbing — Claude/Codex
# run the native plugin (pristine upstream); their disabled-skill behavior is
# governed by the rule files / CLAUDE.md overrides, not by on-disk stubs.
echo "🛡️  Applying stubs for ignored skills (Antigravity + repo source)..."
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
        for tgt_dir in "$GLOBAL_DIR/skills" "$SCRIPT_DIR/../skills"; do
            [ -d "$tgt_dir" ] || continue
            skill_path="$tgt_dir/$skill_name"
            # Skip targets we cannot modify (e.g. root-owned files from a past
            # sudo run). Removing/overwriting them would need sudo; instead we
            # warn and move on so the setup stays idempotent and non-blocking.
            if [ -e "$skill_path" ] && [ ! -w "$tgt_dir" ]; then
                echo "   ⚠️  Skipped (not writable, needs different ownership): $skill_path"
                continue
            fi
            if ! rm -rf "$skill_path" 2>/dev/null; then
                echo "   ⚠️  Skipped (cannot remove, needs different ownership): $skill_path"
                continue
            fi
            mkdir -p "$skill_path"
            echo "$stub_content" > "$skill_path/SKILL.md"
            echo "   ✓ Stubbed: $skill_name (in $tgt_dir)"
        done
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
echo "   1. Restart Antigravity / Claude Code / Codex"
echo "   2. Rules auto-load from global instruction files"
echo "   3. Claude/Codex: the superpowers plugin loads upstream skills + the"
echo "      SessionStart bootstrap hook. Verify with:"
echo "        claude plugin list        # expect: superpowers@superpowers-dev"
echo "        codex  plugin list        # expect: superpowers"
echo "   4. Antigravity gets the full skill copy under ~/.gemini/config/skills"
echo ""
echo "✅ Done!"
