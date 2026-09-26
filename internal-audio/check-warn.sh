# Read-only: what is the WARN storm at ~308 s?
uptime
dmesg | grep -c 'WARNING:'
dmesg | grep -m3 -B2 -A30 'WARNING:' | head -120
echo '=== last 30 ==='
dmesg | tail -30 | cut -c1-220
echo '=== wcd/slim/ngd lines (no stack traces) ==='
dmesg | grep -iE 'slim|ngd|wcd|217:a0' | grep -v 'Modules linked in' | head -40
