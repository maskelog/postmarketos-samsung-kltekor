# Force the chipidea OTG port into host mode so a USB DAC can enumerate.
# Revert: echo gadget > <same role file>   (or reboot)
echo '=== BEFORE ==='
uname -r
ROLE=$(find /sys/devices -name role -path '*ci_hdrc*' 2>/dev/null | head -1)
[ -z "$ROLE" ] && ROLE=$(ls -d /sys/class/usb_role/*/role 2>/dev/null | head -1)
echo "role file: ${ROLE:-NONE}"
[ -n "$ROLE" ] && echo "current role: $(cat $ROLE)"
for e in /sys/class/extcon/*; do [ -e "$e" ] && echo "$e name=$(cat $e/name) state=$(cat $e/state 2>/dev/null | tr '\n' ' ')"; done
for n in /proc/device-tree/soc/usb@*; do
  printf '%s dr_mode=%s status=%s extcon=%s\n' "$n" \
    "$(tr -d '\0' < $n/dr_mode 2>/dev/null)" "$(tr -d '\0' < $n/status 2>/dev/null)" \
    "$( [ -e $n/extcon ] && echo yes || echo no)"
done
if [ -z "$ROLE" ]; then
  echo 'No role switch file found - cannot switch at runtime.'
  dmesg | grep -iE 'ci_hdrc|otg|extcon|usb' | tail -40
  exit 1
fi
echo '=== SWITCH TO HOST ==='
MARK=$(cat /proc/uptime | cut -d' ' -f1)
echo "dmesg mark (uptime): $MARK"
echo host > "$ROLE" && echo "wrote host -> now: $(cat $ROLE)"
modprobe snd-usb-audio 2>&1
sleep 6
echo '=== AFTER ==='
for d in /sys/bus/usb/devices/*; do [ -e "$d/idVendor" ] && echo "$d $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/manufacturer 2>/dev/null) $(cat $d/product 2>/dev/null) speed=$(cat $d/speed)"; done
for r in /sys/class/regulator/*; do n=$(cat $r/name 2>/dev/null); case "$n" in *vbus*|*otg*|*VBUS*|*OTG*|*usb*|*5v*|*5V*) echo "regulator $n state=$(cat $r/state 2>/dev/null)";; esac; done
echo '--- asound ---'
cat /proc/asound/cards
echo '--- dmesg ---'
dmesg | tail -60
