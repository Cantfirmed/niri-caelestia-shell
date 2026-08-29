#!/usr/bin/env python3
import sys
import json
import subprocess
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: local_colors.py <walls_dir>", file=sys.stderr)
        sys.exit(1)

    walls_dir = Path(sys.argv[1]).expanduser()
    cache_dir = Path("~/.cache/caelestia").expanduser()
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / "local_wallpaper_colors.json"

    # Load cache
    cache = {}
    if cache_file.exists():
        try:
            cache = json.loads(cache_file.read_text())
        except Exception:
            pass

    # Supported image extensions
    valid_exts = {".jpg", ".jpeg", ".png", ".webp"}

    # Scan directory
    if walls_dir.exists():
        for file_path in walls_dir.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in valid_exts:
                name = file_path.name
                if name not in cache:
                    # Run matugen dry-run to get palettes
                    try:
                        cmd = [
                            "matugen", "image", str(file_path),
                            "--dry-run", "-j", "hex",
                            "--source-color-index", "0"
                        ]
                        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
                        data = json.loads(res.stdout)
                        
                        # Extract colors
                        colors = data.get("colors", {})
                        extracted = [
                            colors.get("primary", {}).get("default", {}).get("color", "#888888"),
                            colors.get("secondary", {}).get("default", {}).get("color", "#888888"),
                            colors.get("tertiary", {}).get("default", {}).get("color", "#888888"),
                            colors.get("primary_container", {}).get("default", {}).get("color", "#888888"),
                            colors.get("tertiary_container", {}).get("default", {}).get("color", "#888888")
                        ]
                        cache[name] = extracted
                    except Exception:
                        pass

    # Save cache
    try:
        cache_file.write_text(json.dumps(cache, indent=2))
    except Exception:
        pass

    # Print output
    print(json.dumps(cache))

if __name__ == "__main__":
    main()
