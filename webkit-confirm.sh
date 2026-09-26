echo '=== SUDO DMESG: gpu/iommu/oom/segfault ==='
sudo dmesg | grep -Ei 'oom|out of memory|killed process|gpu fault|iommu|adreno|gmu|drm:msm|segfault|WebKit.*trap|Epiphany.*trap|a3xx|freedreno' | tail -100
echo '=== GREETD / SESSION START MECHANISM ==='
cat /etc/greetd/config.toml 2>/dev/null
echo '--- profile.d files ---'
ls -la /etc/profile.d/
echo '--- environment.d ---'
find /etc/environment.d /usr/lib/environment.d /home/user/.config/environment.d -type f 2>/dev/null -exec echo {} \; -exec cat {} \;
echo '=== WEBKITWEBPROCESS ENV (current, if running) ==='
for p in $(pgrep -f WebKitWebProcess); do
  echo "pid $p:"
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -Ei 'GSK_RENDERER|WEBKIT_|LIBGL_|GDK_|MESA_|GBM_|EGL_'
done
echo '=== EPIPHANY MAIN PROCESS ENV ==='
for p in $(pgrep -x epiphany); do
  echo "pid $p:"
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -Ei 'GSK_RENDERER|WEBKIT_|LIBGL_|GDK_|MESA_|GBM_|EGL_'
done
echo '=== PHOC/PHOSH ENV (confirm GSK_RENDERER inherited) ==='
for p in $(pgrep -x phoc) $(pgrep -x phosh); do
  echo "pid $p:"
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -Ei 'GSK_RENDERER'
done
