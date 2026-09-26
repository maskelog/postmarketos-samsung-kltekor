echo '=== system autostart / applications ==='
grep -rl 'brightness-bridge' /usr/share /etc 2>/dev/null
echo '=== phosh.session RequiredComponents ==='
grep -A5 'RequiredComponents' /usr/share/gnome-session/sessions/phosh.session 2>/dev/null
echo '=== local.d (openrc) ==='
ls -la /etc/local.d/ 2>/dev/null
cat /etc/local.d/*.start 2>/dev/null
echo '=== bashrc/profile hooks ==='
grep -rl 'brightness-bridge' /home/user/.bashrc /home/user/.profile /home/user/.bash_profile /home/user/.config 2>/dev/null
echo '=== process tree around it ==='
ps -o pid,ppid,args | grep -E '3194|3833' | grep -v grep
echo '=== is real gsd-power present anywhere ==='
which gsd-power 2>/dev/null
find /usr/libexec /usr/lib -iname '*gsd-power*' 2>/dev/null
ps -eo pid,args | grep -i 'power' | grep -v grep
echo '=== full brightness log ==='
cat /tmp/brightness-bridge.log 2>/dev/null
