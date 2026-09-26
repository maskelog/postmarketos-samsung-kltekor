echo '=== boot ==='
uname -r; uptime
cat /proc/cmdline
echo '=== pstore (previous boot) ==='
mount | grep -q pstore || mount -t pstore pstore /sys/fs/pstore 2>&1
ls -la /sys/fs/pstore/
for f in /sys/fs/pstore/*; do
  [ -f "$f" ] || continue
  echo "##### $f"
  grep -iE 'hangcheck|lockup|offending|iommu|fault|oops|panic|bug:|watchdog|rcu.*stall|ci_hdrc|usb|oom|killed' "$f" | tail -60
  echo '--- tail ---'
  tail -40 "$f"
done
echo '=== this boot: warnings ==='
dmesg | grep -iE 'hangcheck|lockup|iommu|fault|oops|panic|rcu.*stall|l24|error' | tail -30
echo '=== session ==='
ps -o pid,etime,args | grep -E 'phoc|phosh' | grep -v grep
echo '=== usb role ==='
cat /sys/devices/platform/soc/f9a55000.usb/ci_hdrc.0/role
