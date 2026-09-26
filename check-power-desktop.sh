for f in /usr/share/applications/org.gnome.SettingsDaemon.Power.desktop \
         /home/user/.config/autostart/org.gnome.SettingsDaemon.Power.desktop; do
  echo "--- $f ---"
  cat "$f" 2>&1
done
echo '=== any .desktop anywhere referencing gsd-power or Power.desktop, modified recently ==='
find /usr/share/applications /home/user/.config/autostart -iname '*power*' 2>/dev/null -exec ls -la {} \;
