#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Cantfirmed/niri-caelestia-shell.git"
INSTALL_DIR="${1:-$HOME/.config/quickshell/niri-caelestia-shell}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}::${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; exit 1; }

# ── Check we're on Arch ───────────────────────────────────────────────
if [ ! -f /etc/arch-release ] && [ ! -f /etc/os-release ] || ! grep -qi 'arch' /etc/os-release 2>/dev/null; then
    err "This install script is for Arch Linux only."
fi
ok "Arch Linux detected"

# ── Install dependencies ──────────────────────────────────────────────
if ! pacman -Qi niri-caelestia-shell-meta &>/dev/null; then
    info "Installing metapackage for all dependencies..."

    if ! command -v makepkg &>/dev/null; then
        err "makepkg not found — are you sure this is Arch?"
    fi

    WORKDIR=$(mktemp -d)
    pushd "$WORKDIR" >/dev/null

    git clone --depth=1 "$REPO_URL" .
    makepkg -si --noconfirm

    popd >/dev/null
    rm -rf "$WORKDIR"

    ok "Metapackage installed"
fi

# ── Clone / update the repo ───────────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Updating existing install at $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
else
    info "Cloning to $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
fi
ok "Repository ready at $INSTALL_DIR"

cd "$INSTALL_DIR"

# ── Build C++ plugin ──────────────────────────────────────────────────
if [ ! -d build/plugin ]; then
    info "Building C++ QML plugin..."
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    ok "Plugin built"
else
    info "Plugin already built — skipping (rm -rf build/ to rebuild)"
fi

# ── Symlink niri config ───────────────────────────────────────────────
if [ ! -L "$HOME/.config/niri" ] && [ ! -d "$HOME/.config/niri" ]; then
    info "Symlinking niri config..."
    ln -s "$INSTALL_DIR/niri" "$HOME/.config/niri"
    ok "Niri config symlinked"
elif [ "$(readlink -f "$HOME/.config/niri")" = "$(readlink -f "$INSTALL_DIR/niri")" ]; then
    ok "Niri config already symlinked"
else
    warn "$HOME/.config/niri already exists and isn't the shell's config."
    warn "Check the README for how to cherry-pick the bits you want."
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Niri-Caelestia Shell is installed! 🚀${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "    1. Restart niri (or log out and back in)"
echo "    2. Press Super+Space to open the launcher"
echo "    3. Press Super+D  to open the dashboard"
echo ""
echo "  Have fun! 🌌"
echo ""
