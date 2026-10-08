#!/usr/bin/env bash
# Toggle Noctalia emoji picker in the top bar.
# If the launcher panel is already open, close it; otherwise open it focused on /emo.

status=$(noctalia msg status 2>/dev/null)
if echo "$status" | grep -qE '"activePanelId":[[:space:]]*"launcher"'; then
    noctalia msg panel-close launcher
else
    noctalia msg panel-open launcher /emo
fi
