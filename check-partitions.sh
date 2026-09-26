echo '=== losetup ==='
losetup -a
echo '=== lsblk full tree ==='
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
echo '=== backing file details ==='
for f in $(losetup -a | sed -n 's/.*(\(.*\))/\1/p'); do
  echo "$f:"
  ls -la "$f"
  df -h "$f"
done
echo '=== parted mmcblk0 ==='
parted -s /dev/mmcblk0 unit MiB print free 2>&1
echo '=== fstab ==='
cat /etc/fstab
echo '=== root fs usage breakdown ==='
du -xhd1 / 2>/dev/null | sort -rh | head -20
