# Native Niri IPC C++ Transaction & Move Batching

## Status: Done

## Description
Eliminate race conditions and UI jitter during window and column drag-and-drop operations on the bar by shifting the asynchronous focus-and-move state machine from QML (`services/Niri.qml`) into the native C++ plugin (`plugin/src/Caelestia/Internal/niriipc.cpp`).

Additionally, upgrade socket communications to consume Niri's long-lived JSON `event-stream` directly in C++, removing all remaining polling timers and ensuring instantaneous shell updates.

## Checklist
- [x] Profile current QML focus-and-move state machine (`_moveAfterFocusPendingCb`, `_seqState`) in `services/Niri.qml`
- [x] Implement atomic column reordering method in C++ (`NiriIpc::moveColumnToIndex(windowId, targetIndex, restoreFocus)`)
- [x] Connect to Niri's `event-stream` socket endpoint for zero-latency push events
- [x] Benchmark CPU usage and event latency during rapid window dragging on the taskbar
- [x] Verify error handling when target window is closed mid-transaction
