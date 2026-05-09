#!/bin/bash
set -e

GLOBAL_DIR="$HOME/.gemini/antigravity"
CODEX_DIR="$HOME/.codex"
CLAUDE_DIR="$HOME/.claude"

GEMINI_MD="$HOME/.gemini/GEMINI.md"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CODEX_MD="$HOME/.codex/AGENTS.md"

remove_block() {
    local target_file="$1"
    if [ -f "$target_file" ] && grep -qF "<!-- AG-SUPERPOWERS:BEGIN -->" "$target_file"; then
        python3 -c "
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
begin = sys.argv[2]
end = sys.argv[3]
start_idx = content.find(begin)
end_idx = content.find(end)
if start_idx != -1 and end_idx != -1:
    end_idx += len(end)
    if start_idx > 0 and content[start_idx-1] == '\n':
        start_idx -= 1
    content = content[:start_idx] + content[end_idx:]
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "$target_file" "<!-- AG-SUPERPOWERS:BEGIN -->" "<!-- AG-SUPERPOWERS:END -->"
        echo "   ✓ Removed rules block from $target_file"
    else
        echo "   ✓ No superpowers rules found in $target_file"
    fi
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Superpowers Auto-Clean                                 ║"
echo "║     Removes global skills and blocks from all platforms    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  This will remove skills and strip AG-SUPERPOWERS blocks from your markdown files."
read -p "Confirm? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "   Cancelled"
    exit 0
fi

echo ""
echo "🧹 Step 1/2: Removing installed skills from all platforms..."
for dir in "$GLOBAL_DIR/skills" "$CODEX_DIR/skills" "$CLAUDE_DIR/skills"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir/"*
        echo "   ✓ Skills removed from $dir"
    else
        echo "   ✓ No skills folder found at $dir"
    fi
done

echo ""
echo "📝 Step 2/2: Removing global instructions blocks..."
remove_block "$GEMINI_MD"
remove_block "$CODEX_MD"
remove_block "$CLAUDE_MD"

echo ""
echo "✅ Cleanup Complete!"
