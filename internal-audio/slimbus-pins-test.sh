# Test: mux tlmm gpio70/71 to the "slimbus" function (runtime only, reverts
# on reboot), then reload the WCD9320 module and see if it enumerates.
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
P=$(ls -d /sys/kernel/debug/pinctrl/fd510000.pinctrl* | head -1); echo "pinctrl: $P"
grep -E '^pin 7[01] ' $P/pinmux-pins
echo '=== before ==='; grep -E '^ gpio7[01] ' /sys/kernel/debug/gpio
echo 'gpio70 slimbus' > $P/pinmux-select && echo 'gpio71 slimbus' > $P/pinmux-select && echo 'muxed'
echo '=== after ==='; grep -E '^ gpio7[01] ' /sys/kernel/debug/gpio; grep -E '^pin 7[01] ' $P/pinmux-pins
M=$(cat /proc/uptime | cut -d' ' -f1); echo "mark $M"
modprobe -r snd_soc_wcd9320; sleep 1; modprobe snd_soc_wcd9320
sleep 6
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | awk -v m="$M" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 >= m+0) print}' | grep -v 'Modules linked in' | tail -60 | cut -c1-200
