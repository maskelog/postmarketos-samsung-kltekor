uname -v; uptime
grep -E '^ gpio(63|78) ' /sys/kernel/debug/gpio 2>/dev/null || { mount -t debugfs none /sys/kernel/debug; grep -E '^ gpio(63|78) ' /sys/kernel/debug/gpio; }
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | grep -iE 'wcd|WCD9320 version|msm8974-snd|slim|asoc' | grep -v 'SB xfer\|Modules linked' | tail -15 | cut -c1-180
