#!/usr/bin/env python3
"""
Bluetooth Device Battery to Alias Synchronizer
Monitors connected Bluetooth audio/peripheral devices and updates their BlueZ Alias
to match their current battery percentage (e.g. '100%', '80%').
This allows desktop bars (like Noctalia) to render:
[BT Logo] [BT Battery Percentage]
without modifying or conflating the system/laptop battery.
"""

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

def get_device_battery(mac):
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "info", mac],
            stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            if "Battery Percentage:" in line:
                m = re.search(r"\((\d+)\)", line)
                if m:
                    return m.group(1)
                parts = line.split(":")[-1].strip().split()
                if parts:
                    return parts[0]
    except Exception:
        pass

    # Fallback to UPower
    dev_str = "headset_dev_" + mac.replace(":", "_")
    try:
        out = subprocess.check_output(
            ["upower", "-i", f"/org/freedesktop/UPower/devices/{dev_str}"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            if "percentage:" in line:
                return line.split(":")[-1].replace("%", "").strip()
    except Exception:
        pass

    return None

def set_device_alias(mac, alias):
    dev_path = f"/org/bluez/hci0/dev_{mac.replace(':', '_')}"
    cmd = [
        "busctl", "--system", "call", "org.bluez", dev_path,
        "org.freedesktop.DBus.Properties", "Set", "ssv",
        "org.bluez.Device1", "Alias", "s", alias
    ]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        pass

def sync_all():
    connected = get_connected_devices()
    for mac in connected:
        pct = get_device_battery(mac)
        if pct is not None:
            target_alias = f"{pct}%"
            set_device_alias(mac, target_alias)

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
            if now - last_sync >= 20.0:
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
