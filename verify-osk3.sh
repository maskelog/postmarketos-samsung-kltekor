uptime
ps -eo pid,ppid,args | grep -Ei 'stevia|osk' | grep -v grep
SESSPID=3189
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$SESSPID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
echo "bus=$DBUS_SESSION_BUS_ADDRESS"
gdbus introspect --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --recurse 2>&1 | grep -E 'node |AppId|Running|Phase'
