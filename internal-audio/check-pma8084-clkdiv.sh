# Read-only: identify PMA8084 peripherals at 0x5b00-0x5d00 (clock dividers?)
# via the SPMI PMIC regmap debugfs. Writes nothing.
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
echo '=== regmap debugfs dirs ==='
for R in /sys/kernel/debug/regmap/*; do
  echo "$(basename $R) name=$(cat $R/name 2>/dev/null)"
done
for R in /sys/kernel/debug/regmap/0-0*; do
  [ -e "$R/registers" ] || continue
  echo "### $R name=$(cat $R/name 2>/dev/null)"
  # peripheral type (0x04) / subtype (0x05) of each candidate block, plus
  # the GPIO block at 0xc000 (type 0x10) as a known reference
  grep -E '^(5b0[4-5]|5b4[0-8]|5c0[4-5]|5c4[0-8]|5d0[4-5]|c004|c005|ce0[4-5]|ce4[0-6]):' $R/registers 2>/dev/null
done
