# Read-only: why does the WCD9320 not report present on SLIMbus?
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
echo '=== PMA8084 gpio15 (MCLK out, want: out func1 / high) ==='
grep -E '^ gpio15' /sys/kernel/debug/gpio
grep -A1 -E '^gpiochip1' /sys/kernel/debug/gpio | head -2
echo '=== PMA8084 gpio15 raw regs (0xce40..0xce46) ==='
grep -E '^ce4[0-6]:' /sys/kernel/debug/regmap/0-00/registers
echo '=== clkdiv 1 regs (0x5b43 div, 0x5b46 en) ==='
grep -E '^5b4[3-6]:' /sys/kernel/debug/regmap/0-00/registers
echo '=== tlmm gpio63 (codec reset, want: out high) / gpio72 (irq) ==='
grep -E '^ gpio(63|72) ' /sys/kernel/debug/gpio
echo '=== codec supplies (s4, s5, l1) ==='
grep -E '^ *(s4|s5|l1) |217:a0' /sys/kernel/debug/regulator/regulator_summary
echo '=== clk ==='
grep -E 'pma8084_div_clk1|xo_board' /sys/kernel/debug/clk/clk_summary
echo '=== slimbus / ngd dmesg ==='
dmesg | grep -iE 'slim|ngd|wcd|217:a0' | tail -40
