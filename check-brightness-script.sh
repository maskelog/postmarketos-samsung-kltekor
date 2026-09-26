echo '=== script content ==='
cat /usr/local/bin/phosh-brightness-bridge.py
echo '=== how it is started ==='
grep -rl 'phosh-brightness-bridge' /etc /home/user/.config 2>/dev/null
find / -xdev -iname '*brightness-bridge*' 2>/dev/null
echo '=== related openrc/service files ==='
find /etc/init.d /etc/runlevels -iname '*brightness*' 2>/dev/null
echo '=== backlight sysfs ==='
ls -la /sys/class/backlight/ 2>/dev/null
for d in /sys/class/backlight/*/; do
  echo "$d"
  cat "$d/max_brightness" 2>/dev/null
  cat "$d/brightness" 2>/dev/null
  cat "$d/actual_brightness" 2>/dev/null
  ls -la "$d" 2>/dev/null
done
echo '=== process ==='
ps -o pid,ppid,user,args | grep -i brightness | grep -v grep
