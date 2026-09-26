# GPU lockups on r9 (IOMMU kernel) — 2026-09-23

Collected: `devcd2-232754.txt` (devcoredump of the 4434 s lockup),
`lockup-dmesg.txt` (all hangcheck blocks since boot). A collector
(`/mnt/pmos-storage/gpu-lockup/collect.sh`, 2 s poll of
/sys/class/devcoredump, copies data + dmesg tail, then dismisses) is
running on the phone; it is not persistent across reboots.

## The five lockups (uptime s → offending task)

| t | task | IOMMU fault before it | rptr / wptr |
|---|---|---|---|
| 3940 | phoc | none | 80 / 130 |
| 3943 | Firefox Renderer | none | 64 / 64 |
| 3960 | phoc | none | 46 / 46 |
| 4257 | Firefox Renderer | none | 60 / 60 |
| 4434 | Firefox CanvasRenderer (WebGL aquarium) | `*** fault: iova=0, flags=0` at 4432 s, then MDP `pp done time out` x3 | 352 / 6112 |

(one more `*** fault: iova=2d80` right after the 4434 s recovery)
All recovered by hangcheck; session survived. Earlier (r6): GSK ngl →
phoc lockup, no fault.

## Ruled out

- Fault IRQ routing: qcom_iommu programs CBAR.IRPTNDX=1 for every bank,
  so both GPU contexts raise SPI 240+1 = 241, which is what the DT
  requests. (amami's "silent faults" were their own arm-smmu driver.)
  `no_afe` and `no_stall` are already set for the msm8974 GPU instance.
- Missing GPU rail vote: on msm8974 gfx3d is an RPM clock
  (downstream `DEFINE_CLK_RPM_SMD(gfx3d_clk_src, ... OXILI_ID)`, mainline
  rpmcc `gfx3d_clk_src`); the RPM scales VDD_GFX (PMA8084 S7) itself.
  Downstream's `vdd-gfx-supply` is only msm-thermal's floor vote.

## Open

- 4 of 5 lockups have no IOMMU fault, so the IOMMU is not proven to be
  the cause. Needed: A/B on the same kernel with GPU+MDP `iommus`
  deleted (carveout, as r4) under the same Firefox load.
- The iova-0 read: GPU fetch through a zero base address, harmless on
  the carveout (reads phys 0), a fault behind the SMMU, then a
  terminated transaction the a3xx does not survive?
- Decode `devcd2` with Mesa's `crashdec` (needs mesa freedreno tools
  built on the host) to see which IB/draw was executing.
- Performance: amami's 0036 (align IOVA to large pages) took their
  glxgears gap from 5.1x to 1.53x vs carveout; we still map in 4 KB
  pages.

## Crash-dump decode (2026-09-23 23:37)

- Mesa 26.2.3 `crashdec` built on WSL without sudo: `~/kbuild/mesa/mesa-26.2.3/build-fd/src/freedreno/decode/crashdec`
  (deps unpacked from `apt download` into `~/kbuild/localroot`; env in
  `~/kbuild/mesa/env.sh`; lua/libarchive via meson wraps).
- devcd2 (the 4257 s lockup, Firefox Renderer) decoded → `devcd2-decoded.txt`:
  RBBM_STATUS HI_BUSY|CP_NRT_BUSY|HLSQ_BUSY|GPU_BUSY; CP inside
  IB1 0xa3f1000 (sz 0x48c) → IB2 0xcd58000 (sz 0x52e); CP_ME_NRT_ADDR
  0xa407008 / DATA 0x3f800000; CP_HW_FAULT=0, CP_PROTECT_STATUS=0,
  RBBM_AHB_ERROR_STATUS=0x9c. IB contents were NOT in the dump (BOs are
  only dumped with MSM_SUBMIT_BO_DUMP), so the draw can't be identified.
- `msm.rd_full` set to Y at runtime (resets on reboot) so the next
  devcoredump carries all submit BOs. Collector still running; dir made
  world-writable. No new lockup since (5 total at 4434 s).

## Side effect: Phosh input dead after the lockups

- ~5200 s: top bar and bottom home swipe stopped responding (in Firefox
  and on the Phosh home screen); apps still took touch. phosh answered
  D-Bus, screen not locked; with Firefox open phosh used ~24 % CPU,
  phoc ~14 % (idle: ~0). `mdp5_crtc_get_scanout_position: no encoder
  found for crtc 0` logged at 5267 s.
- Old phoc ignored SIGTERM → had to SIGKILL. Fresh session (greetd
  restart) fixed it — user confirmed. Likely phoc/phosh state left
  inconsistent by the GPU hang recoveries. Workaround: restart session
  (`rc-service greetd stop; kill -9 <phoc>; rc-service greetd zap; start`).
- Firefox created three profiles (default, default-release,
  default-release-1) because it was launched from SSH while a profile
  was locked; consolidate later.
