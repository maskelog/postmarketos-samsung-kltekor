set -eu
stamp=$(date +%Y%m%d-%H%M%S)
backup="/home/user/.local/state/webkit-fix-$stamp"
mkdir -p "$backup"
cp -p /etc/profile.d/adreno-a330-quirks.sh "$backup/adreno-a330-quirks.sh.orig"

cat > /etc/profile.d/adreno-a330-quirks.sh <<'EOF'
# Various GPU workarounds for Adreno a330

# The 'ngl' GTK renderer, which is now used by default, has worse
# performance and is somewhat more prone to crashes. The legacy GL
# renderer has since been removed. Use software rendering fallback.

export GSK_RENDERER=cairo

# This SoC's a3xx GPU driver has no IOMMU (see dmesg: "no IOMMU,
# fallback to VRAM carveout" / "No memory protection without IOMMU"),
# so DMA-BUF backed buffers are not protected/tracked the normal way.
# WebKitGTK's own accelerated compositor (independent of GSK_RENDERER)
# still used this path and corrupted the screen during rapid repaints
# (e.g. typing triggers URL-bar/autocomplete redraws in GNOME Web).
# Force WebKit to skip the DMA-BUF renderer and use software
# compositing instead.

export WEBKIT_DISABLE_DMABUF_RENDERER=1
export WEBKIT_DISABLE_COMPOSITING_MODE=1
EOF

chmod 644 /etc/profile.d/adreno-a330-quirks.sh
echo "BACKUP=$backup"
echo '--- new file ---'
cat /etc/profile.d/adreno-a330-quirks.sh
