#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

# Pre-commit hook
cat << 'HOOK_EOF' > "$HOOKS_DIR/pre-commit"
#!/usr/bin/env bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
if [ -x "$REPO_ROOT/scripts/verify-deltas.sh" ]; then
    "$REPO_ROOT/scripts/verify-deltas.sh" || {
        echo ""
        echo "❌ Pre-commit hook failed: A protected Niri customization was deleted or broken."
        echo "   Review NIRI-DELTAS.md and fix the issues above before committing."
        echo "   (Emergency override: git commit --no-verify)"
        exit 1
    }
fi
HOOK_EOF
chmod +x "$HOOKS_DIR/pre-commit"

# Post-merge hook
cat << 'HOOK_EOF' > "$HOOKS_DIR/post-merge"
#!/usr/bin/env bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
if [ -x "$REPO_ROOT/scripts/verify-deltas.sh" ]; then
    "$REPO_ROOT/scripts/verify-deltas.sh" || {
        echo ""
        echo "⚠️  Post-merge warning: A protected Niri customization was overwritten by this merge!"
        echo "   Please review the failures above and restore the deltas documented in NIRI-DELTAS.md."
    }
fi
HOOK_EOF
chmod +x "$HOOKS_DIR/post-merge"

echo "✓ Git hooks installed in $HOOKS_DIR (pre-commit, post-merge)."
