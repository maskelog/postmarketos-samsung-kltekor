# Current status (2026-09-26)

Speaker and headphones, jack detection, and automatic output switching were
confirmed working by the user after reboot. callaudiod unloads PulseAudio
module-switch-on-port-available at startup; klte-jack-routing.sh restores
it after callaudiod initialization through a user autostart entry.
See the root README for installation. Historical notes below retain earlier
observations; raw logs, source caches and reference clones are not published.

# Galaxy S5 (klte) internal audio on mainline — status and record

Last updated: 2026-09-25 00:50. Kernel on the phone: **r14**
(`linux-postmarketos-qcom-msm8974-6.16.12-r14`, build `#15`).
Chronological lab notes with every measurement: [`NOTES.md`](NOTES.md).

## Status

| Function | State | Evidence |
|---|---|---|
| ADSP / APR / QDSP6 (q6core, q6afe, q6asm, q6adm) | ✅ working | r10, all four services bind |
| SLIMbus NGD + WCD9320 codec enumeration | ✅ working | `WCD9320 version 8 0, 1.0.2.1` at boot |
| Sound card `Samsung Galaxy S5` (driver `msm8974`) | ✅ registers at boot | `/proc/asound/cards` |
| Headphones | ✅ heard by user | HPH PA status 0x04 → 0x08 while playing |
| Loudspeaker | ✅ heard by user | SPKR_DRV_EN 0x6f → 0xef while playing |
| PulseAudio / UCM (Speaker, Headphones, Earpiece) | ✅ working, manual switching confirmed by user | `pactl list cards` |
| Headphone plug detection | ✅ kernel detects insert/remove (r14) | `headphone inserted/removed` in dmesg |
| Automatic PulseAudio switching on plug/unplug | ⏳ plug→Headphones seen; unplug→Speaker not yet observed | profile log |
| Earpiece | ❓ routed in UCM, not verified by ear | |
| Microphones (DMIC2 main, DMIC4 sub, AMIC2 headset) | ❌ DMIC not implemented in the codec driver | |
| Headset buttons, headset-mic detection | ❌ needs full MBHC + interrupts | |
| eS705 (Audience voice processor) | not used (not in the playback path) | |

## Signal path

```
PulseAudio (UCM Samsung/klte HiFi)
 -> ALSA hw:0,0  MultiMedia1 (q6asm-dai)
 -> q6routing  "SLIMBUS_0_RX Audio Mixer MultiMedia1"
 -> q6afe SLIMBUS_0_RX  (ADSP, APR over SMD apr_audio_svc)
 -> LPASS SLIMbus (NGD fe12f000, BAM fe104000 controlled by the ADSP)
 -> WCD9320 "Taiko" 2.0: SLIM RX1/RX2 -> RX1/RX2 -> HPHL/HPHR (headphones)
                                        RX7 -> SPK DRV (loudspeaker, codec class-D)
                                        RX1 -> EAR PA (earpiece)
```

## klte hardware facts found (and where)

| Item | Value | Source |
|---|---|---|
| Codec reset `SYS_RST_N` | **tlmm gpio78** (NOT gpio63 of the Qualcomm reference DT) | Samsung `board-8974-sec-k-gpiomux.c` (msm_taiko_config) |
| Codec interrupt `CDC_INT` | tlmm gpio72 | same |
| Codec supplies | PMA8084 S5 2.15 V (buck), S4 1.8 V (tx/rx/io), L1 1.225 V | `msm8974pro-sec.dtsi` / `-ac.dtsi` |
| Codec MCLK 9.6 MHz | PMA8084 clock divider 1 (SPMI 0x5b00, type 06/0b, already enabled /2 by bootloader) out on **PMA8084 GPIO15 func1** | measured: regs + pin toggling |
| SLIMbus pins | tlmm gpio70/71 func1 (set by LPASS firmware at runtime) | measured |
| Speaker | WCD9320 internal class-D (SPK DRV), supply VPH_PWR, no external amp | Samsung DT / mixer_paths |
| Samsung jack detect | `CONFIG_SAMSUNG_JACK=y`: FSA8039 DET -> PMA8084 GPIO20, fsa_en = expander pin 10 (Samsung 310) | `sec_jack.c`, klte DT |
| GPIO20 on this unit | reads 0 whether or not a plug is in (also with fsa_en high and pull-up) → unusable | measured 2026-09-25 |
| Codec jack comparator | MBHC_INSERT_DETECT (0x94a in regmap) = 0x6f; MBHC_INSERT_DET_STATUS (0x94b) bit 2 clear = plugged (0x0b plugged / 0x04 empty) | measured, method from Lumia 1520 |
| HW_REV pins | tlmm gpio16/14/13/8 | Samsung gpiomux |
| Codec variant | Taiko 2.0 (ID minor 0x0001) | boot log |

## Kernel revisions (pmaports branch `msm8974-iommu-experiment`)

| Rev | pmaports commit | Change | Result |
|---|---|---|---|
| r10 | 4504e1b | 0030 klte DT: APR bus + q6core/afe/asm/adm; `QCOM_APR`, `SND_SOC_QCOM`, `SND_SOC_QDSP6` = m | DSP side up, no card |
| r11 | 5d28389 | 0031 clkdiv names from DT, 0032 NGD late-start fix, 0033 WCD9320 codec, 0034 msm8974 card, 0035 klte DT (SLIMbus, codec, clkdiv, GPIO15, card); `SLIMBUS`, `SLIM_QCOM_NGD_CTRL`, `SPMI_PMIC_CLKDIV`, `SND_SOC_WCD9320`, `SND_SOC_MSM8974` = m | codec never enumerated (reset on wrong gpio63) |
| r12 | cc9e44d | reset → gpio78; speaker PA/VDD_SPKDRV implemented | card at boot, headphones + speaker work |
| r13 | 238b8e3 | card `driver_name = "msm8974"`, GPIO jack on PMA8084 GPIO20 | jack stuck "plugged" (GPIO20 useless) |
| r14 | 428e7bc | jack handed to codec; codec polls MBHC insertion comparator every 500 ms; GPIO20 removed from DT | plug detection works |

Patch files 0030–0035 and the APKBUILD/config are also copied to
`../msm8974-iommu-aport/`. Built packages r9–r14 are in `../kernel-pkgs/`.

### Where the patch content comes from
- WCD9320 driver and `msm8974` machine driver: Xperia Z2 (sirius) mainline port,
  RobLymm/xperia-sirius-linux @2e57ac2 (GPL-2.0), itself z3ntu's
  flto-msm8974-5.11 driver forward-ported to 6.16. Copies in `references/sirius/`.
- NGD late-registration fix (0032): KorelisLabs/lumia-1520-mainline patch 0001.
- MBHC insertion setup (0x6f / status bit 2): Lumia 1520 `tools/wcd9320-mbhc-detect-evidence.sh`.
- Speaker PA handlers and all klte wiring: Samsung LineageOS kernel
  `android_kernel_samsung_msm8974` @5650d2bb (`references/samsung/`).
- Mixer values: LineageOS `android_device_samsung_klte-common` lineage-18.1
  `audio/mixer_paths.xml` (`references/klte-common/`).

## Userspace: UCM

Files in [`ucm2/`](ucm2/) — installed on the phone (new files only, nothing
package-owned replaced):
- `/usr/share/alsa/ucm2/Samsung/klte/klte.conf`, `HiFi.conf`
- symlinks `/usr/share/alsa/ucm2/conf.d/{msm8974,Samsung_Galaxy_}/Samsung Galaxy S5.conf`
  (the second one is only for the old r11/r12 driver name)

Verb `HiFi` routes MultiMedia1 → SLIMBUS_0_RX and SLIM RX1/RX2 = AIF1_PB.
Devices (mutually conflicting, same PCM `hw:0,0`):

| Device | Priority | Codec routing (values from Samsung mixer_paths) |
|---|---|---|
| Speaker | 100 | RX7 MIX1 INP1/INP2 = RX1/RX2, RX7 Digital Volume 79, SPK DRV Volume 8, COMP0 on, DAC1 on |
| Headphones | 200, `JackControl "Headphone Jack"` | RX1/RX2 MIX1 INP1, CLASS_H_DSM MUX = DSM_HPHL_RX1, RX1/RX2 Digital 77, HPHL/HPHR Volume 20, HPHL DAC on |
| Earpiece | 50 | RX1 MIX1 INP1 = RX1, CLASS_H_DSM MUX = DSM_HPHL_RX1, RX1 Digital 84, EAR PA Gain POS_3_DB, DAC1 on |

PulseAudio 17 turns these into card profiles `HiFi (Speaker)`,
`HiFi (Headphones)`, `HiFi (Earpiece)`. Manual switch:
`pactl set-card-profile alsa_card.platform-sound 'HiFi (Headphones)'`.

**Not persistent across a reinstall yet** — add the UCM install to
`../postinstall-fixes.sh`.

## How to reproduce / operate

- Build (needs sudo, run by the user): `~/.local/bin/pmbootstrap build linux-postmarketos-qcom-msm8974`
- Install + reboot: `python install-kernel.py kernel-pkgs\<apk>` (prompts for
  the SSH password; or `PW_FILE=<file>` env var). It verifies `apk add`'s
  upgrade line and `boot-deploy completed` before rebooting.
- Roll back: install an older apk from `kernel-pkgs\` the same way (r9 = no
  audio, r12 = audio without jack detection).
- Phone-side checks (run with `python remote_diag.py <script> --root`):
  `check-r14.sh` (card + jack), `play-test.sh` (headphone/speaker tones with
  PA register readback), `jack-dmesg.sh` (plug events).

## Debugging lessons (keep)

1. **Board wiring beats reference DTs.** Samsung's DT still carries Qualcomm's
   `cdc-reset-gpio = 63`; the real reset was in the board C gpiomux (gpio78).
   Diagnostic that found it: kretprobe on `qcom_slim_ngd_get_laddr` returned
   `-ENXIO` → the ADSP manager never saw the codec report present.
2. Hold a GPIO from userspace without libgpiod: GPIO v2 chardev ioctl from
   python (`/tmp/hold78.py`, `/tmp/holdline.py` in the scripts).
3. Read single PMIC/codec registers with
   `dd if=/sys/kernel/debug/regmap/<dev>/registers bs=<line len> skip=$((ADDR)) count=1`.
   **Never** read the whole SPMI `regmap/0-00/registers`: the arbiter fails on
   unowned peripherals and floods WARNs.
4. Jack controls live on `iface=CARD`, not MIXER (`amixer cget iface=CARD,name='Headphone Jack'`).
5. Busybox `diff` prints `-`/`+`, not `<`/`>`.
6. `CONFIG_SAMSUNG_JACK=y` means Samsung never used the codec MBHC — but the
   codec's insertion comparator is still wired and works on this unit.

## Open items

1. Confirm automatic PulseAudio switching on **unplug** (speaker takes over).
2. Persist UCM in `postinstall-fixes.sh`; upstream-quality cleanup of the
   patches (debug `printk`s in the WCD9320 port, file modes 0755).
3. Earpiece verification.
4. Microphones: implement `taiko_codec_enable_dmic` (klte main/sub mics are
   DMIC2/DMIC4) and a capture UCM.
5. Headset mic / buttons: full MBHC with `REGMAP_IRQ` on gpio72.
6. Remove the unused `hp-det-gpios` GPIO-jack path from the machine driver if
   no other board needs it (kept; harmless).
