# Phosh dies after long uptime — 2026-09-27

## Symptom
After ~1.5 h uptime the session died (greetd `crashed`, no phoc/phosh). 26→27 Sep boot:
session closed 00:14:06 (uptime ~5850 s).

## Root cause: vmalloc exhaustion from a qcom-ngd-ctrl DMA leak (not RAM)
- From 5152 s: `vmalloc_node_range for size 12288 failed: Address range restricted to
  0xf0800000 - 0xff800000` in `dup_task_struct` → fork() fails (VMAP_STACK) → processes
  can't spawn, sleep-inhibitor respawn loop, session collapses. RAM/swap were fine.
- /proc/vmallocinfo: 20083 areas / 159 MiB from `dma_common_contiguous_remap` (of 240 MiB).
- `qcom_slim_ngd_init_dma()` does dma_alloc_coherent for rx+tx msgq on every runtime
  resume; `qcom_slim_ngd_exit_dma()` never frees them (upstream bug). Autosuspend 100 ms
  vs WCD9320 jack poll 500 ms (patch 0033, `WCD9320_JACK_POLL_MS`) → suspend/resume every
  poll → 2 buffers leaked per 0.51 s = matches 20083 in ~5150 s.
- Side effects once exhausted: BAM `Failed to allocate desc fifo`, SLIMbus -22/-12/-28,
  PulseAudio hw_params "Out of memory" spam, jack poll error spam every 0.5 s.

## Fixes
- Workaround (on phone, active): `/etc/local.d/slim-ngd-no-autosuspend.start` writes `on` to
  `qcom,slim-ngd.1/power/control` at boot. Verified after reboot: remap count 85 → 85 in 30 s.
  Remove it once the kernel fix is installed.
- Kernel fix: `msm8974-iommu-aport/0036-slimbus-qcom-ngd-free-the-message-queue-buffers-in-exit_dma.patch`
  (dry-run applies cleanly to ~/kbuild/linux-6.16.12-msm8974). Not yet added to pmaports
  APKBUILD / built. Upstream-worthy.

## r15 built, installed and runtime-tested (2026-09-27)

- WSL access worked with tool escalation. Located pmaports at
  `/home/hana/.local/var/pmbootstrap/cache_git/pmaports`, branch
  `msm8974-iommu-experiment`. Added 0036 to APKBUILD source, bumped pkgrel
  14 -> 15 and ran `pmbootstrap checksum linux-postmarketos-qcom-msm8974`.
- Built successfully with pmbootstrap 3.11.1, using WSL root and its
  supported `--as-root` option with hana's explicit config. Git trust was
  scoped to this pmaports directory for the command only. No sudoers or
  global Git configuration changes. Commit: `e1bf3a7`.
- Package: `../kernel-pkgs/linux-postmarketos-qcom-msm8974-6.16.12-r15.apk`
  (17,701,479 bytes), SHA256
  `f571a5e856273c51a386408baf1f17dfbb14de3659244138fd032c659220293c`.
  Build log: `build-r15.log`; Windows aport copy is updated too.
- Installed r14 -> r15, mkinitfs/boot-deploy succeeded, rebooted.
  Running kernel verified as `6.16.12 #16-postmarketos-qcom-msm8974`;
  apk confirms `6.16.12-r15`. Phosh and ALSA S5 card came up.
- After verifying the new boot, backed up the workaround locally as
  `slim-ngd-no-autosuspend.start.backup`, removed the phone's
  `/etc/local.d/slim-ngd-no-autosuspend.start`, and set NGD power/control
  to `auto` for this running boot.
- 120.5 second test with codec jack polling and runtime PM enabled:
  five samples all had 9 dma_common_contiguous_remap mappings totaling
  2,412,544 bytes; runtime active time rose 30,717 ms and suspended time
  rose 89,846 ms. Thus runtime suspend/resume was exercised without the
  earlier monotonic leak (previously hundreds of mappings in this time).
  See `r15-runtime-soak.txt`. A later independent count was 13; active
  DMA mappings can vary with runtime power state.
- The test's original `pgrep -x phosh` returned empty despite a live
  Phosh PID3429. Separate ps and greetd checks confirmed the same phoc
  PID3026 / phosh PID3429 throughout. Monitor now reads /proc/*/comm.
  See `r15-auto-health.txt` and `r15-final-health.txt`.
- Final checks: workaround absent, power/control=auto, greetd started,
  headphone jack reads off (unplugged), no relevant vmalloc allocation,
  codec register read or SLIMbus buffer errors found. Listening to audio
  and a fresh plug/unplug cycle were not tested in this deployment.
- This verifies the short reproducer, not a new 1.5-hour soak. A separate
  reboot after workaround removal has not been done; the workaround file
  is absent and auto is already enabled at runtime.
- r14 APK remains available for rollback. No GitHub push was performed.

## Separate GPU-related session failure on r15 (2026-09-27 13:36)

User reported Phosh died while attempting to use Bluetooth. At uptime
2258.107s, kernel hangcheck reported a GPU lockup with offending task phoc;
at 13:36:37 GNOME session reported an unrecoverable required shell component
failure, then greetd's user session closed. No Phosh/phoc remained.
DMA remaps were still 9 at uptime ~40 minutes, with 1204 MiB memory available:
the earlier SLIMbus vmalloc leak did not recur in this observation.
Evidence: r15-recurrence.txt and r15-bluetooth-crash-recovery.txt.

Bluetooth had failed HCI Reset at boot (28s), and BlueZ had no default
controller. The GPU failure occurred much later. User interaction is a
possible trigger, but Bluetooth causing the GPU hang is not established.
GSK_RENDERER=cairo is already configured; prior Adreno/phoc hangs predate r15.

Recovered greetd with zap/start without reboot. phoc PID9247 and Phosh
PID9343 started. Reapplied the existing runtime HOST_WAKE GPIO75 workaround
using ../fm-radio/restore-bt-runtime.py; BlueZ Powered=yes. Eight-second
Bluetooth discovery found nearby devices, ended with Discovering=no, and
the same Phosh/phoc PIDs survived with no new GPU hang in dmesg. DMA remaps
remained 9. Evidence: r15-bt-restored.txt, r15-bt-scan-health.txt.

GPU crash remains unresolved; this was recovery, not a permanent GPU fix.
Bluetooth workaround remains runtime-only; r15 contains only the DMA leak
patch and does not include the prepared Bluetooth DT patch. Pairing and the
exact user UI sequence were not reproduced in this check.

## r15 (#16, built by the user with 0036) — leak FIXED (2026-09-27)
- Workaround script already gone from /etc/local.d. With NGD control=auto for 60 s the NGD
  runtime-suspended ~45 s of 60 (i.e. cycling), yet remap areas went 13 -> 9 (freed, no growth).
- First boot of r15 hung on the "maps: ... [vectors]" screen (same as r8/r9 hangs); a forced
  reboot booted fine. ramoops header errors → hung boot not captured. Still-open intermittent issue.
