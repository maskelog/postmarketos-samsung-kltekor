# Reload the WCD9320 module once (it has no users) with SLIMbus debug on,
# and capture the probe / logical-address messages. No PMIC register dumps.
M=$(cat /proc/uptime | cut -d' ' -f1); echo "mark $M"
for m in slimbus slim_qcom_ngd_ctrl snd_soc_wcd9320; do echo "module $m +p" > /proc/dynamic_debug/control 2>/dev/null; done
lsmod | grep -E '^snd_soc_wcd9320'
modprobe -r snd_soc_wcd9320 && echo unloaded
sleep 1
modprobe snd_soc_wcd9320 && echo loaded
echo 'module snd_soc_wcd9320 +p' > /proc/dynamic_debug/control 2>/dev/null
sleep 5
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | awk -v m="$M" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 >= m+0) print}' | grep -v 'Modules linked in' | tail -80 | cut -c1-200
