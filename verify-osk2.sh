uptime
ps -eo pid,ppid,args | grep -Ei 'stevia|gnome-session-b|osk' | grep -v grep
echo '=== autostart dir sanity ==='
ls -la /home/user/.config/autostart/
echo '=== gnome-session dbus introspect for App list ==='
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$(pgrep -x gnome-session-b | head -1)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
gdbus introspect --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --recurse | grep -E 'node |AppId|Running'
