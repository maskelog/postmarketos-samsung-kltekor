echo '=== EHCI port status (PORTSC) ==='
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
ls /sys/kernel/debug/usb/ 2>/dev/null
for f in /sys/kernel/debug/usb/ehci/*/registers; do echo "$f"; cat "$f"; done
cat /sys/kernel/debug/ci_hdrc.0/port_test 2>/dev/null
for f in /sys/kernel/debug/ci_hdrc.0/*; do echo "--- $f"; cat "$f" 2>/dev/null | head -20; done
echo '=== hub port ==='
for f in /sys/bus/usb/devices/1-0:1.0/usb1-port1/*; do [ -f "$f" ] && echo "$f: $(cat $f 2>/dev/null)"; done
echo '=== PHY / regulators ==='
for r in /sys/class/regulator/*; do n=$(cat $r/name 2>/dev/null); case "$n" in l24|l6|l3|5vs1|*usb*|*vbus*|*ldo24*) echo "$n state=$(cat $r/state 2>/dev/null) uV=$(cat $r/microvolts 2>/dev/null) users=$(cat $r/num_users 2>/dev/null)";; esac; done
dmesg | grep -iE 'l24|ulpi|phy|hsusb' | tail -20
echo '=== MUIC / charger (Samsung routes D+/D- through the MUIC switch) ==='
find /proc/device-tree -iname '*muic*' -o -iname '*max778*' -o -iname '*max776*' -o -iname '*tsu67*' -o -iname '*sm5502*' -o -iname '*sm5504*' 2>/dev/null
for d in /sys/bus/i2c/devices/*; do echo "$d name=$(cat $d/name 2>/dev/null) driver=$(basename $(readlink $d/driver 2>/dev/null) 2>/dev/null)"; done
dmesg | grep -iE 'max77|muic|i2c' | tail -20
echo '=== recent dmesg ==='
dmesg | tail -15
