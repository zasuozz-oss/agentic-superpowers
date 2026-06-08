#!/bin/bash
# Update Superpowers skills from upstream repository
# Pulls latest skills from obra/superpowers, updates installed skills,
# and syncs changes back to fork repo's global-config/skills/
# Usage: bash setup/update-superpowers.sh  (run from the repo root)

set -e

UPSTREAM_REPO="https://github.com/obra/superpowers.git"
UPSTREAM_BRANCH="main"
GLOBAL_SKILLS_DIR="$HOME/.gemini/config/skills"
# Auto-detect fork repo location
FORK_REPO_DIR=""
SCRIPT_REAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POTENTIAL_FORK="$(cd "$SCRIPT_REAL_PATH/.." && pwd)"
GLOBAL_DIR="$HOME/.gemini/config"

if [ "$POTENTIAL_FORK" != "$GLOBAL_DIR" ] && [ -d "$POTENTIAL_FORK/skills" ]; then
    FORK_REPO_DIR="$POTENTIAL_FORK"
elif [ "$(pwd)" != "$GLOBAL_DIR" ] && [ -d "$(pwd)/skills" ]; then
    FORK_REPO_DIR="$(pwd)"
fi

UPSTREAM_DIR="$FORK_REPO_DIR/superpowers"

# Check if a directory tree can be written to (create/replace/delete files).
_is_writable_recursive() {
    local _dir="$1"
    [ -d "$_dir" ] || return 0
    [ ! -w "$_dir" ] && return 1
    # Only DIRECTORY write permission governs creating/replacing/deleting files
    # inside it — a read-only file (e.g. a 0444 git pack) can still be removed
    # via its writable parent dir. So we check directories only, and prune
    # subtrees we never write into that legitimately contain read-only entries
    # (git internals, code-signed .app bundles, dependency caches). Scanning
    # every file used to misreport those as "permission denied".
    local _d
    while IFS= read -r -d '' _d; do
        if [ ! -w "$_d" ]; then
            return 1
        fi
    done < <(find "$_dir" \( -name '.git' -o -name '*.app' -o -name 'node_modules' \) -prune -o -type d -print0 2>/dev/null)
    return 0
}

# Detect OS for platform-specific permission suggestions
IS_WINDOWS=false
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
    IS_WINDOWS=true
fi

# Check permissions before doing any write operations
PERM_ERRORS=""
CHECK_DIRS=("$GLOBAL_DIR")
if [ -n "$FORK_REPO_DIR" ]; then
    CHECK_DIRS+=("$FORK_REPO_DIR/skills" "$FORK_REPO_DIR/superpowers")
fi

for dir in "${CHECK_DIRS[@]}"; do
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
    echo "❌ Permission denied on some directories or files."
    echo "   Run these commands first to fix ownership, then re-run setup:"
    echo "$PERM_ERRORS"
    echo ""
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Superpowers Update Workflow                           ║"
echo "║     Pull upstream → Update installed → Sync fork repo     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Fetch upstream
echo "🔄 Step 1: Fetching upstream (obra/superpowers)..."
CACHE_DIR="$HOME/.gemini/config/.superpowers-cache"
echo "   Cloning upstream..."
rm -rf "$CACHE_DIR"
git clone --quiet --depth 1 "$UPSTREAM_REPO" "$CACHE_DIR"
echo "   ✓ Cloned"

if [ -n "$FORK_REPO_DIR" ]; then
    # Backup to superpowers directory (so user can commit it) without .git files
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --exclude '.git/' --exclude '.gitignore' --exclude '.gitattributes' "$CACHE_DIR/" "$UPSTREAM_DIR/"
    else
        rm -rf "$UPSTREAM_DIR"
        cp -R "$CACHE_DIR" "$UPSTREAM_DIR"
        rm -rf "$UPSTREAM_DIR/.git"
        rm -f "$UPSTREAM_DIR/.gitignore" "$UPSTREAM_DIR/.gitattributes"
    fi
    echo "   ✓ Backed up to fork repo (plain files)"
fi

# Set the source directory for the rest of the script
UPSTREAM_DIR="$CACHE_DIR"
echo ""

# Step 2: Check for changes
echo "🔍 Step 2: Checking for updates..."
DIFF_FILE="/tmp/superpowers-diff-$(date +%Y%m%d-%H%M%S).txt"

# Build diff exclude arguments dynamically from ignore-skills.txt
DIFF_OPTS=""
while read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r')"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    # Skip empty lines
    if [ -n "$line" ]; then
        # Remove trailing slash for diff -x
        CLEAN_NAME="${line%/}"
        DIFF_OPTS="$DIFF_OPTS -x '$CLEAN_NAME'"
    fi
done < "$SCRIPT_REAL_PATH/ignore-skills.txt"

# Also exclude custom local skills in the repo not in UPSTREAM
if [ -d "$UPSTREAM_DIR/skills/" ] && [ -n "$FORK_REPO_DIR" ] && [ -d "$FORK_REPO_DIR/skills" ]; then
    for local_skill in "$FORK_REPO_DIR/skills"/*; do
        skill_name=$(basename "$local_skill")
        if [ ! -e "$UPSTREAM_DIR/skills/$skill_name" ]; then
            DIFF_OPTS="$DIFF_OPTS -x '$skill_name'"
        fi
    done
fi

TARGET_DIFF_DIR="$FORK_REPO_DIR/skills/"
if [ -z "$FORK_REPO_DIR" ]; then TARGET_DIFF_DIR="$GLOBAL_SKILLS_DIR/"; fi

# Run diff using the dynamically built arguments
eval "diff -r $DIFF_OPTS \"$TARGET_DIFF_DIR\" \"$UPSTREAM_DIR/skills/\" > \"$DIFF_FILE\" 2>&1 || true"

if [ -s "$DIFF_FILE" ]; then
    CHANGED=$(grep -cE "^(Only in|diff)" "$DIFF_FILE" 2>/dev/null || echo "0")
    echo "   ✓ $CHANGED changes found"
    echo ""
else
    echo "   ✓ Already up to date! Proceeding to sync anyway..."
    rm -f "$DIFF_FILE"
fi

# Step 3: Automatically apply updates
echo "📝 Step 3: Syncing updates to local repository..."

if [ -n "$FORK_REPO_DIR" ] && [ -d "$FORK_REPO_DIR/skills" ]; then
    echo "🔄 Syncing upstream skills into $FORK_REPO_DIR/skills..."
    # Build combined exclude list: ignored skills + custom skills (protected from upstream overwrite)
    _EXCL_TMP=$(mktemp)
    grep -v '^#' "$SCRIPT_REAL_PATH/ignore-skills.txt" >> "$_EXCL_TMP" 2>/dev/null || true
    grep -v '^#' "$SCRIPT_REAL_PATH/custom-skill.txt" >> "$_EXCL_TMP" 2>/dev/null || true
    if command -v rsync >/dev/null 2>&1; then
        rsync -av --exclude-from="$_EXCL_TMP" "$UPSTREAM_DIR/skills/" "$FORK_REPO_DIR/skills/"
    else
        mkdir -p "$FORK_REPO_DIR/skills"
        for skill_path in "$UPSTREAM_DIR/skills"/*; do
            [ -e "$skill_path" ] || continue
            skill_name=$(basename "$skill_path")
            if ! grep -qE "^${skill_name}/?(\r)?$" "$_EXCL_TMP" 2>/dev/null; then
                cp -R "$skill_path" "$FORK_REPO_DIR/skills/"
            fi
        done
    fi
    rm -f "$_EXCL_TMP"
    SKILL_COUNT=$(ls -1 "$FORK_REPO_DIR/skills/" | wc -l | tr -d ' ')
    echo "   ✓ Synced $SKILL_COUNT skills to $FORK_REPO_DIR/skills/"
    echo ""
    
    # NOTE: We intentionally do NOT copy upstream CLAUDE.md anywhere.
    # Upstream CLAUDE.md is the project's *contributor/PR guidelines*, not an
    # agent working instruction. Skill bootstrap comes from the `using-superpowers`
    # skill instead (see rule files). The legacy SPO.md mechanism has been removed.
    echo "   📌 Remember to commit changes in the repo:"
    echo "   cd $FORK_REPO_DIR"
    echo "   git add -A && git commit -m 'chore: update skills from upstream'"
else
    echo "❌ Local repository directory not found! Skip syncing."
fi

# Apply stubs for ignored skills
echo "🛡️  Applying stubs for ignored skills in local repository..."
if [ -f "$SCRIPT_REAL_PATH/ignore-skills.txt" ] && [ -n "$FORK_REPO_DIR" ]; then
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
        for tgt_dir in "$FORK_REPO_DIR/skills"; do
            if [ -d "$tgt_dir" ]; then
                rm -rf "$tgt_dir/$skill_name"
                mkdir -p "$tgt_dir/$skill_name"
                echo "$stub_content" > "$tgt_dir/$skill_name/SKILL.md"
            fi
        done
        echo "   ✓ Stubbed: $skill_name"
    done < "$SCRIPT_REAL_PATH/ignore-skills.txt"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Update Complete                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
if [ -n "$FORK_REPO_DIR" ] && [ -d "$FORK_REPO_DIR/skills" ]; then
echo "   - Local repo: ✓ Synced ($SKILL_COUNT skills)"
fi
echo "   - Run: bash setup-global.sh  (to install this new version to your system)"
echo ""
echo "✅ Done!"
