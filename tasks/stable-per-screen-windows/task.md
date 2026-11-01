# Stable Per-Screen Windows Across Output Hotplug

## Status: Superseded (optional, quality-of-life only)

> **Superseded 2026-10-31.** The SIGSEGV this task was written for is fixed at the
> root in Quickshell itself: `ProxyWindowBase::deleteWindow()` destroyed the backing
> `QQuickWindow` while its QML item tree was still alive. Our local patch
> `patches/quickshell/0001-defer-window-teardown.patch` defers the destruction by one
> event loop iteration, and 5+ consecutive `niri msg output HDMI-A-1 off/on` cycles
> produce no coredumps. See `AGENTS.md` → "SIGSEGV on output loss / resume-from-suspend
> (dangling `QQuickWindow`)".
>
> The crash therefore does **not** require keeping per-screen windows alive, and
> `scripts/quickshell-resume-guard.sh` is no longer needed once a real suspend/resume
> has been verified. This task is kept only because the destroy/recreate churn still
> causes a brief visual rebuild of the bar/wallpaper on hotplug. Treat it as an
> optional polish task, not a crash fix.

## Description (original)

Stop Quickshell from destroying and recreating every per-screen window when the
set of outputs changes transiently.

On wake the external monitor renegotiates its DRM link, the compositor reports
zero outputs for a moment (`qt.qpa: There are no outputs - creating placeholder
screen`), `services/Screens.qml` filters that down to an empty list, and every
`Variants { model: Screens.screens }` tears its window down. When the output
returns, the windows are rebuilt.

## Approach

1. **Key the window set by screen name, not by `ShellScreen` object.**
   - Add to `services/Screens.qml`: a sticky `list<string> names` (screens seen
     since shell start / last N seconds) and a `function byName(name)` that
     resolves the live `ShellScreen`, or `null` when the output is currently gone.
   - Never store `ShellScreen` objects across updates: `QuickshellTracked::updateScreens()`
     `deleteLater()`s the wrappers, so holding one is a use-after-free
     (quickshell#1228).
2. **Keep windows alive, hide instead of destroy.**
   - `Variants { model: Screens.names }` in `modules/drawers/Drawers.qml`,
     `modules/background/Background.qml`, `modules/areapicker/AreaPicker.qml`,
     and `services/Brightness.qml`; resolve `screen: Screens.byName(name)` and
     add `visible: screen !== null` so a window never lands on the remaining
     output.
   - Decide how `Exclusions`, `ShellState.forScreen(...)` and `Config.forScreen(...)`
     behave while a name has no live screen (they all take/derive from a screen).
3. **Grace period for genuine unplug.** Drop a name (and thus destroy its window)
   only after it has been absent for a few seconds *and* the topology is stable,
   so a real unplug still reclaims resources while a 1–3s wake hiccup does not
   churn anything.
4. **Lock surfaces.** `modules/lock/` uses `Quickshell.screens` per output; check
   whether it needs the same treatment (quickshell#1155 / #503 are the same class
   of bug for `WlSessionLockSurface`).
5. Once verified, remove the `onResumed` restart hook from `modules/IdleMonitors.qml`
   and delete `scripts/quickshell-resume-guard.sh` (or keep the script as an
   opt-in emergency lever).

## Affected files

- `services/Screens.qml` (new `names`/`byName` API, grace timer)
- `modules/drawers/Drawers.qml`
- `modules/background/Background.qml`
- `modules/areapicker/AreaPicker.qml`
- `services/Brightness.qml`
- `services/ShellState.qml` (two `Variants { model: Screens.screens }` blocks)
- `modules/lock/` (if lock surfaces are switched over)
- `modules/IdleMonitors.qml` (remove the resume hook afterwards)

## Risks

- A `PanelWindow` with `screen: null` must not appear on the remaining output —
  gate with `visible`.
- Creating a window for a name that has no screen yet may produce Wayland
  warnings or a surface on the primary output; verify with an output off/on run.
- `ShellState`/`Config.forScreen` expect a screen; passing a name-only key can
  change config lookups (`GlobalConfig.forScreen(name)` takes a string, so this
  is the safer path).
- Persistent panel state (`DrawerVisibilities`) is keyed per screen; make sure a
  removed/re-added output keeps its saved visibilities.

## Validation

- `niri msg output HDMI-A-1 off` → `on` cycle: bar/wallpaper must not flicker
  rebuild and no "Cannot use same item on different windows" warnings.
  (Crash-free is already guaranteed by the Quickshell teardown patch.)
- Unplug HDMI for > grace period: window is really destroyed, no leaked
  surfaces (`qs -c niri-caelestia-shell ipc show` still responsive).
- Run `scripts/verify-deltas.sh`.
