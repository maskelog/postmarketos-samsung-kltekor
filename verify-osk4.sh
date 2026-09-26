SESSPID=3189
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$SESSPID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
for i in $(seq 1 40); do
  aid=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager/App$i --method org.gnome.SessionManager.App.GetAppId 2>/dev/null)
  if [ -n "$aid" ]; then
    echo "App$i: $aid"
  fi
done
echo '=== stevia process, again ==='
ps -eo pid,ppid,args | grep -i stevia | grep -v grep
echo '=== uptime now ==='
uptime
