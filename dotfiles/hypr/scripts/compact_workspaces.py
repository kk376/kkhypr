#!/usr/bin/env python3
"""
Hyprland Dynamic Workspace Compactor Daemon
Monitors Hyprland socket2 for window close and move events.
Automatically compacts active workspaces to remove numeric gaps (1, 2, 3...)
and shifts subsequent workspaces down when an intermediate workspace is emptied.
"""

import json
import os
import select
import signal
import socket
import subprocess
import sys
import time

def get_socket_path() -> str:
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        raise RuntimeError("HYPRLAND_INSTANCE_SIGNATURE environment variable not set")
    sock = os.path.join(xdg_runtime, "hypr", his, ".socket2.sock")
    if not os.path.exists(sock):
        sock = f"/tmp/hypr/{his}/.socket2.sock"
    return sock

def run_hyprctl_json(cmd: str):
    try:
        raw = subprocess.check_output(["hyprctl", "-j", cmd], stderr=subprocess.DEVNULL)
        return json.loads(raw)
    except Exception:
        return None

def compact_workspaces() -> bool:
    clients = run_hyprctl_json("clients")
    active = run_hyprctl_json("activeworkspace")
    if clients is None or active is None:
        return False

    active_id = active.get("id")

    # Group client addresses by positive integer workspace IDs
    ws_clients = {}
    for c in clients:
        ws = c.get("workspace", {})
        ws_id = ws.get("id")
        if ws_id is not None and isinstance(ws_id, int) and ws_id > 0:
            addr = c.get("address")
            if addr:
                ws_clients.setdefault(ws_id, []).append(addr)

    occupied = sorted(ws_clients.keys())
    if not occupied:
        if active_id is not None and active_id > 1:
            subprocess.run(["hyprctl", "dispatch", "workspace", "1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return False

    moves = []
    for i, old_id in enumerate(occupied):
        target_id = i + 1
        if old_id != target_id:
            for addr in ws_clients[old_id]:
                moves.append((target_id, addr))

    target_active = None
    max_occupied = occupied[-1]
    if active_id is not None and active_id > 0:
        if active_id not in ws_clients:
            if active_id > max_occupied:
                target_active = max_occupied
        else:
            idx = occupied.index(active_id)
            if idx + 1 != active_id:
                target_active = idx + 1

    if not moves and target_active is None:
        return False

    batch_parts = []
    for target_id, addr in moves:
        batch_parts.append(f"dispatch movetoworkspacesilent {target_id},address:{addr}")
    if target_active is not None and target_active != active_id:
        batch_parts.append(f"dispatch workspace {target_active}")

    batch_cmd = ";".join(batch_parts)
    try:
        subprocess.run(["hyprctl", "--batch", batch_cmd], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False

def main():
    running = True

    def handle_signal(sig, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    while running:
        try:
            sock_path = get_socket_path()
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
        except Exception:
            time.sleep(1.0)
            continue

        buf = ""
        last_trigger = 0.0
        pending_compact = False
        busy = False

        while running:
            timeout = 0.05 if pending_compact else 1.0
            try:
                r, _, _ = select.select([s], [], [], timeout)
            except select.error:
                break

            if r:
                try:
                    data = s.recv(4096).decode("utf-8", errors="ignore")
                    if not data:
                        break
                    buf += data
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        line = line.strip()
                        if not line:
                            continue
                        event_name = line.split(">>", 1)[0] if ">>" in line else line

                        if not busy and event_name in ("closewindow", "movewindow"):
                            pending_compact = True
                            last_trigger = time.time()
                except Exception:
                    break

            if pending_compact and (time.time() - last_trigger >= 0.08):
                pending_compact = False
                busy = True
                try:
                    compact_workspaces()
                    time.sleep(0.05)
                    # Drain socket to absorb events caused by our own batch command
                    s.setblocking(False)
                    try:
                        while True:
                            drain = s.recv(4096)
                            if not drain:
                                break
                    except (BlockingIOError, socket.error):
                        pass
                    finally:
                        s.setblocking(True)
                finally:
                    busy = False

        try:
            s.close()
        except Exception:
            pass

        if running:
            time.sleep(0.5)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        compact_workspaces()
        sys.exit(0)
    main()
