echo '=== user autostart dir ==='
ls -la /home/user/.config/autostart/ 2>/dev/null
for f in /home/user/.config/autostart/*.desktop; do
  echo "--- $f ---"
  cat "$f" 2>/dev/null
done
echo '=== recent brightness log ==='
tail -40 /tmp/brightness-bridge.log 2>/dev/null
echo '=== dbus name check ==='
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/3833/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
gdbus call --session --dest org.gnome.SettingsDaemon.Power --object-path /org/gnome/SettingsDaemon/Power/Screen --method org.freedesktop.DBus.Properties.Get org.gnome.SettingsDaemon.Power.Screen Brightness
echo '=== is this the only owner (no real gsd-power fighting it) ==='
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.ListNames | tr ',' '\n' | grep -i settingsdaemon
ps -eo pid,args | grep -i gsd-power | grep -v grep
