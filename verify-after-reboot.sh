set -eu
echo 'BOOT'
cat /proc/sys/kernel/random/boot_id
uptime
echo 'STORAGE'
findmnt -rn -M /home/user -o SOURCE,TARGET,FSTYPE,OPTIONS
df -h /home/user /
testfile=$(mktemp /home/user/.storage-verify.XXXXXX)
printf 'user-write-after-reboot-ok\n' > "$testfile"
cat "$testfile"
rm "$testfile"
echo 'KEYBOARD'
ps -o pid,ppid,args | grep -E '[p]hosh-osk-stevia|[g]nome-session-binary'
phosh_pid=$(ps -o pid,args | awk '$2 == "/usr/libexec/phosh" {print $1; exit}')
test -n "$phosh_pid"
export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < "/proc/$phosh_pid/environ" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
export XDG_RUNTIME_DIR=/run/user/10000
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner sm.puri.OSK0
gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.IsSessionRunning
gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible
grep '^X-GNOME-Provides=' /home/user/.config/autostart/sm.puri.OSK0.desktop
