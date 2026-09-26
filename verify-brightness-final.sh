echo '=== session procs ==='
ps -o pid,ppid,args | grep -E 'gnome-session-b|gsd-power|brightness-bridge' | grep -v grep
echo '=== log ==='
tail -10 /tmp/brightness-bridge.log 2>/dev/null
echo '=== dbus check ==='
BPID=$(pgrep -f phosh-brightness-bridge.py | head -1)
if [ -n "$BPID" ]; then
  export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$BPID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
  gdbus call --session --dest org.gnome.SettingsDaemon.Power --object-path /org/gnome/SettingsDaemon/Power/Screen --method org.freedesktop.DBus.Properties.Get org.gnome.SettingsDaemon.Power.Screen Brightness
else
  echo "NO BRIDGE PROCESS RUNNING"
fi
echo '=== uptime ==='
uptime
