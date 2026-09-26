# Keep the SLIMbus NGD runtime-active (bus clock running), wait, then reload
# the WCD9320 module. Runtime only; reboot restores autosuspend.
for p in $(find /sys/devices/platform/soc/fe12f000.slim -name control -path '*power*' 2>/dev/null); do
  d=$(dirname $(dirname $p)); echo "$d: status=$(cat $(dirname $p)/runtime_status) control=$(cat $p) delay=$(cat $(dirname $p)/autosuspend_delay_ms 2>/dev/null)"
done
for p in $(find /sys/devices/platform/soc/fe12f000.slim -name control -path '*power*' 2>/dev/null); do echo on > $p; done
sleep 1
for p in $(find /sys/devices/platform/soc/fe12f000.slim -name runtime_status 2>/dev/null); do echo "$p -> $(cat $p)"; done
sleep 5
M=$(cat /proc/uptime | cut -d' ' -f1); echo "mark $M"
modprobe -r snd_soc_wcd9320; sleep 1; modprobe snd_soc_wcd9320
sleep 6
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | awk -v m="$M" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 >= m+0) print}' | grep -v 'Modules linked in' | tail -60 | cut -c1-200
