#!/usr/bin/env bash

# Define display modes
# Format: "Display Name" -> "script argument"
declare -A modes
modes=(
    ["Laptop Screen Only"]="internal"
    ["External Screen Only"]="external"
    ["Extend Left"]="extend-left"
    ["Extend Right"]="extend-right"
    ["Duplicate/Mirror"]="duplicate"
)

options="Laptop Screen Only\nExternal Screen Only\nExtend Right\nExtend Left\nDuplicate/Mirror"

# Run fuzzel in dmenu mode
choice=$(echo -e "$options" | fuzzel -d -p "Display Profile: " -l 5)

if [[ -n "$choice" && -n "${modes[$choice]}" ]]; then
    mode="${modes[$choice]}"
    /home/patrick/.config/niri/niri-display.py "$mode"
fi
