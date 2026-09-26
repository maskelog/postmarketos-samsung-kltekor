echo '=== STORAGE ==='
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
df -hT
cat /etc/fstab
cat /proc/partitions
echo '=== SESSION ==='
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/3273/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
export XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
gdbus introspect --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --recurse | grep -E 'node |AppId|StartupId|Phase|Registered|Running|Disabled|Autostart'
echo '=== CONFIG ==='
find /usr/share /usr/local/share /etc /home/user -name phosh.session -o -name sm.puri.OSK0.desktop 2>/dev/null
cat /usr/share/gnome-session/sessions/phosh.session | tail -3
