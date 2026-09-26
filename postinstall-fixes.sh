#!/bin/sh
# postmarketOS klte (Galaxy S5) post-install fixes.
# Run once after a fresh pmbootstrap install, on first login, as the
# normal user (needs sudo). Safe to re-run; each step is guarded.
set -eu

echo '== Fix 1: phosh-osk-stevia autostart =='
# GNOME Session 48 (gsm-autostart-app.c) splits X-GNOME-Provides on ';'
# with g_strsplit, which keeps a trailing empty string. Its duplicate-
# provider check then matches that empty string against Phosh shell's
# own trailing-empty entry and silently drops the Stevia OSK launcher,
# so the on-screen keyboard never starts. A user override without the
# trailing ';' avoids the clash.
SYS_DESKTOP=/usr/share/applications/sm.puri.OSK0.desktop
USER_AUTOSTART="$HOME/.config/autostart/sm.puri.OSK0.desktop"
if [ -f "$SYS_DESKTOP" ] && [ ! -f "$USER_AUTOSTART" ]; then
  mkdir -p "$HOME/.config/autostart"
  sed 's/^X-GNOME-Provides=.*/X-GNOME-Provides=inputmethod/' "$SYS_DESKTOP" > "$USER_AUTOSTART"
  echo "installed $USER_AUTOSTART"
else
  echo "skip (system desktop file missing, or override already present)"
fi

echo '== Fix 2: WebKitGTK screen corruption on Adreno a3xx =='
# This SoC's a3xx GPU driver has no IOMMU (dmesg: "no IOMMU, fallback
# to VRAM carveout" / "No memory protection without IOMMU"). The
# device's own adreno-a330-quirks.sh already forces GSK_RENDERER=cairo
# for GTK4, but WebKitGTK's accelerated DMA-BUF compositor is a
# separate path and still hit the same bug, corrupting the screen in
# GNOME Web under rapid repaints (e.g. typing). Force WebKit to
# software-composite too.
QUIRKS=/etc/profile.d/adreno-a330-quirks.sh
if [ -f "$QUIRKS" ] && ! grep -q WEBKIT_DISABLE_DMABUF_RENDERER "$QUIRKS"; then
  sudo tee -a "$QUIRKS" >/dev/null <<'EOF'

# WebKitGTK's accelerated compositor also hits the missing-IOMMU
# DMA-BUF bug above; GSK_RENDERER=cairo does not cover it since it is
# a separate rendering path from GTK4/GSK.
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export WEBKIT_DISABLE_COMPOSITING_MODE=1
EOF
  echo "patched $QUIRKS (reboot required for this to take effect)"
else
  echo "skip (quirks file missing, or already patched)"
fi

echo '== Fix 3 (safety net): relocate large/growable dirs off a small root =='
# Only does anything if root is still tight on space (e.g. you kept
# pmbootstrap's default root size instead of sizing it generously at
# install time) and a large secondary storage partition is mounted.
# No-op otherwise.
ROOT_AVAIL_MB=$(df -m --output=avail / | tail -1 | tr -d ' ')
if [ "$ROOT_AVAIL_MB" -lt 500 ] && mountpoint -q /mnt/pmos-storage 2>/dev/null; then
  echo "root has only ${ROOT_AVAIL_MB}MiB free; relocating apk cache to /mnt/pmos-storage"
  sudo mkdir -p /mnt/pmos-storage/var-cache-apk
  sudo cp -a /var/cache/apk/. /mnt/pmos-storage/var-cache-apk/
  sudo diff -rq /var/cache/apk /mnt/pmos-storage/var-cache-apk
  if ! grep -q var-cache-apk /etc/fstab; then
    printf '%s\n' "/mnt/pmos-storage/var-cache-apk /var/cache/apk none bind 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
  sudo rm -rf /var/cache/apk/*
  sudo mount /var/cache/apk
  echo "done"
else
  echo "skip (root has ${ROOT_AVAIL_MB}MiB free, or no large storage partition mounted)"
fi

echo '== Fix 4: brightness slider + gsd-power startup delay =='
# (a) Phosh >= 0.5x drives the backlight itself (sysfs + logind
# SetBrightness); it no longer talks to gsd-power. For a "raw" backlight
# with max_brightness < 99 it takes the minimum level as 0 and then maps
# levels through log10(), so log10(0) = -inf and every slider position
# lands on level 0 (slider moves, screen goes to minimum). This panel
# (s6e3fa2: raw, max 59) hits exactly that. PHOSH_DEBUG=backlight-non-linear
# makes Phosh use the levels directly.
PROFILE=/etc/profile.d/phosh-backlight.sh
if [ ! -f "$PROFILE" ]; then
  sudo tee "$PROFILE" >/dev/null <<'EOF'
# Phosh maps backlight levels through log10(), but for a "raw" backlight
# with max_brightness < 99 it sets the minimum level to 0, so
# log10(0) = -inf and every slider position ends up at level 0. Use
# Phosh's linear level mapping instead.
case ",${PHOSH_DEBUG:-}," in
  *,backlight-non-linear,*) ;;
  *) export PHOSH_DEBUG="${PHOSH_DEBUG:+$PHOSH_DEBUG,}backlight-non-linear" ;;
esac
EOF
  sudo chmod 644 "$PROFILE"
  echo "installed $PROFILE"
else
  echo "skip ($PROFILE already present)"
fi

# (b) gsd-power never claims org.gnome.SettingsDaemon.Power on this SoC
# and its Initialization-phase timeout delayed session startup by about
# a minute. Disable its autostart via the standard XDG Hidden=true
# override. An earlier gsd-power replacement shim
# (phosh-brightness-bridge.py) turned out to be unused by Phosh and
# caused the same ~90 s Initialization-phase timeout itself, so it is no
# longer installed; hide its autostart if an old install left it behind.
mkdir -p "$HOME/.config/autostart"
GSD="$HOME/.config/autostart/org.gnome.SettingsDaemon.Power.desktop"
if [ -f /etc/xdg/autostart/org.gnome.SettingsDaemon.Power.desktop ] && [ ! -f "$GSD" ]; then
  cat > "$GSD" <<'EOF'
[Desktop Entry]
Type=Application
Name=GNOME power management (disabled: fails on this SoC, delays session start)
Exec=/usr/libexec/gsd-power
Hidden=true
EOF
  echo "disabled gsd-power autostart"
else
  echo "skip (gsd-power autostart missing, or already overridden)"
fi
BRIDGE_AUTOSTART="$HOME/.config/autostart/phosh-brightness-bridge.desktop"
if [ -f "$BRIDGE_AUTOSTART" ] && ! grep -q '^Hidden=true' "$BRIDGE_AUTOSTART"; then
  echo 'Hidden=true' >> "$BRIDGE_AUTOSTART"
  echo "disabled leftover phosh-brightness-bridge autostart"
fi

echo
echo 'Done. Reboot for the WebKit/OSK/brightness environment changes to take effect.'
