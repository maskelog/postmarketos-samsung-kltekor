echo '=== kernel version ==='
uname -a
echo '=== kernel config IOMMU ==='
if [ -f /proc/config.gz ]; then
  zcat /proc/config.gz | grep -iE 'IOMMU|ARM_SMMU|QCOM_IOMMU'
else
  echo 'no /proc/config.gz'
fi
CFG=$(find /boot -iname 'config-*' 2>/dev/null | head -1)
echo "boot config: $CFG"
if [ -n "$CFG" ]; then
  grep -iE 'IOMMU|ARM_SMMU|QCOM_IOMMU' "$CFG"
fi
echo '=== dt / iommu nodes ==='
find /proc/device-tree -iname '*iommu*' 2>/dev/null
find /sys/firmware/devicetree/base -iname '*iommu*' 2>/dev/null
echo '=== apk kernel package ==='
apk info -v | grep -i linux-postmarketos
