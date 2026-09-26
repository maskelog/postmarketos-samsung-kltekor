echo '=== file ==='
cat -A /etc/profile.d/adreno-a330-quirks.sh
echo '=== sh -n syntax check ==='
sh -n /etc/profile.d/adreno-a330-quirks.sh; echo "exit=$?"
echo '=== all matching procs (no -x) ==='
ps -eo pid,ppid,user,comm | grep -Ei 'gnome-session|phoc|phosh|epiphany|WebKit'
echo '=== env of gnome-session-binary, any match ==='
for p in $(pgrep -f gnome-session-binary); do
  echo "pid=$p"
  cat /proc/$p/status 2>/dev/null | grep -E '^(Name|Uid)'
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | sort
  echo '----'
done
