# Galaxy S5 postmarketOS keyboard diagnosis

Device: 192.168.1.144, samsung-klte, user account user.
Observed on 2026-09-22 (Asia/Seoul). No credentials are stored here.

## Confirmed findings

- postmarketOS edge, armv7, OpenRC; Phosh 0.55.0-r1, phoc 0.55.1-r1, Stevia 0.55.0-r0.
- Initially no phosh-osk-stevia, squeekboard, maliit, or ibus-daemon process was running.
- Session D-Bus NameHasOwner(sm.puri.OSK0) returned false.
- The session console contains: `phosh-osk-manager-WARNING: Unable to toggle OSK: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name sm.puri.OSK0 was not provided by any .service files`.
- org.gnome.desktop.a11y.applications screen-keyboard-enabled is true.
- org.gnome.desktop.input-sources sources is `[('xkb', 'us')]`.
- Installed Stevia layouts.json contains no Korean layout (kr/ko/hangul).
- IBus base packages exist, but ibus-hangul, libhangul, fcitx and UIM packages were not present in the installed package inventory. /usr/share/ibus/component contains dconf, gtkextension, gtkpanel and simple only.
- ldd resolved Stevia's shared-library dependencies.
- A bounded 12-second launch of Stevia inside the existing graphical D-Bus/Wayland session loaded English (US), configured a 360x200 OSK surface, acquired sm.puri.OSK0 and registered with GNOME SessionManager. It was then stopped by the diagnostic timeout. This verifies initialization, not end-to-end touch typing.
- The diagnostic run's log is on the phone at /tmp/stevia-diagnosis.log.
- Kernel log search found no Stevia/segfault/OOM-kill entry. This does not prove no historical crash occurred.

## Interpretation and limits

The immediate cause of the missing keyboard is the absent OSK process/service. The installed English keyboard can initialize when launched manually. Persistent startup/session integration needs investigation or repair; the exact reason the original session did not retain/start the OSK is not established by the available logs.

Korean input has a separate configuration/support gap: only English is selected, the installed Stevia layout list has no Korean entry, and no Hangul composition engine is installed. Simply relaunching the existing OSK will not supply Korean input.

The Phosh session lists sm.puri.OSK0 as a required component. The desktop launcher exists at /usr/share/applications/sm.puri.OSK0.desktop. Historical logs show this launcher was manually edited on June 8; this alone does not establish the cause. OpenRC's GNOME session falls back from systemd startup; the systemd warnings alone are not evidence of the failure.

## Changes during diagnosis

No persistent phone settings or packages were changed. Stevia was launched temporarily and stopped after the diagnostic interval. Its service was absent again at the end. Reboot/login persistence and actual touch typing were not tested.

## Next repair targets

1. Restore reliable Stevia startup in the user's graphical session and verify it survives login/reboot.
2. Select a verified Korean-capable OSK/composition integration for this armv7 Phosh environment, then test both English and composed Hangul in the intended applications.

## Follow-up: startup root cause and repair

The previously edited Stevia desktop file has `X-GNOME-Provides=sm.puri.OSK0;inputmethod;`. Phosh's shell has `X-GNOME-Provides=panel;windowmanager;`. GNOME Session 48 reads these with `g_desktop_app_info_get_string` and `g_strsplit(..., ";", -1)`, retaining a final empty string in each list. Its duplicate-provider check matches this empty string against the shell and discards the Stevia application. This is different from GLib's proper string-list API, which would omit the trailing empty item.

On-device reproduction using the actual libglib g_strsplit returned:

```
mobi.phosh.Shell: ['panel', 'windowmanager', '']
sm.puri.OSK0: ['sm.puri.OSK0', 'inputmethod', '']
```

Before repair, GNOME Session's App1 was the shell and App2 was absent. The repair installs a user override at `/home/user/.config/autostart/sm.puri.OSK0.desktop` with `X-GNOME-Provides=inputmethod` (no trailing separator). All other launcher fields are retained. On a new session, App2 is correctly registered as `sm.puri.OSK0.desktop`.

Original launcher copy: `/home/user/.local/state/stevia-fix-20260922-174509/system-sm.puri.OSK0.desktop`.

Primary source: GNOME Session 48.0, `gnome-session/gsm-autostart-app.c`, functions `gsm_autostart_app_get_provides` and `gsm_autostart_app_provides`; `gnome-session/gsm-manager.c`, `add_autostart_app_internal`.
https://github.com/GNOME/gnome-session/blob/48.0/gnome-session/gsm-autostart-app.c
https://github.com/GNOME/gnome-session/blob/48.0/gnome-session/gsm-manager.c

## Follow-up: internal storage

The existing ext4 userdata partition `/dev/mmcblk0p26`, UUID `2da457f9-89dd-4287-89bb-89473c8983e8`, was already mounted at `/mnt/pmos-storage`. It contains existing data, which was preserved.

The current home was copied with `cp -a` to `/mnt/pmos-storage/home-user-active`, then bind-mounted over `/home/user`. The original home remains underneath the bind mount as a rollback copy. Existing `/mnt/pmos-storage/user`, `media`, and `browser-storage-20260922` directories were preserved.

Added fstab entry:

```
/mnt/pmos-storage/home-user-active /home/user none bind 0 0
```

fstab backup: `/etc/fstab.before-home-storage-20260922-174634`.

Initial checks: home and destination have the same filesystem device number; normal user file creation, read and deletion succeeded. Capacity is approximately 25.8 GiB usable filesystem size, 23.5 GiB free. The system root remains approximately 1.8 GiB; this change expands home/user data capacity, not APK system-package space.

Rollback requires stopping the graphical session, retaining any new data written to the new home, removing the home bind entry from fstab and unmounting `/home/user`. Do not simply unmount a home with active applications. No formatting or repartitioning was performed.

## Final validation after reboot (17:52 KST)

- New boot ID: `46a9bf90-e04a-4a0a-b025-59fb3dbbc6da`; uptime approximately 2 minutes.
- `/home/user` automatically mounted from `/dev/mmcblk0p26[/home-user-active]`.
- Normal user file creation, read and deletion succeeded after reboot.
- Stevia PID 4781 was started by GNOME Session PID 3199, without a manual keyboard launch.
- `NameHasOwner(sm.puri.OSK0)` and `IsSessionRunning()` both returned true.
- Keyboard visibility was false at that instant, which is normal when the keyboard is hidden; before the reboot, the automatically started OSK had also reported Visible=true.
- There is a pre-existing GNOME SettingsDaemon.Power registration timeout delaying the session's Panel phase. Stevia appeared approximately two minutes into boot. This repair fixes its complete omission from startup, not that unrelated startup delay.
- Korean input engine/layout installation was not part of this repair and remains pending.

Raw final verification: `verify-after-reboot.last-result.txt` in the local workspace.
