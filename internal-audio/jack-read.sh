# Read-only: PMA8084 GPIO20 (headset detect) state
grep -E '^ gpio20:' /sys/kernel/debug/gpio
R=/sys/kernel/debug/regmap/0-00/registers
rd() { dd if=$R bs=9 skip=$(($1)) count=1 2>/dev/null | tr -d '\n'; }
s=""; for i in 1 2 3 4 5 6; do s="$s $(rd 0xd308)"; done; echo "STATUS1:$s"
echo "mode/vin/pull: $(rd 0xd340) $(rd 0xd341) $(rd 0xd342) en $(rd 0xd346)"
