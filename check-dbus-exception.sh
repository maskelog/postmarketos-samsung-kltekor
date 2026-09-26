BPID=$(pgrep -f phosh-brightness-bridge.py | head -1)
echo "bridge pid=$BPID"
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$BPID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
python3 - <<'PY'
import dbus, dbus.service, dbus.mainloop.glib
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = "org.gnome.SettingsDaemon.Power"
try:
    b = dbus.service.BusName(name, bus, replace_existing=False, allow_replacement=False, do_not_queue=True)
    print("acquired ok (name was free)")
except dbus.exceptions.DBusException as e:
    print("EXC TYPE:", type(e).__name__)
    print("EXC STR:", repr(str(e)))
except Exception as e:
    print("outer error:", repr(e))
PY
