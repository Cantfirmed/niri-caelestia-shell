import sys
import os
import re

def update_multiple_outputs(outputs_list):
    config_path = os.path.expanduser("~/.config/niri/niri/output.kdl")
    if not os.path.exists(config_path):
        # Create it if it doesn't exist
        with open(config_path, "w") as f:
            f.write("// --- Output Configuration ---\n")
    
    with open(config_path, "r") as f:
        content = f.read()
    
    for out in outputs_list:
        connector = out["connector"]
        x = out.get("x")
        y = out.get("y")
        scale = out.get("scale")
        mode = out.get("mode")
        
        # Find existing output block
        pattern = rf'output\s+"{connector}"\s+{{(.*?)\n}}'
        match = re.search(pattern, content, re.DOTALL)
        
        if match:
            block = match.group(1)
            if x is not None and y is not None:
                if "position" in block:
                    block = re.sub(r'position\s+x=-?\d+\s+y=-?\d+', f'position x={x} y={y}', block)
                else:
                    block += f'\n    position x={x} y={y}'
            
            if scale is not None:
                if "scale" in block:
                    block = re.sub(r'scale\s+\d+\.?\d*', f'scale {scale}', block)
                else:
                    block += f'\n    scale {scale}'
            
            if mode is not None:
                if "mode" in block:
                    block = re.sub(r'mode\s+".*?"', f'mode "{mode}"', block)
                else:
                    block += f'\n    mode "{mode}"'
            
            content = content.replace(match.group(0), f'output "{connector}" {{{block}\n}}')
        else:
            # Add new block
            new_block = f'\noutput "{connector}" {{\n'
            if x is not None and y is not None:
                new_block += f'    position x={x} y={y}\n'
            if mode is not None:
                new_block += f'    mode "{mode}"\n'
            if scale is not None:
                new_block += f'    scale {scale}\n'
            new_block += '}\n'
            content = content + new_block
            
    with open(config_path, "w") as f:
        f.write(content)
    
    # Reload niri config
    os.system("niri msg load-config-file")

def update_output_kdl(connector, x=None, y=None, scale=None, mode=None):
    item = {"connector": connector}
    if x is not None: item["x"] = x
    if y is not None: item["y"] = y
    if scale is not None: item["scale"] = scale
    if mode is not None: item["mode"] = mode
    update_multiple_outputs([item])

if __name__ == "__main__":
    import argparse
    import json
    
    parser = argparse.ArgumentParser()
    parser.add_argument("connector", nargs="?")
    parser.add_argument("--x", type=int)
    parser.add_argument("--y", type=int)
    parser.add_argument("--scale", type=float)
    parser.add_argument("--mode")
    parser.add_argument("--bulk")
    args = parser.parse_args()
    
    if args.bulk:
        bulk_data = json.loads(args.bulk)
        update_multiple_outputs(bulk_data)
    elif args.connector:
        update_output_kdl(args.connector, args.x, args.y, args.scale, args.mode)

