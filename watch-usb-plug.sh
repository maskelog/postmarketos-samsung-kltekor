# Watch USB enumeration for ~90 s while the user (re)plugs the Y-cable + DAC.
ROLE=/sys/devices/platform/soc/f9a55000.usb/ci_hdrc.0/role
echo "role: $(cat $ROLE)"
[ "$(cat $ROLE)" = host ] || { echo host > $ROLE; echo 'switched to host'; }
# keep the root hub awake so a connect can't be missed while it is autosuspended
echo on > /sys/bus/usb/devices/usb1/power/control 2>/dev/null
echo "usb1 runtime: $(cat /sys/bus/usb/devices/usb1/power/runtime_status 2>/dev/null)"
START=$(dmesg | tail -1 | sed 's/^\[ *\([0-9.]*\)\].*/\1/')
echo "start mark: $START"
for i in $(seq 1 18); do
  sleep 5
  printf '[t+%ss] devices:' $((i*5))
  for d in /sys/bus/usb/devices/*; do [ -e "$d/idVendor" ] && printf ' %s=%s:%s' "$(basename $d)" "$(cat $d/idVendor)" "$(cat $d/idProduct)"; done
  echo
done
echo '=== dmesg since start ==='
dmesg | awk -v s="$START" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 > s+0) print}'
echo '=== device tree ==='
for d in /sys/bus/usb/devices/*; do [ -e "$d/idVendor" ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/manufacturer 2>/dev/null) $(cat $d/product 2>/dev/null) speed=$(cat $d/speed) maxpower=$(cat $d/bMaxPower 2>/dev/null)"; done
for p in /sys/bus/usb/devices/1-1:1.0/1-1-port*; do [ -e "$p/state" ] && echo "$(basename $p): $(cat $p/state) over_current=$(cat $p/over_current_count)"; done
echo '=== ALSA ==='
cat /proc/asound/cards
aplay -l 2>/dev/null
