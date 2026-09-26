echo '=== files touched around first bridge start (2026-06-08) ==='
find /usr/share/applications /etc/xdg/autostart /home/user/.config/autostart -newermt '2026-06-08 00:00:00' ! -newermt '2026-06-09 00:00:00' -type f 2>/dev/null
echo '=== all autostart-phase desktop files mentioning python or local/bin ==='
grep -l 'Exec=.*python\|Exec=.*/usr/local/bin' /usr/share/applications/*.desktop /etc/xdg/autostart/*.desktop 2>/dev/null
echo '=== phosh-session wrapper itself ==='
cat /usr/bin/phosh-session 2>/dev/null
file /usr/bin/phosh-session 2>/dev/null
echo '=== ls autostart dirs with mtimes ==='
ls -la --time-style=full-iso /etc/xdg/autostart/ 2>/dev/null
