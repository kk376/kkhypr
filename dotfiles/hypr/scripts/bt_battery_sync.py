#!/usr/bin/env python3
"""
Bluetooth Device Battery Synchronizer Daemon
Monitors connected Bluetooth audio and peripheral devices via native D-Bus signal subscriptions.
Exports current connection and battery status to /run/user/<uid>/bt_battery.json for top bar widgets.
Supports instant notification on device connection, InterfacesAdded, and PropertiesChanged events.
"""

import json
import logging
import os
import signal
import sys
import time

import gi
from gi.repository import Gio, GLib

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

class BluetoothBatterySync:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.uid = os.getuid()
        self.target_file = f"/run/user/{self.uid}/bt_battery.json"
        self.last_written = None
        self.retry_timer_id = None
        self.retry_count = 0

    def query_connected_device(self):
        try:
            proxy = Gio.DBusProxy.new_sync(
                self.bus,
                Gio.DBusProxyFlags.NONE,
                None,
                "org.bluez",
                "/",
                "org.freedesktop.DBus.ObjectManager",
                None,
            )
            objects = proxy.GetManagedObjects()
        except Exception as e:
            logging.error("Failed to query BlueZ managed objects: %s", e)
            return False, "", None, None

        for path, ifaces in objects.items():
            if "org.bluez.Device1" in ifaces:
                dev = ifaces["org.bluez.Device1"]
                if dev.get("Connected", False):
                    name = dev.get("Name", dev.get("Alias", "Bluetooth Device"))
                    mac = dev.get("Address", "")
                    pct = None

                    # Check BlueZ Battery1 interface
                    if "org.bluez.Battery1" in ifaces:
                        val = ifaces["org.bluez.Battery1"].get("Percentage")
                        if val is not None:
                            try:
                                pct = int(val)
                            except (ValueError, TypeError):
                                pass

                    # Fallback to UPower device if BlueZ hasn't exposed battery yet
                    if pct is None and mac:
                        pct = self.query_upower_battery(mac)

                    return True, name, pct, mac

        return False, "", None, None

    def query_upower_battery(self, mac: str):
        dev_str = "headset_dev_" + mac.replace(":", "_")
        try:
            upower_dev = Gio.DBusProxy.new_sync(
                self.bus,
                Gio.DBusProxyFlags.NONE,
                None,
                "org.freedesktop.UPower",
                f"/org/freedesktop/UPower/devices/{dev_str}",
                "org.freedesktop.UPower.Device",
                None,
            )
            val = upower_dev.get_cached_property("Percentage")
            if val is not None:
                return int(round(float(val.unpack())))
        except Exception:
            pass
        return None

    def write_status(self, connected: bool, name: str, percent: int | None, mac: str | None):
        state = {
            "connected": connected,
            "name": name,
            "percent": percent,
            "mac": mac,
        }
        if state == self.last_written:
            return

        temp_file = self.target_file + ".tmp"
        try:
            with open(temp_file, "w") as f:
                json.dump(state, f)
            os.replace(temp_file, self.target_file)
            self.last_written = state
            logging.info(
                "Updated status: connected=%s, name=%s, percent=%s",
                connected,
                name,
                f"{percent}%" if percent is not None else "None",
            )
        except Exception as e:
            logging.error("Failed to write %s: %s", self.target_file, e)

    def sync(self):
        connected, name, pct, mac = self.query_connected_device()
        self.write_status(connected, name, pct, mac)

        if connected and pct is None:
            # Device is connected but battery reporting is still handshaking.
            # Schedule fast retry queries.
            self.schedule_retry()
        else:
            self.cancel_retry()

    def schedule_retry(self):
        if self.retry_timer_id is not None:
            return
        self.retry_count = 0
        self.retry_timer_id = GLib.timeout_add(1000, self._on_retry_tick)

    def cancel_retry(self):
        if self.retry_timer_id is not None:
            GLib.source_remove(self.retry_timer_id)
            self.retry_timer_id = None
        self.retry_count = 0

    def _on_retry_tick(self):
        self.retry_count += 1
        connected, name, pct, mac = self.query_connected_device()
        self.write_status(connected, name, pct, mac)

        if pct is not None or not connected or self.retry_count >= 10:
            self.retry_timer_id = None
            return GLib.SOURCE_REMOVE

        return GLib.SOURCE_CONTINUE

    def on_bluez_signal(self, conn, sender, path, iface, signal_name, params, user_data):
        # Trigger immediate sync on any relevant BlueZ state transition
        if signal_name in {"PropertiesChanged", "InterfacesAdded", "InterfacesRemoved"}:
            self.sync()

    def on_upower_signal(self, conn, sender, path, iface, signal_name, params, user_data):
        self.sync()

    def run(self):
        logging.info("Starting Bluetooth Battery Synchronizer Daemon (native D-Bus)")

        # Initial synchronization
        self.sync()

        # Subscribe to BlueZ signals across all objects
        self.bus.signal_subscribe(
            "org.bluez",
            None,
            None,
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_bluez_signal,
            None,
        )

        # Subscribe to UPower signals
        self.bus.signal_subscribe(
            "org.freedesktop.UPower",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_upower_signal,
            None,
        )
        self.bus.signal_subscribe(
            "org.freedesktop.UPower",
            "org.freedesktop.UPower",
            "DeviceAdded",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_upower_signal,
            None,
        )

        # Periodic fallback sanity sync every 30 seconds
        GLib.timeout_add_seconds(30, lambda: (self.sync(), GLib.SOURCE_CONTINUE)[1])

        loop = GLib.MainLoop()

        def on_terminate(sig, frame):
            logging.info("Terminating cleanly on signal %s", sig)
            loop.quit()

        signal.signal(signal.SIGINT, on_terminate)
        signal.signal(signal.SIGTERM, on_terminate)

        loop.run()

if __name__ == "__main__":
    app = BluetoothBatterySync()
    app.run()
