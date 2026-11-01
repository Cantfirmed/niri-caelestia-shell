#!/usr/bin/env bash
# Build Quickshell from source against the Qt currently installed on this system
# and install it to ~/.local/bin/quickshell.
#
# Why this exists: Quickshell links against private Qt APIs (QQuickWindowPrivate,
# QQuickItemPrivate, QtWaylandClientPrivate, ...), so it MUST be rebuilt after every
# Qt upgrade. A stale binary prints
#   "Quickshell was built against Qt X but the system has updated to Qt Y ..."
# and segfaults in places like QQuickItemPrivate::dirty() -> QQuickWindow::maybeUpdate().
#
# The build also applies our local fork patches from patches/quickshell/*.patch.
# See AGENTS.md -> "Building Quickshell locally".
#
# Usage:
#   scripts/build-quickshell.sh              # build master and install
#   QS_REF=v0.3.2 scripts/build-quickshell.sh
#   QS_SRC=/some/dir scripts/build-quickshell.sh
#   NO_INSTALL=1 scripts/build-quickshell.sh # build only
#
# Requirements: cmake, ninja, clang (or gcc), pkg-config, wayland-scanner,
#   qt6-base qt6-declarative qt6-wayland qt6-shadertools, vulkan-headers,
#   cli11 (installed to ~/.local), cpptrace, jemalloc, libdrm, libxcb, pam, polkit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${QS_SRC:-$HOME/.cache/caelestia/quickshell-src}"
BUILD_DIR="${QS_BUILD_DIR:-$SRC_DIR/build}"
INSTALL_BIN="${QS_INSTALL_BIN:-$HOME/.local/bin/quickshell}"
REF="${QS_REF:-master}"
REPO="${QS_REPO:-https://github.com/quickshell-mirror/quickshell}"
JOBS="${QS_JOBS:-$(nproc)}"
CC_BIN="${QS_CC:-clang}"
CXX_BIN="${QS_CXX:-clang++}"

log() { printf '[build-quickshell] %s\n' "$*"; }
die() {
    printf '[build-quickshell] ERROR: %s\n' "$*" >&2
    exit 1
}

# --- prerequisites -----------------------------------------------------------

for cmd in cmake ninja git pkg-config; do
    command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

[ -x "/usr/bin/wayland-scanner" ] || die "missing /usr/bin/wayland-scanner"

if [ ! -f "$HOME/.local/share/cmake/CLI11/CLI11Config.cmake" ] && [ ! -f /usr/lib/cmake/CLI11/CLI11Config.cmake ]; then
    die "CLI11 not found. Install it (sudo pacman -S cli11) or build it into ~/.local:
  git clone --depth 1 --branch v2.5.0 https://github.com/CLIUtils/CLI11 /tmp/cli11
  cmake -S /tmp/cli11 -B /tmp/cli11/build -G Ninja -DCLI11_BUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=\$HOME/.local
  cmake --install /tmp/cli11/build"
fi

SYSTEM_QT="$(pkg-config --modversion Qt6Core 2>/dev/null || echo unknown)"
log "system Qt: $SYSTEM_QT"
log "compiler: $("$CXX_BIN" --version | head -1)"

# --- source ------------------------------------------------------------------

if [ ! -d "$SRC_DIR/.git" ]; then
    log "cloning $REPO into $SRC_DIR"
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone "$REPO" "$SRC_DIR"
else
    log "updating $SRC_DIR"
    git -C "$SRC_DIR" fetch --tags origin
fi

log "checking out $REF"
git -C "$SRC_DIR" checkout --detach "origin/$REF" 2>/dev/null ||
    git -C "$SRC_DIR" checkout --detach "$REF"
git -C "$SRC_DIR" reset --hard HEAD
git -C "$SRC_DIR" clean -fd -- src cmake >/dev/null

# --- local patches -----------------------------------------------------------

shopt -s nullglob
PATCHES=("$SCRIPT_DIR"/patches/quickshell/*.patch)
shopt -u nullglob

if [ ${#PATCHES[@]} -gt 0 ]; then
    for patch in "${PATCHES[@]}"; do
        log "applying $(basename "$patch")"
        if ! git -C "$SRC_DIR" apply --recount "$patch"; then
            die "failed to apply $(basename "$patch") - upstream likely changed, update the patch in patches/quickshell/"
        fi
    done
else
    log "no local patches found in patches/quickshell/"
fi

# --- configure ---------------------------------------------------------------

# NOTE: NO_PCH because clang's precompiled header for the common PCH set is built
# without -pthread, and src/services/polkit compiles with it, which fails with
# "POSIX thread support was disabled in precompiled file ... but is currently enabled".
# NOTE: WaylandScanner is pinned because a conda/anaconda wayland-scanner earlier in
# PATH (1.24) generates protocol code for a newer libwayland-client (1.26).
# NOTE: FRAME_POINTERS keeps crash backtraces readable (Qt frames otherwise unwind
# into nonsense, which cost us hours when chasing the teardown crash).
log "configuring in $BUILD_DIR"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_C_COMPILER="$CC_BIN" \
    -DCMAKE_CXX_COMPILER="$CXX_BIN" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DFRAME_POINTERS=ON \
    -DNO_PCH=ON \
    -DWaylandScanner_EXECUTABLE=/usr/bin/wayland-scanner \
    -DCMAKE_PREFIX_PATH="$HOME/.local" \
    -DDISTRIBUTOR="local build (Qt $SYSTEM_QT)"

# --- build -------------------------------------------------------------------

log "building with $JOBS jobs"
cmake --build "$BUILD_DIR" -j "$JOBS"

BIN="$BUILD_DIR/src/quickshell"
[ -x "$BIN" ] || die "build finished but $BIN is missing"
log "built: $("$BIN" --version)"

if [ "${NO_INSTALL:-0}" = "1" ]; then
    log "NO_INSTALL=1, not installing"
    exit 0
fi

# --- install -----------------------------------------------------------------

mkdir -p "$(dirname "$INSTALL_BIN")"
if [ -x "$INSTALL_BIN" ]; then
    BACKUP="$INSTALL_BIN.bak-$(date +%Y%m%d-%H%M%S)"
    cp -a "$INSTALL_BIN" "$BACKUP"
    log "backed up previous binary to $BACKUP"
fi

# Replace via rename: the old binary may be running and would make `cp` fail with
# ETXTBSY otherwise.
cp "$BIN" "$INSTALL_BIN.new"
chmod 755 "$INSTALL_BIN.new"
mv -f "$INSTALL_BIN.new" "$INSTALL_BIN"
log "installed $("$INSTALL_BIN" --version) -> $INSTALL_BIN"
log "restart the shell to pick it up:  pkill -TERM -f 'quickshell --path .*shell.qml'  (launch-quickshell.sh restarts it)"
