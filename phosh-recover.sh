echo '=== uptime ==='
uptime
echo '=== session processes ==='
ps -o pid,stat,etime,args | grep -E 'phoc|phosh|gnome-session|greetd|stevia' | grep -v grep
rc-service greetd status 2>&1
echo '=== dmesg (last 40, gpu/usb/oom/crash) ==='
dmesg | grep -iE 'hangcheck|gpu lockup|offending|iommu|fault|oom|killed|segfault|usb|ci_hdrc' | tail -40
echo '=== greetd / session log ==='
tail -30 /var/log/greetd.log 2>/dev/null
logread 2>/dev/null | grep -iE 'phoc|phosh|greetd' | tail -20
echo '=== memory ==='
free -m
echo '=== restart session ==='
pkill -x phoc 2>/dev/null; sleep 1
rc-service greetd zap
rc-service greetd start
sleep 8
ps -o pid,stat,etime,args | grep -E 'phoc|phosh' | grep -v grep
