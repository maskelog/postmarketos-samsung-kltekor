ps -o pid,ppid,comm,args | grep -E 'gnome-session-binary|phoc$|phosh$' | grep -v grep
echo '---'
for p in $(pgrep -x gnome-session-b 2>/dev/null); do
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -E 'GSK_RENDERER|WEBKIT_'
done
