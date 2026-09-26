# r11 check (read-only): SLIMbus, WCD9320, MCLK, sound card
uname -v
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
echo '=== modules ==='
lsmod | grep -E 'slim|wcd|msm8974|clk_spmi|q6|apr' 
echo '=== slimbus devices ==='
ls /sys/bus/slimbus/devices/ 2>/dev/null
for d in /sys/bus/slimbus/devices/*; do [ -e "$d" ] && echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
echo '=== mclk ==='
grep -E 'pma8084_div_clk|div_clk1' /sys/kernel/debug/clk/clk_summary
grep -A1 'gpio15' /sys/kernel/debug/pinctrl/*pma8084*/pinmux-pins 2>/dev/null | head -3
echo '=== alsa ==='
cat /proc/asound/cards
aplay -l 2>/dev/null
echo '=== deferred ==='
cat /sys/kernel/debug/devices_deferred 2>/dev/null | grep -v -E 'etm|etr|etf|funnel|tpiu|replicator'
echo '=== dmesg ==='
dmesg | grep -iE 'slim|ngd|wcd|taiko|msm8974-snd|sndcard|clkdiv|asoc|q6afe|q6asm|apr' | tail -60
