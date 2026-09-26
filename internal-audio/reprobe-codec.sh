# Re-trigger the deferred WCD9320 probe once and capture what SLIMbus says.
# Touches only the codec's own driver binding (probe re-runs its power-on and
# reset sequence). No PMIC register dumps.
M=$(cat /proc/uptime | cut -d' ' -f1); echo "mark $M"
grep -q ' dyndbg' /proc/cmdline; ls /proc/dynamic_debug/control >/dev/null 2>&1 && \
  { echo 'module slimbus +p' > /proc/dynamic_debug/control; echo 'module slim_qcom_ngd_ctrl +p' > /proc/dynamic_debug/control; echo dyndbg-on; }
for d in 217:a0:0:0 217:a0:1:0; do echo "$d" > /sys/bus/slimbus/drivers_probe 2>&1; done
sleep 3
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | awk -v m="$M" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 >= m+0) print}' | grep -v 'Modules linked in' | tail -60 | cut -c1-200
