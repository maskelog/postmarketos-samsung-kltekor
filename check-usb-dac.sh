echo '=== KERNEL ==='
uname -r
echo '=== USB CONTROLLERS / ROLE ==='
for d in /sys/class/usb_role/*; do [ -e "$d" ] && echo "$d: $(cat $d/role 2>/dev/null)"; done
ls /sys/bus/platform/drivers/ci_hdrc/ 2>/dev/null
for f in /sys/kernel/debug/ci_hdrc.*/role /sys/devices/platform/soc*/*usb*/ci_hdrc.*/role; do [ -e "$f" ] && echo "$f: $(cat $f)"; done
find /sys/devices -maxdepth 6 -name role -path '*ci_hdrc*' 2>/dev/null | while read f; do echo "$f: $(cat $f)"; done
echo '=== DT usb node ==='
for n in /proc/device-tree/soc/usb@*; do
  echo "$n"
  for p in dr_mode extcon status compatible; do [ -e "$n/$p" ] && printf '  %s: %s\n' "$p" "$(tr '\0' ' ' < $n/$p)"; done
  ls "$n" | tr '\n' ' '; echo
done
echo '=== EXTCON ==='
for e in /sys/class/extcon/*; do [ -e "$e" ] && echo "$e name=$(cat $e/name) state=$(cat $e/state 2>/dev/null | tr '\n' ' ')"; done
echo '=== GADGET (UDC) ==='
ls /sys/class/udc/ 2>/dev/null
for u in /sys/class/udc/*; do [ -e "$u" ] && echo "$u state=$(cat $u/state 2>/dev/null) function=$(cat $u/function 2>/dev/null)"; done
echo '=== USB BUS (host side) ==='
ls /sys/bus/usb/devices/
for d in /sys/bus/usb/devices/*; do [ -e "$d/idVendor" ] && echo "$d $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null) speed=$(cat $d/speed)"; done
echo '=== REGULATORS (vbus/otg) ==='
for r in /sys/class/regulator/*; do n=$(cat $r/name 2>/dev/null); case "$n" in *vbus*|*otg*|*VBUS*|*OTG*|*usb*|*5v*) echo "$r $n state=$(cat $r/state 2>/dev/null)";; esac; done
echo '=== POWER SUPPLY ==='
for p in /sys/class/power_supply/*; do echo "$p type=$(cat $p/type 2>/dev/null) online=$(cat $p/online 2>/dev/null) usb_type=$(cat $p/usb_type 2>/dev/null)"; done
echo '=== MODULES ==='
lsmod | grep -iE 'snd_usb|usb|ci_|extcon|sm5502|max77|chipidea'
ls /lib/modules/$(uname -r)/kernel/sound/usb/ 2>/dev/null
echo '=== ALSA ==='
cat /proc/asound/cards
echo '=== DMESG usb/otg/extcon ==='
dmesg | grep -iE 'usb|otg|ci_hdrc|extcon|vbus|muic|sm5502|max77|snd|hub' | tail -80
