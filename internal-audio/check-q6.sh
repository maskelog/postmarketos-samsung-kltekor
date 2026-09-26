# r10 check: did the APR bus and q6 services bind? (read-only)
uname -a
echo '=== modules ==='
lsmod | grep -E 'apr|q6|qdsp6|pdr|snd_soc' || echo 'none loaded'
echo '=== apr rpmsg channel ==='
for d in /sys/bus/rpmsg/devices/*apr*; do echo "$d driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
echo '=== apr bus devices ==='
for d in /sys/bus/apr/devices/*; do [ -e "$d" ] && echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
echo '=== asoc components ==='
cat /sys/kernel/debug/asoc/components 2>/dev/null || { mount -t debugfs none /sys/kernel/debug 2>/dev/null; cat /sys/kernel/debug/asoc/components 2>/dev/null; }
cat /sys/kernel/debug/asoc/dais 2>/dev/null | head -40
echo '=== adsp ==='
cat /sys/class/remoteproc/remoteproc1/state
echo '=== dmesg apr/q6/adsp ==='
dmesg | grep -iE 'apr|q6|qdsp|adsp|remoteproc|pdr|asoc' | tail -40
echo '=== deferred ==='
cat /sys/kernel/debug/devices_deferred 2>/dev/null
echo '=== alsa ==='
cat /proc/asound/cards
