# Sample single PMIC registers via regmap debugfs with dd (one line each,
# no full dump): PMA8084 GPIO15 STATUS1 (0xce08, bit0 = pin level) and
# GPIO16 (0xcf08, 32 kHz sleep clock) as a reference.
R=/sys/kernel/debug/regmap/0-00/registers
L=$(head -c 64 $R | head -1 | wc -c); echo "line length $L"
head -2 $R
rd() { dd if=$R bs=$L skip=$(($1)) count=1 2>/dev/null | tr -d '\n'; }
echo "check: $(rd 0xce40) $(rd 0xce46) $(rd 0x5b46)"
for name in 0xce08 0xcf08; do
  s=""; for i in $(seq 1 24); do v=$(rd $name); s="$s ${v##* }"; done
  echo "$name:$s"
done
dmesg | tail -3 | cut -c1-120
