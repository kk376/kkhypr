#!/usr/bin/env python3
"""
Bluetooth Device Battery Synchronizer
Monitors connected Bluetooth audio/peripheral devices and exports current battery status
to /run/user/<uid>/bt_battery.json for top bar widgets (e.g. Noctalia Custom Bar).
Ensures the BlueZ device Alias reflects the authentic hardware name rather than battery percentage.
"""

import json
import os
import re
import signal
import subprocess
import sys
import time

def get_connected_devices():
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "devices", "Connected"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="ignore")
        devices = []
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] == "Device":
                devices.append(parts[1])
        return devices
    except Exception:
        return []

def get_device_info(mac):
    name = "Bluetooth Device"
    battery = None
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "info", mac],
            stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            line_str = line.strip()
            if line_str.startswith("Name:"):
                name = line_str[5:].strip()
            elif "Battery Percentage:" in line_str:
                m = re.search(r"\((\d+)\)", line_str)
                if m:
                    battery = int(m.group(1))
                else:
                    parts = line_str.split(":")[-1].strip().split()
                    if parts and parts[0].isdigit():
                        battery = int(parts[0])
    except Exception:
        pass

    if battery is None:
        # Fallback to UPower
        dev_str = "headset_dev_" + mac.replace(":", "_")
        try:
            out = subprocess.check_output(
                ["upower", "-i", f"/org/freedesktop/UPower/devices/{dev_str}"],
                stderr=subprocess.DEVNULL
            ).decode("utf-8", errors="ignore")
            for line in out.splitlines():
                if "model:" in line and name == "Bluetooth Device":
                    name = line.split(":")[-1].strip()
                elif "percentage:" in line:
                    val_str = line.split(":")[-1].replace("%", "").strip()
                    try:
                        battery = int(float(val_str))
                    except ValueError:
                        pass
        except Exception:
            pass

    return name, battery

def restore_device_alias(mac, name):
    dev_path = f"/org/bluez/hci0/dev_{mac.replace(':', '_')}"
    cmd = [
        "busctl", "--system", "call", "org.bluez", dev_path,
        "org.freedesktop.DBus.Properties", "Set", "ssv",
        "org.bluez.Device1", "Alias", "s", name
    ]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        pass

def write_status(connected, name, percent, mac):
    data = {
        "connected": connected,
        "name": name,
        "percent": percent,
        "mac": mac,
    }
    uid = os.getuid()
    target = f"/run/user/{uid}/bt_battery.json"
    temp_target = target + ".tmp"
    try:
        with open(temp_target, "w") as f:
            json.dump(data, f)
        os.replace(temp_target, target)
    except Exception:
        pass

def sync_all():
    connected = get_connected_devices()
    if not connected:
        write_status(False, "", None, None)
        return

    # Primary connected device
    for mac in connected:
        name, pct = get_device_info(mac)
        if name and name != "90%":
            restore_device_alias(mac, name)
        if pct is not None:
            write_status(True, name, pct, mac)
            return

    # If connected but no battery reported yet
    name, _ = get_device_info(connected[0])
    write_status(True, name, None, connected[0])

def main():
    running = True

    def handle_signal(sig, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    sync_all()

    dbus_cmd = [
        "dbus-monitor", "--system",
        "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"
    ]

    while running:
        try:
            proc = subprocess.Popen(
                dbus_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
        except Exception:
            time.sleep(5.0)
            sync_all()
            continue

        last_sync = time.time()
        while running and proc.poll() is None:
            now = time.time()
            if now - last_sync >= 10.0:
                sync_all()
                last_sync = now

            line = proc.stdout.readline()
            if not line:
                break
            if "Battery" in line or "Percentage" in line or "Connected" in line:
                sync_all()
                last_sync = time.time()

        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1.0)
            except Exception:
                proc.kill()

        if running:
            time.sleep(1.0)

if __name__ == "__main__":
    main()
