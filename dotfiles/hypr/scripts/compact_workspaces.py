#!/usr/bin/env python3
"""
Hyprland Dynamic Workspace Compactor Daemon
Monitors Hyprland socket2 for window close, workspace destruction, and window move events.
Automatically compacts active workspaces to remove numeric gaps (1, 2, 3...)
and shifts subsequent workspaces down when an intermediate workspace is emptied.
Supports both native Hyprland Lua dispatcher bindings (Hyprland 0.56+) and legacy batch syntax.
"""

import fcntl
import json
import logging
import os
import select
import signal
import socket
import subprocess
import sys
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

_lua_mode_cache = None

def is_lua_mode() -> bool:
    global _lua_mode_cache
    if _lua_mode_cache is not None:
        return _lua_mode_cache
    try:
        res = subprocess.run(
            ["hyprctl", "eval", "return true"],
            capture_output=True,
            text=True,
            timeout=1.0,
            check=False,
        )
        _lua_mode_cache = (res.returncode == 0 and "ok" in res.stdout.lower())
    except Exception:
        _lua_mode_cache = False
    return _lua_mode_cache

def acquire_lock():
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    lock_file = os.path.join(xdg_runtime, "hypr_workspace_compactor.lock")
    try:
        lock_fd = open(lock_file, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock_fd
    except (BlockingIOError, OSError):
        sys.exit(0)

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

def execute_compaction(moves: list, target_active: int | None, active_id: int | None) -> bool:
    if not moves and (target_active is None or target_active == active_id):
        return False

    if is_lua_mode():
        stmts = []
        for target_id, addr in moves:
            stmts.append(
                f'hl.dispatch(hl.dsp.window.move({{ workspace = {target_id}, window = "address:{addr}", follow = false }}))'
            )
        if target_active is not None and target_active != active_id:
            stmts.append(f'hl.dispatch(hl.dsp.focus({{ workspace = {target_active} }}))')

        lua_code = "; ".join(stmts)
        try:
            res = subprocess.run(
                ["hyprctl", "eval", lua_code],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode != 0:
                logging.error("hyprctl eval failed (code %d): %s", res.returncode, res.stderr or res.stdout)
                return False
            logging.info("Compacted workspaces via Lua dispatch: %d move(s)", len(moves))
            return True
        except Exception as e:
            logging.error("Failed to execute hyprctl eval: %s", e)
            return False
    else:
        batch_parts = []
        for target_id, addr in moves:
            batch_parts.append(f"dispatch movetoworkspacesilent {target_id},address:{addr}")
        if target_active is not None and target_active != active_id:
            batch_parts.append(f"dispatch workspace {target_active}")

        batch_cmd = ";".join(batch_parts)
        try:
            res = subprocess.run(
                ["hyprctl", "--batch", batch_cmd],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode != 0 or "error:" in res.stdout.lower() or "error:" in res.stderr.lower():
                logging.error("hyprctl batch failed (code %d): %s", res.returncode, res.stderr or res.stdout)
                return False
            logging.info("Compacted workspaces via batch dispatch: %d move(s)", len(moves))
            return True
        except Exception as e:
            logging.error("Failed to execute hyprctl --batch: %s", e)
            return False

def compact_workspaces() -> bool:
    clients = run_hyprctl_json("clients")
    active = run_hyprctl_json("activeworkspace")
    if clients is None or active is None:
        return False

    active_id = active.get("id")

    # Group client addresses by positive integer workspace IDs
    ws_clients = {}
    for c in clients:
        # Ignore unmapped / closing windows
        if c.get("mapped") == 0:
            continue
        ws = c.get("workspace", {})
        ws_id = ws.get("id")
        if ws_id is not None and isinstance(ws_id, int) and ws_id > 0:
            addr = c.get("address")
            if addr:
                ws_clients.setdefault(ws_id, []).append(addr)

    # If no windows exist anywhere on the desktop, do not force-switch workspaces;
    # allow the user to remain on their current empty desktop (homescreen).
    if not ws_clients:
        return False

    # The current active workspace is treated as held while the user is actively on it.
    # This ensures that when all windows on the active desktop are closed, the desktop is not
    # immediately destroyed or re-indexed until the user explicitly switches away to another desktop.
    slots = set(ws_clients.keys())
    if active_id is not None and isinstance(active_id, int) and active_id > 0:
        slots.add(active_id)

    # Also preserve active workspaces on any additional monitors
    monitors = run_hyprctl_json("monitors")
    if monitors and isinstance(monitors, list):
        for m in monitors:
            aws = m.get("activeWorkspace", {})
            mid = aws.get("id")
            if mid is not None and isinstance(mid, int) and mid > 0:
                slots.add(mid)

    # Respect persistent workspaces configured in Hyprland
    workspaces = run_hyprctl_json("workspaces")
    if workspaces and isinstance(workspaces, list):
        for ws in workspaces:
            if ws.get("ispersistent") and isinstance(ws.get("id"), int) and ws.get("id") > 0:
                slots.add(ws.get("id"))

    occupied = sorted(slots)

    moves = []
    for i, old_id in enumerate(occupied):
        target_id = i + 1
        if old_id != target_id:
            for addr in ws_clients.get(old_id, []):
                moves.append((target_id, addr))

    target_active = None
    if active_id is not None and isinstance(active_id, int) and active_id > 0:
        if active_id in occupied:
            idx = occupied.index(active_id)
            if idx + 1 != active_id:
                target_active = idx + 1

    return execute_compaction(moves, target_active, active_id)

def main():
    lock_fd = acquire_lock()
    running = True

    def handle_signal(sig, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    lua = is_lua_mode()
    logging.info("Starting workspace compactor daemon (mode: %s)", "Lua" if lua else "Legacy batch")

    # Initial check on daemon start
    compact_workspaces()

    trigger_events = {
        "closewindow",
        "destroyworkspace",
        "destroyworkspacev2",
        "movewindow",
        "movewindowv2",
        "workspace",
        "workspacev2",
        "focusedmon",
        "openwindow",
    }

    while running:
        try:
            sock_path = get_socket_path()
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            logging.info("Connected to Hyprland socket2: %s", sock_path)
        except Exception as e:
            logging.warning("Unable to connect to Hyprland socket2: %s. Retrying in 1s...", e)
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

            now = time.time()
            if r:
                try:
                    data = s.recv(4096).decode("utf-8", errors="ignore")
                    if not data:
                        logging.warning("Hyprland socket2 disconnected (EOF received).")
                        break
                    buf += data
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        line = line.strip()
                        if not line:
                            continue
                        event_name = line.split(">>", 1)[0] if ">>" in line else line

                        if not busy and event_name in trigger_events:
                            pending_compact = True
                            last_trigger = now
                except Exception as e:
                    logging.warning("Error reading from socket2: %s", e)
                    break

            if pending_compact and (now - last_trigger >= 0.15):
                pending_compact = False
                busy = True
                try:
                    compact_workspaces()
                finally:
                    busy = False

        try:
            s.close()
        except Exception:
            pass

        if running:
            time.sleep(0.5)

    logging.info("Workspace compactor daemon exiting cleanly.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        compact_workspaces()
        sys.exit(0)
    main()
