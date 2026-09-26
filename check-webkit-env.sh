for p in $(pgrep -f WebKitWebProcess); do
  echo "pid=$p"
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -E 'WEBKIT_DISABLE|GSK_RENDERER'
  echo '----'
done
