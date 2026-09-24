#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-screen}"

# Debounce guard: prevent duplicate executions within 800ms
DEBOUNCE_FILE="/tmp/.screenshot_debounce"
NOW_MS=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
if [ -f "$DEBOUNCE_FILE" ]; then
    LAST_MS=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
    DIFF=$(( NOW_MS - LAST_MS ))
    if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt 800 ]; then
        exit 0
    fi
fi
echo "$NOW_MS" > "$DEBOUNCE_FILE"

case "$MODE" in
    area)
        GEOM=$(slurp 2>/dev/null) || exit 0
        grim -g "$GEOM" - | wl-copy --type image/png
        notify-send -a "Grim" "Screenshot" "Area copied to clipboard" -i camera-photo
        ;;
    screen)
        grim - | wl-copy --type image/png
        notify-send -a "Grim" "Screenshot" "Full screen copied to clipboard" -i camera-photo
        ;;
    screen-save)
        SAVE_DIR="$HOME/Pictures/Screenshots"
        mkdir -p "$SAVE_DIR"
        FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
        FILEPATH="$SAVE_DIR/$FILENAME"
        grim "$FILEPATH"
        wl-copy --type image/png < "$FILEPATH"
        notify-send -a "Grim" "Screenshot" "Saved to ~/Pictures/Screenshots/$FILENAME and copied to clipboard" -i camera-photo
        ;;
    *)
        echo "Usage: $0 {area|screen|screen-save}" >&2
        exit 1
        ;;
esac
