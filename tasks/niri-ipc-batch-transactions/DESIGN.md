# Design: Native Niri IPC C++ Transaction & Move Batching

## Overview
In Niri, column moves (`move-column-to-index`) operate exclusively on the currently focused column.
Because moving an unfocused column or reordering grouped icons on the bar requires focusing the window first, waiting for the compositor to acknowledge focus, sending the move action, and restoring initial focus, `services/Niri.qml` currently implements a multi-step asynchronous state machine using `focusedWindowIdChanged` signal watchers.

If user input or another compositor event occurs while this multi-turn handshake is in-flight, focus can be lost or windows can land in incorrect indices.

## Architecture & Implementation

### 1. Atomic Transaction Runner in C++
In `plugin/src/Caelestia/Internal/niriipc.cpp`:
- Implement a transaction worker queue:
  ```cpp
  struct ColumnMoveTransaction {
      uint64_t windowId;
      int targetIndex;
      uint64_t originalFocusWindowId;
      std::function<void(bool success)> callback;
  };
  ```
- Send `{ "Action": { "FocusWindow": { "id": windowId } } }`.
- Upon receiving confirmation on the socket, immediately dispatch `{ "Action": { "MoveColumnToIndex": { "index": targetIndex } } }`.
- Immediately dispatch `{ "Action": { "FocusWindow": { "id": originalFocusWindowId } } }`.
- Expose this cleanly to QML: `NiriIpc.reorderColumn(windowId, targetIndex)`.

### 2. Native `event-stream` Integration
- Niri provides `niri msg --json event-stream` over `/run/user/$UID/niri*.sock`.
- In `nirisocket.cpp`, establish a persistent streaming socket connection that listens continuously for newline-delimited JSON events:
  - `WorkspaceActivated`
  - `WorkspacesChanged`
  - `WindowOpenedOrChanged`
  - `WindowClosed`
  - `WindowFocusChanged`
  - `LayoutChanged`
- Dispatch strongly-typed Qt signals directly to QML, deprecating ad-hoc polling and query loops.
