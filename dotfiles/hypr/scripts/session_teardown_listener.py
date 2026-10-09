#!/usr/bin/env python3
"""
Hyprland Session Teardown Listener Daemon
Monitors Hyprland's IPC event socket. When Hyprland terminates (via keybinding,
logout menu, crash, or signal), this daemon immediately stops hyprland-session.target
and graphical-session.target and unsets compositor-specific environment variables.
Prevents orphaned graphical targets from breaking subsequent display manager logins.
"""

import os
import socket
import subprocess
import sys
import time

def main():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        sys.exit(0)

    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sock_path = os.path.join(xdg_runtime, "hypr", his, ".socket2.sock")
    if not os.path.exists(sock_path):
        sock_path = f"/tmp/hypr/{his}/.socket2.sock"

    # Allow up to 3 seconds for Hyprland to bind the socket if starting concurrently
    connected = False
    for _ in range(30):
        if os.path.exists(sock_path):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(sock_path)
                connected = True
                break
            except (ConnectionRefusedError, FileNotFoundError, OSError):
                time.sleep(0.1)
        else:
            time.sleep(0.1)

    if not connected:
        sys.exit(0)

    try:
        # Block until Hyprland process exits and closes the connection
        while True:
            data = s.recv(4096)
            if not data:
                break
    except Exception:
        pass
    finally:
        try:
            s.close()
        except Exception:
            pass

        # Tear down graphical session targets immediately upon compositor shutdown
        subprocess.run(
            ["systemctl", "--user", "stop", "hyprland-session.target", "graphical-session.target"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            [
                "systemctl",
                "--user",
                "unset-environment",
                "WAYLAND_DISPLAY",
                "HYPRLAND_INSTANCE_SIGNATURE",
                "AQ_DRM_DEVICES",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

if __name__ == "__main__":
    main()
