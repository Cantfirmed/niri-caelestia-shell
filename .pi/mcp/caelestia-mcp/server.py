"""
Caelestia MCP Server — Niri + Quickshell + Caelestia Shell management tools.

Provides an MCP interface for the coding agent to:
- Inspect and control niri windows/workspaces/monitors
- Interact with the quickshell shell via IPC
- Manage caelestia-specific operations (plugin rebuild, theming, wallpaper)
- Read project documentation as MCP resources
"""

import json
import subprocess
import time
from pathlib import Path
from typing import Optional

from mcp.server.fastmcp import FastMCP

# ── Path constants ──────────────────────────────────────────────
PROJECT_ROOT = Path("/home/patrick/.config/dfm/profiles/caelestia/niri_caelestia")
SHELL_JSON = PROJECT_ROOT / "shell.json"
AGENTS_MD = PROJECT_ROOT / "AGENTS.md"
BUILD_DIR = PROJECT_ROOT / "build"
NIRI_CONFIG = Path.home() / ".config/niri"

QS_CONFIG = "niri-caelestia-shell"

mcp = FastMCP("CaelestiaMCP")


# ═══════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════

def _niri_msg_json(subcommand: str) -> str:
    """Run 'niri msg --json <subcommand>' and return stdout or error."""
    try:
        result = subprocess.run(
            ["niri", "msg", "--json", subcommand],
            capture_output=True, text=True, check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"


def _qs(*args: str) -> tuple[int, str, str]:
    """Run 'qs -c <QS_CONFIG> *args' and return (returncode, stdout, stderr)."""
    cmd = ["qs", "-c", QS_CONFIG, *args]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode, result.stdout.strip(), result.stderr.strip()


# ═══════════════════════════════════════════════════════════════
#  NIRI TOOLS — window/compositor introspection & control
# ═══════════════════════════════════════════════════════════════

@mcp.tool()
def niri_get_windows() -> str:
    """Get all open niri windows with full details (id, title, app_id, pid, workspace, layout, floating state). JSON output."""
    return _niri_msg_json("windows")


@mcp.tool()
def niri_get_workspaces() -> str:
    """Get all niri workspaces with their indices, outputs, focus state, and active window IDs. JSON output."""
    return _niri_msg_json("workspaces")


@mcp.tool()
def niri_get_outputs() -> str:
    """Get all connected outputs (monitors) with their names, manufacturers, modes, and current state. JSON output."""
    return _niri_msg_json("outputs")


@mcp.tool()
def niri_get_focused() -> str:
    """Get the currently focused window (id, title, app_id, pid, workspace, geometry). JSON output."""
    return _niri_msg_json("focused-window")


@mcp.tool()
def niri_get_focused_output() -> str:
    """Get the currently focused output/monitor info. JSON output."""
    return _niri_msg_json("focused-output")


@mcp.tool()
def niri_get_overview_state() -> str:
    """Get whether the niri overview (expose-like) is currently open. JSON output."""
    return _niri_msg_json("overview-state")


@mcp.tool()
def niri_get_keyboard_layouts() -> str:
    """Get the currently configured keyboard layouts and their active indices. JSON output."""
    return _niri_msg_json("keyboard-layouts")


@mcp.tool()
def niri_get_layers() -> str:
    """List all open layer-shell surfaces (panels, bars, overlays, lock screens). JSON output."""
    return _niri_msg_json("layers")


@mcp.tool()
def niri_get_casts() -> str:
    """List active screencasts (screen recording sessions). JSON output."""
    return _niri_msg_json("casts")


@mcp.tool()
def niri_action(action: str, window_id: Optional[int] = None) -> str:
    """
    Execute any niri action. Common actions:
    Focus: focus-window, focus-window-previous, focus-window-up/down/top/bottom,
           focus-floating, focus-tiling, switch-focus-between-floating-and-tiling
    Move: move-window-up/down, move-window-to-floating/tiling,
          toggle-window-floating, move-window-up-or-to-workspace-up,
          move-window-down-or-to-workspace-down, move-window-to-workspace-down/up,
          move-window-to-monitor-left/right/up/down/next/previous
    Layout: maximize-column, maximize-window-to-edges,
            expand-column-to-available-width, reset-window-height, swap-window-left
    Column: move-column-left/right, move-column-to-index
    Other: close-window, toggle-overview, open-overview, close-overview
    Optionally specify window_id to target a specific window.
    """
    cmd = ["niri", "msg", "action", action]
    if window_id is not None:
        if action.startswith("move-column"):
            cmd.extend(["--column-id", str(window_id)])
        else:
            cmd.extend(["--id", str(window_id)])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip() or f"Action '{action}' executed successfully."
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"


@mcp.tool()
def niri_move_window_to_workspace(workspace: str, window_id: Optional[int] = None) -> str:
    """Move a window to a specific workspace by index (e.g. '1') or name."""
    return niri_action("move-window-to-workspace", window_id)


@mcp.tool()
def niri_move_column_to_workspace(workspace: str, column_id: Optional[int] = None) -> str:
    """Move an entire column to a specific workspace by index or name."""
    return niri_action("move-column-to-workspace", column_id)


@mcp.tool()
def niri_close_window(window_id: Optional[int] = None) -> str:
    """Close a window by ID, or the currently focused window if no ID given."""
    return niri_action("close-window", window_id)


@mcp.tool()
def niri_set_window_size(
    width: Optional[str] = None,
    height: Optional[str] = None,
    window_id: Optional[int] = None,
) -> str:
    """
    Resize a window. Values can be pixels ('800'), percentage ('50%'), or relative ('+50', '-10').
    For floating windows, use niri_action with move-floating-window.
    """
    results = []
    if width is not None:
        cmd = ["niri", "msg", "action", "set-window-width", str(width)]
        if window_id:
            cmd.extend(["--id", str(window_id)])
        try:
            subprocess.run(cmd, capture_output=True, text=True, check=True)
            results.append(f"Width set to {width}: OK")
        except subprocess.CalledProcessError as e:
            results.append(f"Width: {e.stderr.strip()}")

    if height is not None:
        cmd = ["niri", "msg", "action", "set-window-height", str(height)]
        if window_id:
            cmd.extend(["--id", str(window_id)])
        try:
            subprocess.run(cmd, capture_output=True, text=True, check=True)
            results.append(f"Height set to {height}: OK")
        except subprocess.CalledProcessError as e:
            results.append(f"Height: {e.stderr.strip()}")

    return "\n".join(results) if results else "No size changes requested."


@mcp.tool()
def niri_set_column_width(width: str, column_id: Optional[int] = None) -> str:
    """Set the width of a column. width can be pixels, percentage, or relative."""
    cmd = ["niri", "msg", "action", "set-column-width", str(width)]
    if column_id is not None:
        cmd.extend(["--id", str(column_id)])
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return f"Column width set to {width}."
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"


# ═══════════════════════════════════════════════════════════════
#  QUICKSHELL TOOLS — shell lifecycle & IPC
# ═══════════════════════════════════════════════════════════════

@mcp.tool()
def qs_status() -> str:
    """Check whether the quickshell instance (niri-caelestia-shell) is running."""
    rc, stdout, stderr = _qs("list")
    if rc != 0:
        return f"Error checking quickshell status: {stderr}"
    if QS_CONFIG in stdout:
        return f"Quickshell '{QS_CONFIG}' is running.\n\n{stdout}"
    return f"Quickshell '{QS_CONFIG}' is NOT running.\nInstances:\n{stdout}"


@mcp.tool()
def qs_restart() -> str:
    """
    Restart the quickshell instance. Kills the current instance and starts a new one.
    Use this after making changes to QML files or the C++ plugin.
    """
    rc, stdout, stderr = _qs("kill")
    kill_result = stdout or stderr or "killed"

    time.sleep(0.5)
    rc2, stdout2, stderr2 = _qs("-d")
    start_result = stdout2 or stderr2 or ("started" if rc2 == 0 else f"failed (rc={rc2})")

    return f"Kill: {kill_result}\nStart: {start_result}"


@mcp.tool()
def qs_kill() -> str:
    """Kill all quickshell instances matching niri-caelestia-shell."""
    rc, stdout, stderr = _qs("kill")
    return stdout or stderr or f"Quickshell killed (rc={rc})."


@mcp.tool()
def qs_logs(lines: int = 50) -> str:
    """
    Get recent quickshell logs. Defaults to last 50 lines.
    Useful for debugging panel issues, IPC failures, or QML errors.
    """
    rc, stdout, stderr = _qs("log")
    if rc != 0:
        return f"Error fetching logs: {stderr or 'unknown error'}"
    log_lines = stdout.split("\n")
    recent = log_lines[-lines:] if len(log_lines) > lines else log_lines
    return "\n".join(recent)


@mcp.tool()
def qs_ipc_call(target: str, action: str) -> str:
    """
    Call a quickshell IPC handler to toggle panels, trigger actions, etc.

    Discovered targets (use qs_ipc_list for full details on each):
      - drawers:     toggle(drawer: str) — toggle any panel by name
      - clipboard:   toggle, open, close, clear
      - soundPanel:  toggle, open, close
      - display:     toggle, open, close
      - nexus:       open
      - notifs:      toggleDnd, enableDnd, disableDnd, clear
      - idleInhibitor: toggle, enable, disable
      - lock:        lock, unlock
      - mangaReader: toggle
      - novelReader: toggle
      - mpris:       play, pause, playPause, next, previous, stop, list, getActive
      - wallpaper:   set(path), get, list, open
      - audio:       cycleOutput
      - brightness:  set(value), get, setFor(query, value), getFor(query)
      - gameMode:    toggle, enable, disable
      - picker:      open, openFreeze, regionSearch, regionOcr
      - toaster:     info/warn/error/success(title, message, icon)

    If unsure, use qs_ipc_list first.
    """
    rc, stdout, stderr = _qs("ipc", "call", target, action)
    if rc != 0:
        return f"IPC error: {stderr or 'unknown error'}"
    return stdout or f"IPC call '{target}.{action}' sent."


@mcp.tool()
def qs_ipc_list() -> str:
    """List all available IPC targets and their functions registered in the quickshell instance."""
    rc, stdout, stderr = _qs("ipc", "show")
    if rc != 0:
        return f"Error listing IPC targets: {stderr or 'unknown error'}"
    return stdout or "No IPC targets found (shell may not be running)."


# ═══════════════════════════════════════════════════════════════
#  CAELESTIA-SPECIFIC TOOLS — plugin build, theming, wallpaper
# ═══════════════════════════════════════════════════════════════

@mcp.tool()
def caelestia_rebuild_plugin() -> str:
    """
    Rebuild the Caelestia C++ QML plugin. Run this after modifying any files in plugin/src/.
    Requires cmake and a working build directory at build/.
    """
    if not BUILD_DIR.exists():
        return f"Error: Build directory not found at {BUILD_DIR}"
    try:
        result = subprocess.run(
            ["cmake", "--build", "."],
            cwd=str(BUILD_DIR),
            capture_output=True, text=True, timeout=60,
        )
        output = result.stdout + "\n" + result.stderr
        if result.returncode == 0:
            return f"Plugin rebuilt successfully.\n{output}"
        return f"Build failed (rc={result.returncode}):\n{output}"
    except subprocess.TimeoutExpired:
        return "Build timed out after 60 seconds."
    except FileNotFoundError:
        return "Error: cmake not found. Is it installed?"


@mcp.tool()
def caelestia_shell_config(section: Optional[str] = None) -> str:
    """
    Read the shell.json configuration.
    If section is provided (e.g. 'bar', 'dashboard', 'launcher'), returns just that section.
    Otherwise returns the full config.
    """
    try:
        with open(SHELL_JSON) as f:
            config = json.load(f)
        if section:
            if section in config:
                return json.dumps(config[section], indent=2)
            return f"Section '{section}' not found. Available sections: {list(config.keys())}"
        return json.dumps(config, indent=2)
    except FileNotFoundError:
        return f"Config file not found at {SHELL_JSON}"
    except json.JSONDecodeError as e:
        return f"Invalid JSON in shell.json: {e}"


@mcp.tool()
def caelestia_matugen_reload() -> str:
    """
    Regenerate the matugen/material-you colour scheme from the current wallpaper.
    This updates the colour palette used by the shell.
    """
    wallpaper_path_file = Path.home() / ".local/state/caelestia/wallpaper/path.txt"
    try:
        wallpaper = wallpaper_path_file.read_text().strip()
    except FileNotFoundError:
        return "Error: No current wallpaper path found. Set a wallpaper first."

    try:
        result = subprocess.run(
            ["matugen", "image", wallpaper, "-m", "dark", "-t",
             "scheme-material-you", "--source-color-index", "0"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            return f"Matugen regenerated from {wallpaper}\n{result.stdout}"
        return f"Matugen error: {result.stderr}"
    except FileNotFoundError:
        return "Error: matugen not found. Is it installed?"
    except subprocess.TimeoutExpired:
        return "Matugen timed out."


@mcp.tool()
def caelestia_wallpaper_set(path: str) -> str:
    """
    Set the wallpaper and regenerate colours. Provide the full path to an image file.
    This writes to the wallpaper state file and runs matugen.
    """
    wallpaper_path = Path(path).expanduser().resolve()
    if not wallpaper_path.exists():
        return f"Error: Wallpaper file not found at {wallpaper_path}"

    state_dir = Path.home() / ".local/state/caelestia/wallpaper"
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "path.txt"
    state_file.write_text(str(wallpaper_path))

    try:
        result = subprocess.run(
            ["matugen", "image", str(wallpaper_path), "-m", "dark", "-t",
             "scheme-material-you", "--source-color-index", "0"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            return f"Wallpaper set to {wallpaper_path} and colours regenerated."
        return f"Wallpaper path written, but matugen error: {result.stderr}"
    except FileNotFoundError:
        return f"Wallpaper path written to {state_file}, but matugen not found."
    except subprocess.TimeoutExpired:
        return "Matugen timed out."


@mcp.tool()
def caelestia_list_wallpapers(directory: Optional[str] = None) -> str:
    """List available wallpapers in the wallpapers directory."""
    if directory:
        wp_dir = Path(directory).expanduser().resolve()
    else:
        candidates = [
            Path.home() / "Pictures/wallpapers",
            Path.home() / "Pictures/Wallpapers",
            Path.home() / ".local/share/wallpapers",
        ]
        wp_dir = next((d for d in candidates if d.is_dir()), None)

    if wp_dir is None or not wp_dir.is_dir():
        return "No wallpapers directory found. Provide a directory path."

    images = sorted([
        str(p) for p in wp_dir.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
    ])

    if not images:
        return f"No images found in {wp_dir}"

    return "\n".join(images)


# ═══════════════════════════════════════════════════════════════
#  NIRI CONFIGURATION TOOLS
# ═══════════════════════════════════════════════════════════════

@mcp.tool()
def niri_config_read(file_name: str = "config.kdl") -> str:
    """
    Read a niri configuration file. Defaults to config.kdl.
    Available files: config.kdl, caelestia.kdl, binds.kdl
    """
    config_path = NIRI_CONFIG / file_name
    try:
        return config_path.read_text()
    except FileNotFoundError:
        if NIRI_CONFIG.exists():
            files = [f.name for f in NIRI_CONFIG.iterdir()
                     if f.is_file() and f.suffix == ".kdl"]
            return f"File '{file_name}' not found. Available: {files}"
        return f"Niri config directory not found at {NIRI_CONFIG}"


@mcp.tool()
def niri_config_list() -> str:
    """List all KDL config files in the niri config directory."""
    if not NIRI_CONFIG.exists():
        return f"Niri config directory not found at {NIRI_CONFIG}"
    files = sorted([
        f"{f.name} ({f.stat().st_size} bytes)"
        for f in NIRI_CONFIG.iterdir()
        if f.is_file() and f.suffix == ".kdl"
    ])
    return "\n".join(files) if files else "No .kdl files found."


# ═══════════════════════════════════════════════════════════════
#  RESOURCES — documentation for the LLM
# ═══════════════════════════════════════════════════════════════

@mcp.resource("docs://agents")
def get_agents_md() -> str:
    """The AGENTS.md file — the primary architecture & coding guide for this project."""
    try:
        return AGENTS_MD.read_text()
    except FileNotFoundError:
        return "AGENTS.md not found."


@mcp.resource("docs://shell-json")
def get_shell_json() -> str:
    """The current shell.json configuration."""
    try:
        return SHELL_JSON.read_text()
    except FileNotFoundError:
        return "shell.json not found."


@mcp.resource("docs://niri-config/{file_name}")
def get_niri_config_resource(file_name: str) -> str:
    """Read a niri config KDL file. Available: config.kdl, caelestia.kdl, binds.kdl"""
    config_path = NIRI_CONFIG / file_name
    try:
        return config_path.read_text()
    except FileNotFoundError:
        return f"Config file '{file_name}' not found."


@mcp.resource("docs://niri-actions")
def get_niri_actions_help() -> str:
    """Shell command help for niri — listing available subcommands."""
    try:
        result = subprocess.run(
            ["niri", "msg", "--help"],
            capture_output=True, text=True,
        )
        return result.stdout
    except FileNotFoundError:
        return "niri binary not found."


@mcp.resource("docs://qs-help")
def get_qs_help() -> str:
    """Shell command help for quickshell — listing available options and subcommands."""
    try:
        result = subprocess.run(
            ["qs", "--help"],
            capture_output=True, text=True,
        )
        return result.stdout
    except FileNotFoundError:
        return "qs binary not found."


@mcp.resource("docs://caelestia-structure")
def get_project_structure() -> str:
    """Overview of the Caelestia project directory structure."""
    try:
        result = subprocess.run(
            ["find", str(PROJECT_ROOT), "-maxdepth", "2", "-type", "d",
             "-not", "-path", "*/.git/*", "-not", "-path", "*/node_modules/*",
             "-not", "-path", "*/build/*"],
            capture_output=True, text=True,
        )
        return f"Project: {PROJECT_ROOT}\n\nDirectories:\n{result.stdout.strip()}"
    except Exception as e:
        return f"Error listing project: {e}"


# ═══════════════════════════════════════════════════════════════
#  ENTRYPOINT
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    mcp.run()
