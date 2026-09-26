echo '=== OSK ==='
ps -o pid,args | grep phosh-osk-stevia | grep -v grep
echo '=== WebKit env (spot check via any running webkit or a quick launch not needed, check profile.d) ==='
grep WEBKIT_DISABLE /etc/profile.d/adreno-a330-quirks.sh
echo '=== gsd-power really gone ==='
pgrep -af gsd-power || echo "not running (expected)"
echo '=== root free space ==='
df -h /
