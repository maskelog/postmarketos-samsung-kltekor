#!/bin/sh
echo '=== RPMSG CONTROL/CHAR DEVICES ==='
ls -l /dev/rpmsg* /sys/class/rpmsg /sys/bus/rpmsg/drivers 2>/dev/null
for d in /sys/bus/rpmsg/devices/*; do
    echo "$d driver=$(readlink "$d/driver") override=$(cat "$d/driver_override" 2>/dev/null)"
done
echo '=== KERNEL ABI AND RPMSG CONFIG ==='
zcat /proc/config.gz | grep -E 'CONFIG_(RPMSG|MODVERSIONS|CFI|CC_VERSION|CC_IS|CLANG_VERSION|GCC_VERSION|IKHEADERS)'
echo '=== PYTHON AND BUILD TOOLS ==='
command -v python3; command -v cc; command -v dtc
echo '=== BOARD ID ==='
tr '\000' ' ' < /proc/device-tree/compatible; echo
for f in /proc/device-tree/qcom,board-id /proc/device-tree/qcom,msm-id; do
    [ -f "$f" ] && od -An -tx1 "$f"
done
echo '=== AUDIO-RELATED REGULATORS ==='
cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | grep -E 'name|s4|s2|l1 |l3 |l4 |l6 |l25|vph'
echo '=== AUDIO GPIO CLAIMS ==='
cat /sys/kernel/debug/gpio 2>/dev/null
echo '=== DISK AND MEMORY ==='
df -h / /mnt/pmos-storage; free -m
