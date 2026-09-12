#!/usr/bin/env python3
import sys
import json
import subprocess
import os
import time

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def notify(title, msg, level="info"):
    icon = "monitor"
    if level == "error":
        icon = "error"
    elif level == "warn":
        icon = "warning"
    
    subprocess.run([
        "qs", "-c", "niri-caelestia-shell", "ipc", "call", 
        "toaster", level, title, msg, icon
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

SWITCHING_LOCK = "/tmp/quickshell-display-switching"

def is_wrapper_running():
    """Check if launch-quickshell.sh wrapper is running."""
    res = subprocess.run(["pgrep", "-f", "launch-quickshell.sh"], capture_output=True, text=True)
    return res.returncode == 0

def find_quickshell_pids():
    """Find all quickshell and qs process IDs."""
    result = subprocess.run(
        ["pgrep", "-x", "quickshell|qs"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return []
    pids = []
    for line in result.stdout.strip().splitlines():
        try:
            pids.append(int(line))
        except ValueError:
            pass
    return list(set(pids))

def kill_quickshell():
    """Kill quickshell and qs processes with SIGKILL to prevent use-after-free crash.
    
    When a display is turned off or reconfigured, quickshell's layer surfaces get destroyed
    which triggers a use-after-free in QtWayland's WaylandPanelInterface destructor.
    By killing quickshell before the output change, no layer surfaces exist.
    We use SIGKILL (-9) to skip any cleanup code that might still crash.
    """
    pids = find_quickshell_pids()
    if not pids:
        return
    
    for pid in pids:
        subprocess.run(["kill", "-9", str(pid)], capture_output=True)
    
    # Wait for all instances to fully exit
    for _ in range(20):  # up to 2 seconds
        remaining = find_quickshell_pids()
        if not remaining:
            return
        time.sleep(0.1)
    
    # Force-kill any stubborn remaining instances
    for pid in find_quickshell_pids():
        subprocess.run(["kill", "-9", str(pid)], capture_output=True)

def restart_quickshell():
    """Restart quickshell after display change."""
    # Ensure lock is removed first so wrapper can proceed
    if os.path.exists(SWITCHING_LOCK):
        try:
            os.remove(SWITCHING_LOCK)
        except Exception:
            pass

    # If wrapper is running, wait for it to restart quickshell
    if is_wrapper_running():
        for _ in range(30):  # wait up to 3 seconds
            if find_quickshell_pids():
                return
            time.sleep(0.1)

    # If wrapper not running or didn't launch, start wrapper or quickshell directly
    wrapper_path = os.path.expanduser("~/.config/niri_caelestia/scripts/launch-quickshell.sh")
    if os.path.exists(wrapper_path):
        subprocess.Popen(
            [wrapper_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    else:
        subprocess.Popen(
            ["quickshell", "--path", os.path.expanduser("~/.config/quickshell/niri-caelestia-shell/shell.qml")],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

def main():
    if len(sys.argv) < 2:
        print("Usage: niri-display.py [internal|external|extend-left|extend-right|duplicate]")
        sys.exit(1)

    mode = sys.argv[1]
    turning_off_display = mode in ("internal", "external")
    
    # Get Niri outputs
    res = run_cmd("niri msg --json outputs")
    if res.returncode != 0:
        if turning_off_display:
            restart_quickshell()
        notify("Display Switcher", "Error: Niri is not running or IPC failed", "error")
        sys.exit(1)
        
    try:
        outputs = json.loads(res.stdout)
    except Exception as e:
        if turning_off_display:
            restart_quickshell()
        notify("Display Switcher", f"Failed to parse Niri outputs: {e}", "error")
        sys.exit(1)
        
    # Detect internal and external displays
    internal = None
    external = None
    for name in outputs:
        if name.startswith(("eDP", "LVDS", "DSI")):
            internal = name
        else:
            external = name
            
    if not internal:
        internal = list(outputs.keys())[0] if outputs else "eDP-1"
        
    if not external:
        if mode in ("external", "extend", "extend-left", "extend-right", "duplicate"):
            notify("Display Switcher", "No external display detected.", "warn")
            mode = "internal"

    # Always clean up any existing wl-mirror process
    run_cmd("pkill wl-mirror")

    output_kdl_path = os.path.expanduser("~/.config/niri/niri/output.kdl")

    # Get width of displays for extend positioning
    internal_width = 1920
    if internal in outputs:
        modes = outputs[internal].get("modes", [])
        for m in modes:
            if m.get("is_preferred"):
                internal_width = m.get("width", 1920)
                break
        else:
            if modes:
                internal_width = modes[0].get("width", 1920)

    external_width = 1920
    if external and external in outputs:
        modes = outputs[external].get("modes", [])
        for m in modes:
            if m.get("is_preferred"):
                external_width = m.get("width", 1920)
                break
        else:
            if modes:
                external_width = modes[0].get("width", 1920)

    kdl_content = ""
    if mode == "internal":
        kdl_content = f"""// Auto-generated by niri-display.py
output "{internal}" {{
    scale 1.0
}}
"""
        if external:
            kdl_content += f"""output "{external}" {{
    off
}}
"""
    elif mode == "external":
        kdl_content = f"""// Auto-generated by niri-display.py
output "{internal}" {{
    off
}}
"""
        if external:
            kdl_content += f"""output "{external}" {{
    scale 1.0
}}
"""
    elif mode == "extend-left":
        # External on the left, internal on the right
        kdl_content = f"""// Auto-generated by niri-display.py
output "{internal}" {{
    position x={external_width} y=0
    scale 1.0
}}
"""
        if external:
            kdl_content += f"""output "{external}" {{
    position x=0 y=0
    scale 1.0
}}
"""
    elif mode == "extend-right":
        # Internal on the left, external on the right
        kdl_content = f"""// Auto-generated by niri-display.py
output "{internal}" {{
    position x=0 y=0
    scale 1.0
}}
"""
        if external:
            kdl_content += f"""output "{external}" {{
    position x={internal_width} y=0
    scale 1.0
}}
"""
    elif mode == "duplicate":
        # Enable both displays side by side (standard way to make both active in Wayland)
        kdl_content = f"""// Auto-generated by niri-display.py
output "{internal}" {{
    position x=0 y=0
    scale 1.0
}}
"""
        if external:
            kdl_content += f"""output "{external}" {{
    position x={internal_width} y=0
    scale 1.0
}}
"""
        
        # Check if wl-mirror is installed
        check_mirror = run_cmd("which wl-mirror")
        if check_mirror.returncode == 0:
            subprocess.Popen(
                ["wl-mirror", internal], 
                stdout=subprocess.DEVNULL, 
                stderr=subprocess.DEVNULL
            )
        else:
            notify(
                "Mirroring Failed", 
                "wl-mirror is not installed. Mirroring window could not be opened.", 
                "error"
            )

    # Write output.kdl
    try:
        os.makedirs(os.path.dirname(output_kdl_path), exist_ok=True)
        with open(output_kdl_path, "w") as f:
            f.write(kdl_content)
    except Exception as e:
        if turning_off_display:
            restart_quickshell()
        notify("Display Switcher", f"Failed to write config: {e}", "error")
        sys.exit(1)

    # -- Quickshell crash guard --
    # Always kill quickshell before reloading Niri display configuration.
    # When outputs are added, removed, or repositioned in Niri, QtWayland's
    # layer shell surfaces are closed or invalidated mid-flight by the compositor.
    # Terminating Quickshell cleanly with SIGKILL beforehand prevents the
    # fatal use-after-free in Qt6's QQuickWindow::maybeUpdate / QQuickItemPrivate::dirty.
    # The launch-quickshell.sh wrapper catches SWITCHING_LOCK and waits for completion.
    try:
        open(SWITCHING_LOCK, "w").close()
    except Exception:
        pass

    try:
        kill_quickshell()

        # Reload niri config (may turn off a display)
        if mode == "internal":
            run_cmd(f"niri msg output {internal} on")
        res_reload = run_cmd("niri msg action load-config-file")
        if res_reload.returncode != 0:
            notify("Display Switcher", "Failed to reload Niri config", "error")
            sys.exit(1)

        # Allow Niri output events to settle before restarting shell
        time.sleep(0.5)
    finally:
        restart_quickshell()

    mode_title = {
        "internal": "Laptop Screen Only",
        "external": "External Screen Only",
        "extend": "Extend Desktop",
        "extend-left": "Extend Left",
        "extend-right": "Extend Right",
        "duplicate": "Duplicate/Mirror"
    }.get(mode, mode)
    
    time.sleep(1.0)
    notify("Display Switcher", f"Layout changed to {mode_title}", "success")

if __name__ == "__main__":
    main()
