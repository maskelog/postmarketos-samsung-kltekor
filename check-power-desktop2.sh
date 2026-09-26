echo '=== which package owns gsd-power binary ==='
apk info --who-owns /usr/libexec/gsd-power 2>&1
echo '=== list files owned by that package ==='
PKG=$(apk info --who-owns /usr/libexec/gsd-power 2>/dev/null | sed -n 's/.* is owned by //p' | sed 's/-[0-9].*//')
echo "pkg=$PKG"
apk info -L "$PKG" 2>&1 | grep -i desktop
echo '=== grep only inside /usr/share/applications (not recursive) for gsd-power or Power.Screen ==='
grep -l 'gsd-power\|SettingsDaemon.Power\|SettingsDaemon/Power' /usr/share/applications/*.desktop 2>/dev/null
echo '=== grep only inside /home/user/.config/autostart ==='
grep -l 'gsd-power\|SettingsDaemon.Power\|SettingsDaemon/Power\|brightness-bridge' /home/user/.config/autostart/*.desktop 2>/dev/null
