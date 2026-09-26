echo '=== dbus service activation files ==='
grep -rl 'brightness-bridge' /usr/share/dbus-1 /home/user/.local/share/dbus-1 2>/dev/null
cat /usr/share/dbus-1/services/org.gnome.SettingsDaemon.Power.service 2>/dev/null
find /usr/share/dbus-1/services /home/user/.local/share/dbus-1/services -iname '*settingsdaemon*power*' 2>/dev/null
echo '=== is there a dbus-daemon (not dbus-broker) process ==='
ps -ef | grep -i 'dbus-daemon\|dbus-broker' | grep -v grep
echo '=== full process tree from pid 1 down through session ==='
ps -eo pid,ppid,args | grep -E '2636|2858|2867|2890|2915|3194|3206'
