# Tasks

## Doing

## Todo

## Done

- [x] Resume-from-suspend / output-loss SIGSEGV — fixed in Quickshell via
  [patches/quickshell/0001-defer-window-teardown.patch](patches/quickshell/0001-defer-window-teardown.patch)
  (`ProxyWindowBase::deleteWindow()` now defers window destruction past the item
  tree). Rebuild with `scripts/build-quickshell.sh` after every Qt upgrade.
  See `AGENTS.md` → "SIGSEGV on output loss / resume-from-suspend".
  Second patch (`0002-defer-lock-surface-teardown.patch`) covers the same bug in
  `WlSessionLockSurface` (resume while locked). The temporary resume guard was
  removed 2026-11-01. Optional follow-up:
  [Stable Per-Screen Windows](tasks/stable-per-screen-windows/task.md) to avoid
  the visual rebuild on hotplug.

- [x] [Display Settings Engine & Multi-Monitor Hotplug](tasks/display-settings-engine/task.md)
  See [DESIGN.md](tasks/display-settings-engine/DESIGN.md)
- [x] [Native Niri IPC C++ Transaction & Move Batching](tasks/niri-ipc-batch-transactions/task.md)
  See [DESIGN.md](tasks/niri-ipc-batch-transactions/DESIGN.md)
- [x] [Niri Infinite Ribbon Mini-Map for Taskbar](tasks/niri-ribbon-minimap/task.md)
  See [DESIGN.md](tasks/niri-ribbon-minimap/DESIGN.md)
- [x] [Compositor Abstraction Layer for Upstream Syncs](tasks/compositor-abstraction-layer/task.md)
  See [DESIGN.md](tasks/compositor-abstraction-layer/DESIGN.md)
- [x] [Biri Shaders Live Uniform Studio & M3 Palette Binding](tasks/biri-shader-uniform-studio/task.md)
  See [DESIGN.md](tasks/biri-shader-uniform-studio/DESIGN.md)
- [x] Try to get better Utility Panel mouse over
