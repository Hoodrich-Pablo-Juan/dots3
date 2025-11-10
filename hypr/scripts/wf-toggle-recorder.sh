#!/bin/bash
if pgrep -x "wf-recorder" > /dev/null; then
    pkill -INT wf-recorder
    notify-send "Screen Recording" "Stopped."
else
    mkdir -p "$HOME/Videos/Recordings"
    wf-recorder -f "$HOME/Videos/Recordings/rec_$(date +%Y%m%d_%H%M%S).mp4" &
    notify-send "Screen Recording" "Started. Press Ctrl+P again to stop."
fi
