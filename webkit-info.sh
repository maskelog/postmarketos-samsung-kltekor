echo '=== VERSIONS ==='
apk info -v | grep -E '^(epiphany|webkit2gtk|webkitgtk|phoc|phosh|mesa|libwayland|wlroots|libdrm)' | sort
echo '=== BINARY ==='
which epiphany epiphany-browser 2>/dev/null
readlink -f "$(which epiphany 2>/dev/null || which epiphany-browser 2>/dev/null)"
echo '=== GPU / DRM ==='
lsmod | grep -Ei 'msm|freedreno|adreno|panfrost|lima|vc4'
ls -la /dev/dri/ 2>/dev/null
for c in /sys/kernel/debug/dri/*/name; do echo "$c:"; cat "$c" 2>/dev/null; done
find /usr/lib -maxdepth 3 -iname '*dri*' -type d 2>/dev/null
echo '=== ENV OVERRIDES (system-wide) ==='
grep -riE 'WEBKIT_|LIBGL_|GDK_|GSK_|MESA_' /etc/environment /etc/profile /etc/profile.d/*.sh 2>/dev/null
echo '=== EPIPHANY DESKTOP FILE / LAUNCH ENV ==='
cat /usr/share/applications/org.gnome.Epiphany.desktop 2>/dev/null
echo '=== USER OVERRIDES ==='
find /home/user/.config /home/user/.local -iname '*epiphany*' -o -iname '*webkit*' 2>/dev/null
echo '=== MEMORY ==='
free -h
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree'
echo '=== ZRAM/SWAP ==='
swapon --show 2>/dev/null
echo '=== RECENT OOM / GPU FAULT IN DMESG ==='
dmesg | grep -Ei 'oom|out of memory|killed process|gpu fault|iommu|adreno|gmu|drm:msm|segfault|WebKit.*trap|Epiphany.*trap' | tail -80
echo '=== LOG FILES ==='
ls -la /var/log/ 2>/dev/null
find /home/user/.cache /home/user/.local/state -iname '*epiphany*' -o -iname '*webkit*' -o -iname '*phoc*' -o -iname '*phosh*' 2>/dev/null
echo '=== RUNNING PROCESSES ==='
ps -o pid,ppid,rss,vsz,comm,args | grep -Ei 'epiphany|WebKit|phoc|phosh' | grep -v grep
