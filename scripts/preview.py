#!/usr/bin/env python3
import sys
import json
import subprocess
import re
from pathlib import Path

def main():
    if len(sys.argv) < 4:
        print("Usage: preview.py <image_path> <mode> <scheme_type>", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    mode = sys.argv[2]
    scheme_type = sys.argv[3]

    # Run matugen dry-run
    try:
        cmd = [
            "matugen", "image", image_path,
            "--dry-run", "-j", "hex",
            "--source-color-index", "0",
            "--mode", mode,
            "--type", scheme_type
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        matugen_data = json.loads(res.stdout)
    except Exception as e:
        print(f"Error running matugen: {e}", file=sys.stderr)
        if 'res' in locals():
            print(res.stderr, file=sys.stderr)
        sys.exit(1)

    # Read the scheme.json template
    template_path = Path("~/.config/matugen/templates/scheme.json").expanduser()
    if not template_path.exists():
        template_path = Path("~/.config/dfm/profiles/caelestia/matugen/templates/scheme.json").expanduser()
    
    if not template_path.exists():
        print(f"Template not found at {template_path}", file=sys.stderr)
        sys.exit(1)

    template_str = template_path.read_text()

    # Replaces placeholders like {{colors.on_surface.default.hex_stripped}}
    def replace_placeholder(match):
        token = match.group(1).strip()
        parts = token.split('.')
        if len(parts) >= 3 and parts[0] == 'colors':
            key = parts[1]
            submode = parts[2]
            try:
                color = matugen_data['colors'][key][submode]['color']
                return color.lstrip('#')
            except KeyError:
                pass
        return match.group(0)

    result_str = re.sub(r'\{\{([^}]+)\}\}', replace_placeholder, template_str)

    # Update mode and name in the output JSON
    try:
        result_json = json.loads(result_str)
        result_json['mode'] = mode
        result_json['variant'] = scheme_type.replace("scheme-", "")
        print(json.dumps(result_json, indent=2))
    except Exception as e:
        print(result_str)

if __name__ == "__main__":
    main()
