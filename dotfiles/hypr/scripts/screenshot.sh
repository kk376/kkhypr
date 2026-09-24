#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-screen}"

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
