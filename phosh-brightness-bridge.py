#!/usr/bin/env python3
import dbus, dbus.service, dbus.mainloop.glib
from gi.repository import GLib
import os, sys, signal, time

BACKLIGHT = "/sys/class/backlight/panel/brightness"
BACKLIGHT_MAX = "/sys/class/backlight/panel/max_brightness"
SAVE_FILE = "/home/user/.config/brightness-target"
LOG_FILE = "/tmp/brightness-bridge.log"
DEFAULT_RAW = 41

def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(time.strftime("%F %T ") + str(msg) + "\n")
    except Exception:
        pass

def read_int(path, default=0):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except Exception:
        return default

def write_sysfs(path, value):
    try:
        with open(path, "w") as f:
            f.write(str(int(value)))
        return True
    except Exception as e:
        log(f"write failed path={path} value={value}: {e}")
        return False

def max_raw():
    return max(1, read_int(BACKLIGHT_MAX, 59))

def clamp_raw(raw):
    return max(1, min(max_raw(), int(raw)))

def save_brightness(raw):
    raw = clamp_raw(raw)
    try:
        os.makedirs(os.path.dirname(SAVE_FILE), exist_ok=True)
        with open(SAVE_FILE, "w") as f:
            f.write(str(raw))
    except Exception as e:
        log(f"save failed raw={raw}: {e}")

def saved_raw():
    return clamp_raw(read_int(SAVE_FILE, DEFAULT_RAW))

def raw_to_pct(raw):
    mx = max_raw()
    return max(1, min(100, int(clamp_raw(raw) * 100 / mx))) if mx else 100

def pct_to_raw(pct):
    mx = max_raw()
    return clamp_raw(int(max(1, min(100, int(pct))) * mx / 100))

class BrightnessScreen(dbus.service.Object):
    IFACE = "org.gnome.SettingsDaemon.Power.Screen"

    def __init__(self, bus):
        bus_name = dbus.service.BusName(
            "org.gnome.SettingsDaemon.Power", bus,
            replace_existing=False, allow_replacement=False, do_not_queue=True,
        )
        super().__init__(bus_name, "/org/gnome/SettingsDaemon/Power/Screen")
        saved = saved_raw()
        write_sysfs(BACKLIGHT, saved)
        log(f"started saved={saved}")

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        if iface == self.IFACE and prop == "Brightness":
            raw = read_int(BACKLIGHT, saved_raw())
            pct = raw_to_pct(raw)
            log(f"Get raw={raw} pct={pct}")
            return dbus.Int32(pct)
        raise dbus.exceptions.DBusException("Unknown property: " + prop)

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv")
    def Set(self, iface, prop, value):
        if iface == self.IFACE and prop == "Brightness":
            requested = int(value)
            pct = max(1, min(100, requested))
            raw = pct_to_raw(pct)
            log(f"Set request={requested} pct={pct} raw={raw}")
            write_sysfs(BACKLIGHT, raw)
            save_brightness(raw)
            self.PropertiesChanged(self.IFACE, {"Brightness": dbus.Int32(pct)}, [])

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        if iface == self.IFACE:
            raw = read_int(BACKLIGHT, saved_raw())
            pct = raw_to_pct(raw)
            log(f"GetAll raw={raw} pct={pct}")
            return {"Brightness": dbus.Int32(pct)}
        return {}

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

if __name__ == "__main__":
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    try:
        BrightnessScreen(bus)
    except dbus.exceptions.NameExistsException:
        # Another owner (real gsd-power, or another instance of this
        # bridge) already holds the name. Idle rather than crash so we
        # don't get logged as a failed unit / respawn-loop.
        log("name already owned elsewhere, idling")
        signal.pause()
        sys.exit(0)
    GLib.MainLoop().run()
