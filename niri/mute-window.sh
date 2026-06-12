#!/bin/bash
# Mute/unmute the focused window's audio via PulseAudio/PipeWire.

if [ -z "$1" ]; then
    WINDOW_INFO=$(niri msg --json focused-window)
else
    WINDOW_INFO="$1"
fi

PID=$(echo "$WINDOW_INFO" | jq -r '.pid')
APP_ID=$(echo "$WINDOW_INFO" | jq -r '.app_id')
TITLE=$(echo "$WINDOW_INFO" | jq -r '.title')

if [ -z "$PID" ] || [ "$PID" == "null" ]; then
    exit 0
fi

SINK_INPUTS=$(pactl list sink-inputs | awk -v pid="$PID" '
    /^Sink Input #/ { id=$3 }
    /application.process.id = "/ {
        gsub(/"/, "", $3);
        if ($3 == pid) print id
    }
')

if [ -z "$SINK_INPUTS" ]; then
    SINK_INPUTS=$(pactl list sink-inputs | awk -v appid="$APP_ID" -v title="$TITLE" '
        /^Sink Input #/ { id=$3 }
        /application.name = "/ || /media.name = "/ || /node.name = "/ || /application.process.binary = "/ {
            if (match($0, /"([^"]+)"/, arr)) {
                val = arr[1];
                if (val != "" && (tolower(val) ~ tolower(appid) || tolower(val) ~ tolower(title) || tolower(appid) ~ tolower(val))) {
                    print id
                }
            }
        }
    ' | sort -u)
fi

if [ -n "$SINK_INPUTS" ]; then
    FIRST_ID=$(echo "$SINK_INPUTS" | head -n 1 | sed 's/#//')
    IS_MUTED=$(pactl list sink-inputs | awk -v id="#$FIRST_ID" '
        $0 ~ "Sink Input " id { found=1 }
        found && /Mute:/ { print $2; exit }
    ')

    for ID in $SINK_INPUTS; do
        CLEAN_ID=$(echo "$ID" | sed 's/#//')
        pactl set-sink-input-mute "$CLEAN_ID" toggle
    done

    if [ "$IS_MUTED" == "yes" ]; then
        notify-send -h boolean:transient:true -t 1000 -a "niri" "Audio" "Unmuted: $TITLE" -i audio-volume-high
    else
        notify-send -h boolean:transient:true -t 1000 -a "niri" "Audio" "Muted: $TITLE" -i audio-volume-muted
    fi
fi
