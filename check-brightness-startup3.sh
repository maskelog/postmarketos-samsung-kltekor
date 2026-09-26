echo '=== targeted autostart/application dirs ==='
grep -rl 'brightness-bridge' /usr/share/applications /etc/xdg/autostart /usr/share/gnome-session 2>/dev/null
echo '=== phosh.session RequiredComponents ==='
grep -A8 'RequiredComponents' /usr/share/gnome-session/sessions/phosh.session 2>/dev/null
echo '=== openrc local.d ==='
ls -la /etc/local.d/ 2>/dev/null
cat /etc/local.d/*.start 2>/dev/null
echo '=== user shell/session hooks ==='
grep -l 'brightness-bridge' /home/user/.bashrc /home/user/.profile /home/user/.bash_profile 2>/dev/null
find /home/user/.config -maxdepth 3 -iname '*brightness*' 2>/dev/null
echo '=== process tree ==='
ps -o pid,ppid,args | grep -E '^ *3194 |^ *3833 '
echo '=== real gsd-power binary present? ==='
find /usr/libexec /usr/lib/gnome-settings-daemon* -iname '*power*' 2>/dev/null
ps -eo pid,args | grep -i 'gsd-power\|gnome-settings-daemon' | grep -v grep
echo '=== full brightness log ==='
cat /tmp/brightness-bridge.log 2>/dev/null
