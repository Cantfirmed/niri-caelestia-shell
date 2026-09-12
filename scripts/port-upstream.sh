#!/usr/bin/env bash
set -euo pipefail

# port-upstream.sh — diff, review, and apply upstream caelestia-dots/shell changes
#
# Usage:
#   ./scripts/port-upstream.sh v2.0.1 v2.0.2           # Show diff between two tags
#   ./scripts/port-upstream.sh v2.0.1 v2.0.2 --apply   # Apply via git am (if clean)
#   ./scripts/port-upstream.sh v2.0.1 v2.0.2 --patch   # Generate .patch files
#
# Requires: git remote "upstream" pointing at https://github.com/caelestia-dots/shell.git

REPO_ROOT="$(git rev-parse --show-toplevel)"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
FILTER="$REPO_ROOT/.pi/upstream-files.txt"
PROTECTED="$REPO_ROOT/.pi/protected-files.txt"

if [ ! -f "$FILTER" ]; then
    echo "Error: $FILTER not found. Run from repo root."
    exit 1
fi

FROM="${1:?Usage: $0 <from-tag> <to-tag> [--apply|--patch]}"
TO="${2:?Usage: $0 <from-tag> <to-tag> [--apply|--patch]}"
ACTION="${3:-}"

echo "==> Fetching upstream tags..."
git fetch "$UPSTREAM_REMOTE" --tags 2>&1 | tail -1

FROM_REF="$UPSTREAM_REMOTE/$FROM"
TO_REF="$UPSTREAM_REMOTE/$TO"

# Resolve tag or branch
if ! git rev-parse --verify "$FROM_REF" &>/dev/null; then
    FROM_REF="$FROM"
fi
if ! git rev-parse --verify "$TO_REF" &>/dev/null; then
    TO_REF="$TO"
fi

# Build protected exclusions
PROTECTED_EXCLUDES=()
PROTECTED_LIST=()
if [ -f "$PROTECTED" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        PROTECTED_EXCLUDES+=(":!$line")
        PROTECTED_LIST+=("$line")
    done < "$PROTECTED"
fi

echo "==> Changes from $FROM_REF to $TO_REF (shared files only, protected files excluded):"
echo ""

# Check if upstream modified any protected files
if [ ${#PROTECTED_LIST[@]} -gt 0 ]; then
    PROTECTED_DIFF=$(git diff "$FROM_REF" "$TO_REF" -- "${PROTECTED_LIST[@]}" --stat || true)
    if [ -n "$PROTECTED_DIFF" ]; then
        echo "⚠️  NOTE: Upstream modified the following PROTECTED files."
        echo "   These are excluded automatically to prevent regressions:"
        echo "$PROTECTED_DIFF"
        echo ""
    fi
fi

# Generate the filtered diff
DIFF_FILE=$(mktemp /tmp/upstream-diff-XXXXXX.patch)
trap 'rm -f "$DIFF_FILE"' EXIT

git diff "$FROM_REF" "$TO_REF" -- $(cat "$FILTER") "${PROTECTED_EXCLUDES[@]}" > "$DIFF_FILE"

if [ ! -s "$DIFF_FILE" ]; then
    echo "No eligible changes to shared files between $FROM and $TO."
    exit 0
fi

# Show summary
echo "Changed files to be patched:"
git diff "$FROM_REF" "$TO_REF" -- $(cat "$FILTER") "${PROTECTED_EXCLUDES[@]}" --stat
echo ""
echo "Full diff saved to: $DIFF_FILE"
echo ""

case "$ACTION" in
    --apply)
        echo "==> Applying patch..."
        # Use -p1 because the diff paths are relative to repo root
        git apply --recount -p1 "$DIFF_FILE"
        echo "Patch applied. Reviewing with verify-deltas.sh..."
        "$REPO_ROOT/scripts/verify-deltas.sh"
        echo "Done. Run 'git diff --stat' to review."
        ;;
    --patch)
        cp "$DIFF_FILE" "upstream-${FROM}-${TO}.patch"
        echo "Patch saved as: upstream-${FROM}-${TO}.patch"
        ;;
    "")
        # Just show the diff
        echo "==> Preview (full diff):"
        echo "────────────────────────────────────────"
        cat "$DIFF_FILE"
        echo "────────────────────────────────────────"
        echo ""
        echo "To apply: $0 $FROM $TO --apply"
        echo "To save patch: $0 $FROM $TO --patch"
        ;;
esac
