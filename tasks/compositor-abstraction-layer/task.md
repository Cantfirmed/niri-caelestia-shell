# Compositor Abstraction Layer for Upstream Syncs

## Status: Done

## Description
Decouple Niri IPC and custom UI overrides from upstream Caelestia Shell (`caelestia-dots/shell`).
Currently, pulling upstream updates requires resolving merge conflicts and re-verifying protected files (`NIRI-DELTAS.md`), while lingering legacy Hyprland stubs (`services/Hypr.qml`) clutter the codebase.

This task introduces a clean compositor backend interface (`ICompositor`) so upstream shell modules remain compositor-agnostic, and upstream releases can be ported without regressions.

## Checklist
- [x] Audit all direct `Hypr` and `Niri` references across `modules/` and `services/`
- [x] Define standard `Compositor` abstraction API (workspaces, active window, outputs, power/session actions)
- [x] Implement `NiriCompositor.qml` satisfying the interface
- [x] Clean up legacy Hyprland stubs (`services/Hypr.qml`, unused GameMode mocks)
- [x] Update `scripts/port-upstream.sh` and `scripts/verify-deltas.sh` to validate against the abstraction layer
