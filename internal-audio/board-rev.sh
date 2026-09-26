# Read-only: find the klte board revision.
cat /proc/cmdline; echo
tr '\0' ' ' < /proc/device-tree/model; echo
ls /proc/device-tree/chosen/
for f in /proc/device-tree/chosen/*; do case "$f" in *bootargs*|*initrd*|*kaslr*|*rng*) continue;; esac; printf '%s: ' "$(basename $f)"; tr '\0' ' ' < "$f" | head -c 200; echo; done
ls /proc/device-tree/ | grep -i -E 'lk2nd|qcom,board|qcom,msm'
[ -d /proc/device-tree/lk2nd ] && for f in /proc/device-tree/lk2nd/*; do printf '%s: ' "$(basename $f)"; tr '\0' ' ' < "$f" | head -c 300; echo; done
dmesg | grep -iE 'machine model|board|hw_rev|revision' | head
cat /sys/devices/soc0/* 2>/dev/null | head -20
ls /sys/devices/soc0/ 2>/dev/null
