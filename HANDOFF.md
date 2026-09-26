# postmarketOS Galaxy S5 (klte) — Handoff

Device: `192.168.1.144`, SSH user `user`, device codename `samsung-klte`
(Snapdragon 801 / Adreno 330 / armv7). Password is NOT stored here —
re-enter it when a script needs it. Only the phone's SSH password is
needed for everything under "Phone-side work" below; the WSL sudo
password is separate and belongs to your WSL user.

This file exists so a fresh Claude Code session (e.g. running inside
WSL) has full context without re-deriving it. Read this whole file
before doing anything.

## Environment layout

- Windows project dir: `D:\code\active\postmarketos\` — from WSL this
  is `/mnt/d/code/active/postmarketos/`.
- SSH helper scripts (`remote_diag.py` prompts for the password
  interactively; `remote_diag_auto.py` reads it from a file path given
  as argv[2] — write the password to a throwaway file, use it, delete
  it afterward, never commit it):
  ```
  python remote_diag.py <script.sh> [--root]
  python remote_diag_auto.py <script.sh> <password-file> [--root]
  ```
  `--root` also feeds the same password to `sudo -S`. Both write
  `<script>.last-result.txt` next to the script, then print output —
  on Windows the print step can crash on non-ASCII output
  (`UnicodeEncodeError`, cp949 console); the result file is written
  *before* that print, so just read the `.last-result.txt` file
  instead of trusting the console output if it errors.
- `.diagnostic-tools/` — vendored paramiko/cryptography/etc. for the
  above scripts (Windows-side python deps, already set up).
- WSL: distro `Ubuntu-26.04` (user `hana`). `pmbootstrap` 3.9.0
  installed via `apt`. `pmbootstrap init` has **not** been run yet.

## What's already fixed on the phone (confirmed working, survives reboot)

All four are captured, in reproducible/idempotent form, in
`postinstall-fixes.sh` (item 4 revised 2026-09-23, see below) — run that once after any future clean
reinstall instead of redoing this manually.

1. **On-screen keyboard (phosh-osk-stevia) never autostarted.**
   Root cause: GNOME Session 48's `gsm-autostart-app.c` splits
   `X-GNOME-Provides` on `;` with `g_strsplit`, which keeps a
   trailing empty string; its duplicate-provider check then matches
   that empty string against Phosh shell's own trailing-empty entry
   and silently drops the Stevia launcher. Fix: user override at
   `~/.config/autostart/sm.puri.OSK0.desktop` with
   `X-GNOME-Provides=inputmethod` (no trailing `;`).

2. **GNOME Web (Epiphany) screen corruption while typing.**
   Root cause: this SoC's Adreno a3xx GPU driver has no IOMMU
   (`dmesg`: `no IOMMU, fallback to VRAM carveout` /
   `No memory protection without IOMMU`). The device already had
   `/etc/profile.d/adreno-a330-quirks.sh` forcing
   `GSK_RENDERER=cairo` for GTK4, but WebKitGTK's own accelerated
   DMA-BUF compositor is a separate path and hit the same bug. Fix:
   added `WEBKIT_DISABLE_DMABUF_RENDERER=1` and
   `WEBKIT_DISABLE_COMPOSITING_MODE=1` to that same quirks file.
   Confirmed fixed by the user typing in GNOME Web after reboot.

3. **Root partition (`/dev/loop0p2`, ~1.8G) kept running out of space.**
   Layout: root is a loop-mounted ext4 image occupying the *entire*
   `mmcblk0p23` "system" GPT partition (2430MiB, no adjacent free
   space — `p24` cache sits right after it). The large ~26GB
   `mmcblk0p26` "userdata" partition is already mounted at
   `/mnt/pmos-storage` and bind-mounted onto `/home/user`. Applied the
   same trick to `/var/cache/apk` (moved to
   `/mnt/pmos-storage/var-cache-apk`, bind-mounted back, fstab entry
   added, original deleted from root since apk cache is
   re-downloadable). This is a workaround, not a real fix — see
   "Root partition size" below for the actual options discussed.

4. **Brightness slider / session start delay — REVISED 2026-09-23.**
   The earlier fix here was wrong. Phosh 0.55 does NOT use gsd-power for
   brightness at all: it drives `/sys/class/backlight/panel` itself
   (src/backlight-sysfs.c, via logind `Session.SetBrightness`). The old
   `phosh-brightness-bridge.py` shim was never called by Phosh (its only
   logged Get calls came from our own verification), and its
   `X-GNOME-Autostart-Phase=Initialization` entry made gnome-session wait
   ~90 s for it (`'phosh-brightness-bridge.desktop' failed to register
   before timeout`) — the same delay we thought we'd removed.
   Real slider bug: Phosh takes min level = 0 for `type=raw` backlights
   with `max_brightness < 99`, then (unless scale is non-linear) maps
   through `log10()` → `log10(0) = -inf` → every slider position becomes
   level 0 ("slider moves, screen goes to minimum"). Panel driver
   s6e3fa2 registers raw / scale linear / max 59, so it hits this. Same
   code in Phosh main — worth an upstream bug report.
   Fix applied + confirmed by user: `/etc/profile.d/phosh-backlight.sh`
   exports `PHOSH_DEBUG=backlight-non-linear` (appended safely to any
   existing value); bridge autostart hidden (`Hidden=true`); gsd-power
   still hidden. Session start now ~16 s (was ~90 s). Slider verified:
   level follows it (e.g. 32/59). `postinstall-fixes.sh` Fix 4 rewritten
   accordingly (no longer installs the bridge). The bridge script is
   still at `/usr/local/bin/phosh-brightness-bridge.py` on the phone and
   `phosh-brightness-bridge.py` here, unused.

## `apk upgrade` status

- Kernel package `linux-postmarketos-qcom-msm8974-6.16.12-r4` is
  already the latest available in the repo — no kernel update
  pending in the ordinary sense.
- 655 other packages are upgradable (phosh 0.55→0.57, mesa
  26.1.1→26.2.3, etc.). Per user decision, **left this alone** except
  for a standalone `mesa`/`mesa-dri-gallium`/`mesa-egl`/`mesa-gbm`/
  `mesa-gl`/`mesa-gles` upgrade to 26.2.3-r0, which was simulated
  first (`apk add --simulate --upgrade ...`) and confirmed to only
  pull in `musl`, `libgcc`, `libffi`, `xz-libs`, `libexpat`,
  `libstdc++`, `llvm23-libs` (new, replacing `llvm22-libs`),
  `spirv-tools`, and `wayland-libs-client` — nothing touching
  phosh/phoc/webkit. Applied successfully. Root free space is tight
  (~164MiB after the apk-cache relocation above) — be careful with
  further upgrades without re-checking space.

## Root partition size — real options (not yet acted on)

GPT layout on `/dev/mmcblk0` (29.1GiB eMMC): the "system" partition
(`p23`, holds the root+boot loop image) is sandwiched with zero free
space between other partitions; only `p26` "userdata" (26.4GiB, mostly
empty) has real room. Options discussed with the user, in order of
soundness vs. effort:

1. **Reinstall with `pmbootstrap` using a properly-sized root from the
   start** (the actual fix — avoids needing storage workarounds at
   all). Needs PC + USB + fastboot/heimdall, full backup/restore.
2. **Move the entire root filesystem onto `p26`** without reinstalling,
   leaving only a minimal boot stub in the small `p23` image. Real
   structural fix but touches bootloader/initramfs — meaningfully
   higher brick risk than anything done so far if done wrong.
3. Reclaim the unused `p24` "cache" partition (200MiB) into `p23` by
   repartitioning live — small gain (+200MiB), real risk, not
   recommended (already discussed and deprioritized).
4. **What's actually been done**: bind-mount specific large/growable
   directories (`/home`, `/var/cache/apk`) onto `p26`. Safe, already
   applied twice, but doesn't address `/usr` (1.2GiB, the bulk of root
   usage) and isn't a systemic fix.

User's call so far: stick with option 4 for now; revisit option 1 when
there's time for a full backup+reinstall cycle.

## Current task: Adreno a3xx hardware acceleration (IN PROGRESS, risky)

**Context**: WebKitGTK/GNOME Web screen corruption (fixed above, see
item 2) was ultimately caused by this SoC's GPU driver having no
IOMMU. The user asked whether hardware acceleration can be restored
at all. Answer researched and given: not currently, but there is
upstream work in progress.

**The patch series**: Dmitry Baryshkov posted a 12-patch series adding
IOMMU/SMMU support for MSM8974 — covering "five SMMU instances, used
by display, GPU, Venus, VFE (camera) and JPEG encoder", initially
implementing MDP (display), GPU (Adreno a3xx), and Venus. Reference
provided by the user:
<https://lists.infradead.org/pipermail/linux-arm-kernel/2026-September/1171252.html>
(fetch via WebFetch or open directly for the full thread/patch IDs —
this handoff only has the summary, not the actual patch files/message-IDs
yet).

**Known status per that thread**: Luca Weiss tested on a Fairphone 2
(MSM8974**PRO** variant — klte is the *non-PRO* MSM8974, so there may
be additional variant-specific differences per Weiss's own comment in
the thread). Display (MDSS) boots fine with the patches, but running
`kmscube` (a GPU test app) with GPU IOMMU enabled **crashes/reboots
the device**. This is explicitly unfinished, unstable, upstream work —
not merged anywhere.

**Explicit user decision (already made, don't re-ask)**:
- This is being pursued as a **test/experiment**, risk accepted.
- Recovery path confirmed available: download mode / heimdall re-flash
  if a flashed kernel fails to boot.
- **Build only for now — do NOT flash this to the phone** without a
  separate, explicit go-ahead in a future turn. The phone is currently
  in a known-good, working state (all 4 fixes above verified after
  reboot); don't touch it for this experiment until asked.

**Status (2026-09-23 18:50): r6 FLASHED — display + GPU probe OK.**

- r5 (series only) booted but msm DRM failed: `failed to bind
  fdb00000.gpu (ops a3xx_ops): -16` → no /dev/dri, black screen (SSH ok).
  Cause: ARM32 `arch_setup_dma_ops` attaches its own dma_iommu_mapping
  domain, so msm's `iommu_attach_device()` gets -EBUSY. Same as Luca's
  first report.
- r6 adds `0022-drm-msm-detach-the-ARM-DMA-mapping-...` (patch 3/3 of
  `20260730-fix-qcom-smmu-v2-*`, picked for 7.3; hand-ported, only line
  positions differ). Patches 1–2 of that series are for msm_iommu.c
  (apq8064), not needed. Result: `[drm] Initialized msm ... minor 0`,
  GPU bound, a330 fw loaded, panel detected, Phosh session up, user
  confirmed screen displays normally. No iommu faults; the old
  "no IOMMU, fallback to VRAM carveout" message is gone.
- dmesg captures: `msm8974-iommu-aport/dmesg-r5-no-display.txt`,
  `dmesg-r6-display-ok.txt`. pmaports commit on the experiment branch.
- GPU load test (2026-09-23 ~19:00) PASSED, no reboot, no iommu faults:
  glmark2-es2-wayland full suite in Phosh (33 scenes, score 96, FD330,
  Mesa 26.2.3) and kmscube on bare KMS (smooth 60 s + rgba 45 s,
  59.6 fps) — i.e. Luca's FP2 crash did NOT reproduce on klte.
  Results: `msm8974-iommu-aport/{glmark-full.txt,kmscube.txt,dmesg.snap}`.
  Side findings: (a) fbcon can't draw on the IOMMU-backed fbdev
  (`fb0: sys_fillrect: framebuffer is not in virtual address space`,
  seen when greetd stopped) — tty text console likely broken/blank;
  (b) a few 3-jiffy RCU expedited stalls, also seen during apk install,
  probably unrelated; (c) `rc-service greetd stop` does NOT kill the
  running phoc session — it gets orphaned (killed manually after test).
  kmscube needs stdin kept open (`sleep N | kmscube -c FRAMES`), else it
  exits immediately with "user interrupted!".
- GNOME Web test (19:40–19:48), launched from SSH with env overrides
  only (quirks file /etc/profile.d/adreno-a330-quirks.sh NOT modified):
  - WEBKIT_DISABLE_DMABUF_RENDERER / _COMPOSITING_MODE removed,
    GSK_RENDERER=cairo kept: **no screen corruption while typing** (user
    confirmed) — original goal achieved. WebKitWebProcesses open
    renderD128 (GPU compositing active). Scrolling / page load still slow.
  - GSK_RENDERER=ngl additionally: ~25 s later **GPU lockup, offending
    task phoc** (`hangcheck detected gpu lockup rb 0`, no iommu fault),
    phoc died, greetd "crashed", screen blank; recovered with
    `rc-service greetd zap; rc-service greetd start`. Log:
    `msm8974-iommu-aport/dmesg-gsk-ngl-gpu-hang.txt`. → keep
    GSK_RENDERER=cairo (the quirk comment already warned ngl is
    crash-prone; not clearly IOMMU-related).
  - Epiphany aborted (SIGABRT) with a stale AT-SPI bus after the old
    session was killed; `GTK_A11Y=none` worked around it (reboot fixes).
- Slowness root causes found: CPU fixed at ~825–960 MHz (measured with
  perf cycles; max 2.46 GHz) — no cpufreq: qcom-cpufreq-nvmem supports
  msm8974 but the DT cpu nodes have no clocks/OPP and CONFIG_KRAITCC is
  off (pre-existing, separate kernel project). GPU devfreq init also fails
  (pre-existing since r4; GPU still runs at fast_rate when active).
  Memory tight (~270 MB available, kcompactd busy).
- Misc: /tmp is on the root fs (not tmpfs); crashed Epiphany runs leave
  ~10–17 MB `ContentRuleList-*` files there (cleaned). `perf` pulls
  ~140 MB of deps — installed for measurement, removed again.
- NOT yet tested: suspend/resume (patch 07 CB restore), long uptime.
  Quirks file still has all 3 vars; if keeping r6, the two WEBKIT_DISABLE
  lines can go (keep GSK_RENDERER=cairo). If rolling back to r4, all 3
  are needed again.
- Rollback: r4 is NOT in the repo (only r1). Backup of r4 /boot +
  /lib/modules/6.16.12 + boot.img in `/mnt/pmos-storage/rollback-r4/` on
  the phone and `rollback-r4/` here. Restore: untar both over / as root,
  then `apk` will still think r6 is installed — or `apk add` repo r1.
  Unbootable: lk2nd fastboot → `fastboot boot rollback-r4/boot-r4.img`.

(Previous build notes, still accurate:)

- Built package: `~/.local/var/pmbootstrap/packages/edge/armv7/linux-postmarketos-qcom-msm8974-6.16.12-r5.apk`
  (r5 so it sorts above the device's installed r4). Build clean, no
  warnings in qcom_iommu/arm-smmu. The final `sudo losetup` error in
  the log is only the post-build chroot zap timing out on sudo — harmless.
- Verified in the package: `CONFIG_QCOM_IOMMU=y`, `IOMMU_IO_PGTABLE_LPAE=y`,
  `ARMV7S=y`, `ARM_DMA_USE_IOMMU=y`; `qcom-msm8974pro-samsung-klte.dtb`
  contains enabled mdp/gpu/venus iommu nodes and `iommus` on MDP + GPU.
- **Correction to the note above**: klte's DTB is `qcom-msm8974pro-...`,
  i.e. the Galaxy S5 is MSM8974**PRO** (AC), same family as the
  Fairphone 2 where Luca Weiss saw kmscube crash/reboot the device.
  Expect the same failure mode.
- Tooling: apt pmbootstrap 3.9.0 is too old for current pmaports
  (min 3.11.0). Using git pmbootstrap 3.11.1 at `~/.local/bin/pmbootstrap`
  (`~/src/pmbootstrap`). Config written by hand to
  `~/.config/pmbootstrap_v3.cfg` (no `init` wizard); work dir
  `~/.local/var/pmbootstrap`. pmbootstrap needs sudo, which Claude's
  shell can't prompt for — the user runs build commands in their own
  terminal. Note: device-samsung-klte is now in `device/archived/`.
- pmaports: local branch `msm8974-iommu-experiment`, commit 5b11cfb.
  Backup copy of the whole aport: `msm8974-iommu-aport/` in this folder.
- Patch stack (21 files, on v6.16.12-msm8974):
  - 0001–0010: linux-next `qcom_iommu.c` fixes backported first (as
    Luca did): of_xlate leak, scoped OF loop, sysfs cleanup, inverted
    fault check, devm_pm_runtime_enable, pm_runtime return check,
    pgtbl_ops leak, publish pgtbl_ops under mutex, clocks in ctx_probe,
    dev_err cleanup. All applied clean.
  - 0011–0021: Baryshkov series v1 patches 02–12 (msgid
    `20260809-msm8974-iommu-upstream-v1-*-87f5cd492560@oss.qualcomm.com`,
    patchwork series 1142994; lore returns 403 to curl).
    Patch 01 (dt-binding YAML only) skipped — didn't apply, not needed
    for build. Patch 04 had one conflict (6.17 moved pgsize_bitmap to
    the domain); resolved by keeping 6.16's `qcom_iommu_ops.pgsize_bitmap`
    (4K|64K|1M|16M, identical to v7s sizes).
  - Dmitry's mmcc `GENPD_FLAG_NO_STAY_ON` fix NOT applied: it fixes
    commit 13a4b7fb6260 (6.17), which isn't in 6.16 (flag doesn't exist).

**Next steps**: flash only with explicit user go-ahead. Keep r4 around
for rollback (`apk add linux-postmarketos-qcom-msm8974=6.16.12-r4`, or
heimdall/download mode if it won't boot). Test display first, then
GPU (kmscube) over SSH with `dmesg -w`.


## Krait cpufreq (r7, 2026-09-23 20:25) — WORKING, 300–960 MHz

- Patches 0023–0026 = MahanHD/postmarketos-amami 0014/0015/0016/0022
  (msm8974 HFPLL data, Krait clock tree + OPP table, CPU thermal cooling
  maps, one cpufreq policy per Krait — the shared policy wedges cores
  when frequency switching and power collapse (cpu-spc) both run).
  0025 also needed `#include <dt-bindings/thermal/thermal.h>` in our
  tree. 0027 (ours): klte is fused **speed bin 3 / PVS 2 / v1**
  (qfprom0 @0xb0 = 9b8c000097032138); amami's table only allowed bins
  0–2 → no OPPs; widened opp-supported-hw to 0xf.
- Config: QCOM_HFPLL, KRAITCC, ARM_QCOM_CPUFREQ_NVMEM, CPU_THERMAL(+
  CPU_FREQ_THERMAL) =y; CPUFREQ_DT m→y. pmaports commit on the
  experiment branch; copies in `msm8974-iommu-aport/`.
- Verified: krait-cc probe "CPU0-3 @ 960000 KHz, L2 @ 729600 KHz";
  4 independent policies, 9 OPPs 300–960 MHz, conservative governor,
  cooling devices cpufreq-cpu0..3. 20-min burst soak with cpu-spc on:
  ~3000 transitions/core, 53.5k power collapses, 0 RCU (non-expedited)
  stalls, CPU 45–54 °C (log: `msm8974-iommu-aport/cpufreq-soak-r7.log`).
  A few expedited RCU stalls (≤34 jiffies) at ~919 s — also seen on r6
  without cpufreq, so likely unrelated.
- Earlier "825 MHz" perf measurement was wrong (forking busy loop); the
  cores were always at 960 MHz.
- Above 960 MHz: see `krait-research-downstream/NOTES.md`. Rail (PMA8084
  S8 gang, SPMI SID 1) is at 0.900 V, cores in pure BHS mode; this
  part's downstream table (speed3-pvs2-v1) allows **1344 MHz at 0.900 V**
  with no voltage change; full DVFS up to 2457.6 MHz @ 1.100 V would
  need qcom_spmi-regulator on S8 as cpu-supply (not attempted).


## Krait up to 1267.2 MHz (r9, 2026-09-23 22:05) — WORKING, installed

- User chose "stable voltage only": rail left at the bootloader's 0.900 V
  (not touched), ladder capped at 1267.2 MHz = 10 mV margin vs the
  downstream speed3-pvs2-v1 table (0.890 V). 0028: 4 OPPs 1036.8–1267.2
  MHz in the **klte dts only**, opp-supported-hw = bin 3 only (other PVS
  bins need more voltage — this is validated for PVS 2 only).
- r8 (0028 alone) hung once on its first boot (screen showed "ages",
  phone off the network); a battery pull booted it fine. Cause judged to
  be the missing CX vote: downstream (clock-krait-8974.c hfpll_fmax) has
  CPU HFPLLs vote CX SVS_SOC ≤998.4 MHz, NORMAL ≤1996.8 MHz; mainline
  Linux held no CX vote at all (cx perf_state 0). HFPLL config values
  (0x04D0405D, vco mask 0x100000, user 0x8, low_vco_max 1248 MHz) match
  downstream, so not the PLL setup.
- 0029: klte dts puts `power-domains = <&rpmpd MSM8974_VDDCX>;
  required-opps = <&rpmpd_opp_nom>;` on hfpll0-3 → genpd holds CX at
  NOMINAL (perf_state 4) from probe. Config: PSTORE, PSTORE_RAM,
  PSTORE_CONSOLE, PSTORE_PMSG =y (ramoops node already in klte dtsi;
  mount with `mount -t pstore pstore /sys/fs/pstore`).
- r9 results: 5/5 clean reboots (each spending ~20–30 s/core above
  960 MHz during boot, cx=4). Soak: 10 min all 4 cores pinned at 1267.2
  MHz under continuous load (max 70 °C, below the 75 °C passive trip),
  then 20 min bursty load with switching + cpu-spc: ~4000
  transitions/core, 0 RCU stalls. Log:
  `msm8974-iommu-aport/cpufreq-soak-r9-1267.log`.
- Recovery kit if a kernel ever fails to boot: phone enumerates as pmOS
  USB net (172.16.42.1) even when WiFi is down; Windows fastboot at
  `C:\Users\sh953\AppData\Local\Android\Sdk\platform-tools\fastboot.exe`
  (callable from WSL); `rollback-r4/boot-r7-recovery.img` = r7 kernel +
  r7 dtb + module-free initramfs, for `fastboot boot` (untested).
- Next (not started, needs explicit approval): real DVFS above 1267 MHz
  by driving PMA8084 S8 (SID 1) via qcom_spmi-regulator as cpu-supply.


## Firefox (2026-09-23 23:15) — installed, hardware WebRender confirmed

- `firefox-154.0-r0` (Alpine edge/community, armv7). Root had only ~276 MB
  free and the package is 240 MB, so `/usr/lib/firefox` is bind-mounted
  from `/mnt/pmos-storage/usr-lib-firefox` (fstab entry added) BEFORE
  install. Caveat: `/usr/lib/firefox` already held 3 files from
  `mobile-config-firefox` (defaults/pref/mobile-config-prefs.js,
  mobile-config-autoconfig.js, distribution/policies.json); the bind
  hid them, so they were copied into the storage dir. If that package
  updates, its files now land on storage (fine while the bind is up).
- Pulled partial upgrades: libflac, libsndfile, libvpx, ffmpeg-libavcodec,
  gst-plugins-good(-lang), pciutils-libs (new), and — not declared by apk
  but required (libxul: `PK11_CreatePrivateKeyFromTemplate` missing) —
  nss 3.124→3.128 + sqlite-libs 3.53.2→3.53.4.
- about:support (user-read): Compositing **WebRender** (not Software),
  WebGL renderer freedreno FD330, WebGL2 OpenGL ES 3.0 Mesa 26.2.3.
  Parent process holds renderD128. First EGL context attempt logs
  `Failed to create EGLContext!: 0x3009` then succeeds; shader probe for
  GL_EXT_shader_texture_lod fails harmlessly.
  **But**: ~6 min after launch (uptime 4257 s) one GPU lockup —
  `hangcheck detected gpu lockup rb 0 ... offending task: Renderer
  (/usr/lib/firefox/firefox about:support)` — GPU recovered, Firefox and
  phoc stayed up. Same family as the GSK_RENDERER=ngl → phoc lockup:
  a3xx/freedreno under GL-heavy compositors, no IOMMU fault logged.
  Fallback if it recurs: `gfx.webrender.software = true` in about:config
  (keeps WebRender, CPU rasterisation).
  Works on the r9 (IOMMU) kernel; on r4 (no IOMMU) hardware WebRender
  would likely hit the same corruption GNOME Web did.


### GPU lockup investigation (in progress)
See `gpu-lockup/NOTES.md`: 5 lockups (phoc x2, Firefox x3), only one
preceded by a GPU IOMMU fault (iova 0). crashdec built; msm.rd_full on
(runtime); dump collector running (not persistent). After the lockups the
Phosh session lost touch input on its own UI → fixed by a session restart.

## Password handling convention used throughout this session

Never left in a persisted file. Pattern: write to a throwaway file
under the session scratchpad (or equivalent temp location), pass its
path to `remote_diag_auto.py`, delete the file immediately after. If
you (the new session) need the phone's SSH password again, just ask
the user for it fresh.


## USB OTG DAC (2026-09-24) — NOT working yet

- Port is chipidea `ci_hdrc.0` (usb@f9a55000, dr_mode=otg) but DT has **no
  extcon** → OTG cable never switches it to host. Manual switch works:
  `echo host > /sys/devices/platform/soc/f9a55000.usb/ci_hdrc.0/role`
  (EHCI comes up, 1 port; `gadget` or reboot reverts, kills USB net).
  snd-usb-audio is =m and loads fine.
- **No VBUS from the phone** (no vbus-supply; OTG boost is on the Samsung
  charger/MUIC side, no mainline driver). DAC alone: nothing on the bus.
  With a charging OTG Y-cable, its built-in hub (214b:7250, 4 ports)
  enumerated once (uptime 731 s) but the DAC never appeared behind it and
  the hub disconnected after 25 s; a 90 s watch later saw nothing at all.
  D+/D- routing through the MUIC is evidently OK (hub enumerated).
- `watch-usb-plug.sh` (90 s enumeration watch, root hub autosuspend off),
  `usb-force-host.sh`, `check-usb-dac.sh`, `check-usb-host2.sh` here.
- Afterwards Phosh died, then a reboot hung on the "ags:" screen (same as
  r8's first-boot hang, now on r9); long-press reboot recovered. pstore of
  the hung boot only shows a normal boot to switch_root (quiet cmdline, no
  oops/panic at warning level) — cause unknown.

## Internal speaker / 3.5 mm audio (2026-09-24) — NOT repaired

User clarified the target is internal audio, not USB DAC. SSH read-only
diagnostics confirm no ALSA cards, PulseAudio auto_null only, and disabled
SND_SOC_QCOM/QCOM_APR/SLIMBUS. ADSP firmware boots successfully and exposes
APR RPMSG channels, but DT audio integration and WCD9320 codec support are
missing. No phone settings or kernel were modified. See
`internal-audio/NOTES.md` and `diagnose-internal-audio.last-result.txt` for
source evidence, experimental upstream status, and the driver work needed.
Update 13:20: `internal-audio/probe-apr.sh` (decoder fixed for APR header
v1) got ADSP_STATE=1 and the service list — AFE/ASM/ADM present, so
mainline qcom,apr-v2 + q6afe/q6asm/q6adm can work (Lumia DT apr block is
reusable). Codec/SLIMbus still missing. Details in internal-audio/NOTES.md.
- r10 (pmaports 4504e1b, patch 0030 + QCOM_APR/SND_SOC_QDSP6=m) installed
  and booted 15:03: APR + q6core/afe/asm/adm all bound cleanly, AFE exposes
  SLIMBUS_0..6 ports. No sound card yet (codec/SLIMbus next). r9 apk kept in
  `kernel-pkgs/` for rollback (`install-kernel.py kernel-pkgs\...-r9.apk`).

## Internal audio WORKING (2026-09-24, r12 + UCM)
Headphones and loudspeaker confirmed audible by the user. Root cause of the
long hunt: WCD9320 reset is tlmm **gpio78** on klte, not gpio63. r12 =
pmaports cc9e44d (patches 0030–0035: APR/q6, clkdiv names, NGD late start,
WCD9320 codec + speaker PA, msm8974 card, klte DT). UCM in
`internal-audio/ucm2/` installed on the phone; PulseAudio profiles
HiFi (Speaker/Headphones/Earpiece). Open: jack detection, mics (DMIC),
earpiece check, card driver_name, persisting UCM. Details:
`internal-audio/NOTES.md`.


## Internal audio — summary (2026-09-25, r14)
Full status table, hardware facts, revision history (r10–r14), UCM and
lessons: **`internal-audio/README.md`** (lab log: `internal-audio/NOTES.md`).
Speaker + headphones play (user-confirmed), PulseAudio profiles work,
kernel detects headphone insert/remove via the WCD9320 MBHC comparator.
Open: verify auto-switch on unplug, persist UCM, mics (DMIC), earpiece.
Phone SSH password was given in-chat on 2026-09-24; still not stored in any
file (throwaway `.pw.tmp` deleted after each run).
