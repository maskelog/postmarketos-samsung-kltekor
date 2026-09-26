# Galaxy S5 internal audio investigation — 2026-09-24

Status: **not repaired**. User clarified that the target is the built-in
speaker and 3.5 mm headphone output, not USB DAC. SSH diagnostics ran on
192.168.1.144 as user. No password is stored in these files. No remote
configuration, kernel, mixer, USB role, or firmware was changed.

## Confirmed on this phone

- Running Linux 6.16.12, build #10-postmarketos-qcom-msm8974 (r9).
- `/proc/asound/cards`: `--- no soundcards ---`; no PCM devices.
- PulseAudio 17.0 runs and exposes only the `auto_null` fallback sink.
- `CONFIG_SND=y`, `CONFIG_SND_SOC=y`, but `CONFIG_SND_SOC_QCOM`,
  `CONFIG_QCOM_APR`, and `CONFIG_SLIMBUS` are disabled. Related audio
  transport modules are not installed.
- ADSP starts successfully with `adsp.mdt`; remoteproc1 state is `running`.
- ADSP exposes RPMSG channels `apr`, `apr_apps2`, and `apr_audio_svc`.
  Thus DSP startup/firmware absence is not the immediate blocker.
- Live device tree has no sound-card, SLIMbus, codec, or APR node.
  Inspection uses `find -L` because `/proc/device-tree` is a symlink.
- No audio deferred-probe entry is present.

Full device evidence: `../diagnose-internal-audio.last-result.txt`.
Repeat: `python remote_diag.py diagnose-internal-audio.sh --root`
(prompts for password; diagnostic is read-only).

## Confirmed in the installed kernel's source base

The source archive is the existing local `linux-v6.16.12-msm8974.tar.gz`.
Relevant originals are extracted into `source/` by `inspect-kernel.sh`.

- `qcom-msm8974.dtsi` declares the ADSP with an SMD edge but no APR audio
  services or SLIMbus controller.
- The codec Kconfig/Makefile includes WCD9335 and newer codecs, but no
  WCD9320 implementation. Enabling a differently numbered codec is not a
  substitute.
- The Qualcomm ASoC Kconfig/Makefile has reusable QDSP6 components but no
  MSM8974/Galaxy S5 sound-card integration.

Enabling the three disabled config options alone cannot restore playback.
There is no existing WCD9320 module to load or reinstall in this build.

## External implementation check

- postmarketOS lists klte audio (WCD9320 plus Audience eS704) as broken:
  https://wiki.postmarketos.org/wiki/Samsung_Galaxy_S5_(samsung-klte)
- The same-SoC Lumia project contains experimental WCD9320/SLIMbus and
  QDSP6 work:
  https://github.com/KorelisLabs/lumia-1520-mainline
- Its main-branch audio handoff, inspected on 2026-09-24, describes a
  powered headphone DAC widget but explicitly leaves conversion, analog
  output, and audible sound unproven. It is development material, not a
  verified klte playback fix:
  https://github.com/KorelisLabs/lumia-1520-mainline/blob/main/docs/audio/HANDOFF.md

## Work required to reach a real repair

1. Integrate APR/QDSP6 services with the already working ADSP, and verify
   the firmware's supported AFE/ADM/ASM commands.
2. Port SLIMbus NGD/BAM and the codec's transport, reset, IRQ, clock, and
   supply descriptions using **Samsung klte** board sources. Lumia wiring
   and PM8941 regulator names cannot be copied onto this PMA8084 board.
3. Implement/port WCD9320 codec playback and the klte ASoC card routes,
   including board-specific amplifier/voice-processor dependencies.
4. Build and validate kernel/DT artifacts; then test real card registration,
   PCM playback, headphones and speaker independently, and suspend/resume.
5. Add mixer/UCM routing once a real ALSA card works.

No speculative driver or incomplete config-only change has been applied to
the working kernel package. The missing playback implementation remains the
blocker; restoring sound requires kernel driver development and physical
output validation, not an audio-service restart.

## APR probe (probe-apr.sh) — 2026-09-24

- First run (Codex, 13:00): apr_audio_svc bound temporarily to rpmsg_chrdev,
  `ADSP_GET_STATE` (0x1290c) sent, ADSP answered
  `61001c00 0304 0000 0305 0000 01004c4b 0d290100 01010004 01000000`
  = opcode 0x1290d, token matched, **ADSP_STATE=1 (ready)**. The decoder
  aborted because this firmware answers with **APR header v1**
  (hdr_field 0x61: 6 header words, one extension word 0x04000101) and the
  script only accepted v0. Channel binding was restored.
- Decoder fixed to accept v1 (verified offline on the captured bytes).
  Rerun to get GET_FWK_VERSION / GET_VERSIONS (service list: AFE/ASM/ADM
  ids and versions) — tells whether mainline q6afe/q6asm/q6adm (APR v2
  services) can talk to this firmware.
- Rerun (13:20, fixed decoder): ADSP_STATE=1; GET_FWK_VERSION (0x1292c)
  → basic response status 3 (ADSP_EUNSUPPORTED — old firmware; mainline
  q6core falls back to GET_VERSIONS). GET_VERSIONS → 11 services
  (id, version): core 3 (0x00040000), **AFE 4 (0x00200000)**, VSM 5
  (0x00070004), VPM 6 (0x00070005), **ASM 7 (0x00070002)**, **ADM 8
  (0x00070000)**, MVM 9, CVS 10, CVP 11 (0x00010000), USM 12, LSM 13.
  Binding restored; no playback command sent.
- Conclusion: the APR v2 service set that mainline qcom,apr-v2 + q6core/
  q6afe/q6asm/q6adm expect is present on channel `apr_audio_svc`. Lumia
  rm940 DT's `smd-edge { apr { compatible = "qcom,apr-v2"; ... } }` block is
  SoC-level (not board wiring) and can be reused for klte. Step 1 of the
  plan (APR/QDSP6) is feasible; codec (WCD9320 over SLIMbus NGD, Samsung
  dtsi uses `qcom,slim-ngd` @ fe12f000 with taiko PGD) remains the blocker
  for audible output.

## r10 — APR/QDSP6 (DSP side only), built from pmaports 4504e1b

- 0030 (klte DT only): `&remoteproc_adsp { smd-edge { apr (qcom,apr-v2,
  apr_audio_svc, APR_DOMAIN_ADSP) { q6core@3, q6afe@4 (+dais), q6asm@7
  (+dais MULTIMEDIA1/2), q6adm@8 (+routing) } } }`, modelled on msm8916.
  DTB compiled with host dtc; diff vs r9 = only this node.
- Config: QCOM_APR=m, SND_SOC_QCOM=m, SND_SOC_QDSP6=m (selected helpers
  via syncconfig; no other SND_SOC_QCOM options have defaults).
- Mainline apr_do_rx_callback accepts header ver<=1 and uses the header
  length field, so the firmware's v1 replies are fine.
- Expectation: q6core/q6afe/q6asm/q6adm probe, ASoC components appear,
  still `no soundcards`. Verify with `check-q6.sh` after flashing.
- **r10 flashed 2026-09-24 15:03 — step 1 PASSED** (`check-q6.last-result.txt`):
  kernel #11, apr_audio_svc bound to qcom,apr, services 4:3/4:4/4:7/4:8
  added, q6core/q6afe/q6afe_dai/q6asm/q6asm_dai/q6adm/q6routing loaded.
  ASoC components: q6asm dais (MultiMedia1/2), q6routing, q6afe dais
  (SLIMBUS_0..6 RX/TX, MI2S, TDM, HDMI, ...). No apr/q6 errors; ADSP
  running. Still `no soundcards` (expected). Deferred list = coresight
  only (pre-existing). Next: SLIMbus NGD + WCD9320 + klte machine card.

## Step 2 analysis — klte codec wiring vs. available ports (2026-09-24)

### Best base: Xperia Z2 (sirius) port, same SoC, same kernel 6.16
`references/sirius/` (RobLymm/xperia-sirius-linux @ 2e57ac2, GPL-2.0).
Headphone playback **heard** on hardware, handset mic records. Pieces:
- `drivers/audio/wcd9320/` — z3ntu's 5.11 WCD9320 driver forward-ported to
  6.16 (+ local regmap-slimbus shim, 5 crash fixes, HPH gain-source fix).
- `drivers/audio/msm8974-sndcard.c` — machine driver `qcom,msm8974-sndcard`.
- `drivers/clk/pmic-clkdiv/` — spmi clkdiv with DT-named outputs (the RPM
  already owns "div_clk1"), for the 9.6 MHz MCLK.
- `devicetree/...-sirius-codec.dts` — slimbam (bam-v1.4.0 @fe104000,
  controlled-remotely) + `qcom,slim-ngd-v1.5.0` @fe12f000 (mainline NGD,
  msm8996 path) + ifd/codec `slim217,a0` + clkdiv + pinctrl + dai links.
- `0001-ASoC-qdsp6-q6afe-send-both-LPAIF-clocks...` only matters for MI2S.
Lumia 1520 work (`references/lumia/`) never produced sound; not the base.

### klte wiring (Samsung LineageOS tree 5650d2bb, board dtsi k-r14)
- Codec on SLIMbus: taiko PGD ea `00 01 A0 00 17 02`, IFD `00 00 A0 00 17 02`.
- Reset: tlmm **gpio63** (currently out low = held in reset). IRQ: tlmm
  gpio72 (jack detect; skip for now).
- Supplies (msm8974pro-ac / sec dtsi): buck **pma8084_s5** 2.15 V,
  tx/rx/vddpx **pma8084_s4** 1.8 V, a-1p2v/cx **pma8084_l1** 1.225 V — all
  already defined in mainline klte dtsi with those voltages.
- MCLK 9.6 MHz on **PMA8084 GPIO15** func1 (DIVCLK1), vin-sel 2 (S4 1.8 V),
  CMOS, low drive. Divider peripheral address on PMA8084 not in Samsung DT
  (RPM-owned there); likely 0x5b00 like PM8941 — verify on device (read-only
  SPMI peripheral type) before use. Currently gpio15 = input, pull-down.
- Speaker: codec's own class-D (`cdc-vdd-spkdrv` = vph_pwr, no external amp,
  no amp GPIO). Earpiece: codec EAR PA. Headphones: HPHL/HPHR.
  **Sirius port has SPK PA / SPK DAC / VDD_SPKDRV as stubs** ("unimplemented")
  because the Z2 uses TFA9890 amps — must port these handlers from
  Samsung's wcd9320.c for the klte speaker.
- Mics: main = DMIC2, sub = DMIC4 (digital); sirius leaves
  `taiko_codec_enable_dmic` empty (Z2 has analogue mics only) → klte mics
  need DMIC support ported too. Headset mic = AMIC2 / MIC BIAS2.
- Audience eS705 (SLIMbus ea `00 01 83 00 BE 02`, reset on expander pin
  "300") is **not in the playback path**: Samsung's card links SLIMBUS_0_RX
  straight to taiko_rx1; eS705 only switches the main mic. Leave it off.
- Jack: sec_jack, detect PMA8084 GPIO20, micbias tlmm gpio85, sendend
  gpio77 (later).

### Order of work
1. Build sirius wcd9320 + sndcard + clkdiv into our tree (out-of-tree dirs
   become in-tree Kconfig entries); klte DT: slimbam, NGD v1.5.0, codec
   (PMA8084 supplies, gpio63), clkdiv + PMA8084 gpio15 pinctrl, sound card
   with SLIMBUS_0_RX → wcd9320 rx1. Target: **headphones** (proven path).
2. Port SPK DAC/PA handlers from Samsung wcd9320.c → loudspeaker.
3. EAR PA check → earpiece. 4. DMIC → mics. 5. UCM. 6. jack (REGMAP_IRQ).

### PMA8084 clock divider — verified 2026-09-24 15:54 (check-pma8084-clkdiv.sh)
SPMI regmap 0-00 (PMA8084 usid 0): 0x5b04/05 = 06/0b, 0x5c04/05 = 06/0b,
0x5d04/05 = 06/0b (type 0x06 clock, subtype 0x0b divider) — three dividers
at 0x5b00/0x5c00/0x5d00, same map as PM8941. Reference: 0xc004 = 0x10 (GPIO).
Divider 1 is **already enabled** (0x5b46 = 0x80) with DIV_CTL1 = 0x02 →
19.2 MHz / 2 = 9.6 MHz, i.e. set up by the bootloader/RPM. PMA8084 GPIO15 is
still a plain input, so the clock does not reach the codec yet; 0035's
pinctrl state (func1) is what connects it. usid 1 (0-01) has nothing there.

## r11 — WCD9320 headphone path (pmaports, patches 0031–0035)
0031 clkdiv names from DT (sirius), 0032 NGD late-registration (Lumia 0001),
0033 WCD9320 codec (sirius port), 0034 msm8974 machine driver (sirius),
0035 klte DT: slimbam, slim-ngd-v1.5.0, ifd+codec (PMA8084 S5/S4/L1,
gpio63), pma8084 clkdiv @5b00, GPIO15 func1 pinctrl, sound card
MM1/MM2 → q6routing → SLIMBUS_0_RX → wcd9320 rx1.
Config: SLIMBUS, SLIM_QCOM_NGD_CTRL, SPMI_PMIC_CLKDIV, SND_SOC_WCD9320,
SND_SOC_MSM8974 = m. DTB compiled locally; C not compile-tested yet (no
cross clang on host).

### r11 first boot (18:17) — codec does not enumerate
NGD up (live SSR AFTER_POWERUP, QMI 0x0301 v1 inst 0 node 5 port 3,
"SLIM controller Registered"), clkdiv1 9.6 MHz enabled, PMA8084 GPIO15 =
out func1 vin-2 (raw 0xce40 = 0x25: mode in/out, src func1, **invert set**
by `output-high`; Samsung has no invert), gpio63 out high, S4/S5/L1 on with
the codec as consumer. But 217:a0:0:0 / 1:0 log "Failed to get logical
address" 7× at 25.9–26.1 s and stay deferred; card waits on the codec DAI.
Suspect: probe re-toggles reset then the core asks for the LA immediately.
**Lesson:** do NOT read /sys/kernel/debug/regmap/0-00/registers — it reads
every SPMI address, the arbiter fails on unowned peripherals (0x808) and
floods WARNs (spmi-pmic-arb.c:321). Harmless reads, but it wipes dmesg.

### Codec enumeration debugging (2026-09-24 18:30–19:10, r11, runtime only)
Ruled out, with evidence:
- SLIMbus pins: tlmm gpio70/71 already `func1 8mA keeper` (slimbus) on r11
  (the func0 seen at 12:57 was r9, before any audio driver).
- NGD runtime PM: NGD child was `suspended` (autosuspend 100 ms); forced
  `on` → active; codec still absent 6–32 s later.
- Timing: the IFD (0:0) probe never touches reset and still fails after the
  codec had been powered/out of reset for minutes.
- Query result: kretprobe on qcom_slim_ngd_get_laddr → xfer ok (0.7 ms),
  get_laddr = **-6 (-ENXIO)**: the ADSP SLIMbus manager answers "no device
  with that EA". Bus messaging works; the codec never reported present.
- MCLK: PMA8084 GPIO15 STATUS1 (0xce08) sampled 24× reads 80/81 at random,
  same as the 32 kHz GPIO16 reference → the pin is toggling.
- Power: S5 2.15 V, S4 1.8 V, L1 1.225 V enabled with the codec as consumer;
  gpio63 out high. Sequence matches downstream wcd9xxx_slim_probe (supplies,
  reset low 20 ms / high 20 ms, then LA query; downstream retries 1 ms
  apart until SLIMBUS_PRESENT_TIMEOUT).
Open: gpio63 is the NFC pn547 firmware pin on board revs r03–r05 (r06+ move
it to expander 311) — if this unit is an early rev the reset line is
unknown. Next: find the board rev; check whether any SLIMbus device (e.g.
eS705 EA 00 01 83 00 BE 02) is present to separate "bus not clocking at the
pins" from "codec-specific".
Note: single PMIC registers can be read safely with
`dd if=/sys/kernel/debug/regmap/0-00/registers bs=9 skip=$((0xADDR)) count=1`.

### ROOT CAUSE FOUND (19:20): codec reset is tlmm **gpio78**, not gpio63
Samsung's `arch/arm/mach-msm/board-8974-sec-k-gpiomux.c` (msm_taiko_config):
`.gpio = 78 /* SYS_RST_N */` (out-low default) and `.gpio = 72 /* CDC_INT */`.
gpio63 on klte is the NFC firmware pin (r03–r05) / fingerprint BTP_LDO /
bat_id — the Samsung DT's `qcom,cdc-reset-gpio = <&msmgpio 63>` is just the
inherited Qualcomm reference value. gpio78 read `out low` (codec held in
reset). Holding gpio78 high from userspace (GPIO v2 chardev, /tmp/hold78.py,
gpio78-test.sh) and reloading snd_soc_wcd9320: both 217:a0 devices bind,
card `Samsung Galaxy S5` registers. hp-test.sh (route SLIM RX1/2 MUX=AIF1_PB,
RX1/2 MIX1 INP1=RX1/2, CLASS_H_DSM MUX=DSM_HPHL_RX1, HPHL DAC Switch=1,
HPHL/HPHR Volume=12, SLIMBUS_0_RX Audio Mixer MultiMedia1=1; speaker-test
hw:0,0 440 Hz): HPH PA status 0x9b3/0x9b9 **0x04 idle → 0x08 playing**, i.e.
the headphone path is driven (same pass criterion as the sirius port).
Also: HW_REV bits are tlmm gpio16/14/13/8 (all read high earlier).

## r12 (pmaports cc9e44d)
- 0035: reset-gpios = <&tlmm 78>.
- 0033: SPK PA (SPKR_DRV_EN bit7) + VDD_SPKDRV (open SPKR_DRV_DBG_PWRSTG
  0x24 while powered) ported from downstream taiko for the loudspeaker.
- r11 on the phone still toggles gpio63 (harmless so far) — r12 stops that.

## r12 installed 2026-09-24 20:36 — audio card comes up at boot
Kernel #13. gpio78 out high, gpio63 untouched (out low). Boot log: two
"Failed to get logical address" then `WCD9320 version 8 0, 1.0.2.1`,
card `Samsung Galaxy S5` registered automatically.
play-test.sh (speaker-test hw:0,0 440 Hz):
- Headphones: HPH PA status 0x9b3/0x9b9 04 → **08** while playing.
- Loudspeaker (RX7 MIX1 INP1=RX1, SPK DRV Volume=4): SPKR_DRV_EN 0x9df
  6f → **ef** (bit 7 = driver on) while playing; DBG_PWRSTG 0x9e7 = 00,
  gain 0x9e0 = 24. Whether sound is audible needs a human ear.
Mixer routes (codec side): SLIM RX1/RX2 MUX=AIF1_PB; headphones: RX1/RX2
MIX1 INP1=RX1/RX2, CLASS_H_DSM MUX=DSM_HPHL_RX1, HPHL DAC Switch=1,
HPHL/HPHR Volume; speaker: RX7 MIX1 INP1=RX1, SPK DRV Volume (0–8);
DSP side: SLIMBUS_0_RX Audio Mixer MultiMedia1=1.

### 23:13 — loudspeaker CONFIRMED audible (user) with Samsung klte values
mixer_paths.xml (LineageOS android_device_samsung_klte-common lineage-18.1,
`references/klte-common/audio/`): spk = SLIM RX1 MUX=AIF1_PB, RX7 MIX1
INP1=RX1, DAC1 Switch=1; speaker = + RX7 Digital Volume=79, SPK DRV Volume=8,
COMP0 Switch=1. Headset: HPHL/HPHR Volume=20, RX1/RX2 Digital Volume=77,
COMP1 Switch=1. Handset (rcv): RX1 MIX1 INP1=RX1, CLASS_H_DSM
MUX=DSM_HPHL_RX1, DAC1 Switch=1, EAR PA Gain=POS_3_DB, RX1 Digital Volume=84.
During the working speaker test: SPKR_DRV_EN 0x9df=ef, GAIN 0x9e0=00,
PWRSTG 0x9e7=00. (Earlier SPK DRV Volume=4 + COMP0 off: not heard.)
Codec is Taiko **2.0** (ID minor 0x0001).
Headphones confirmed audible by the user (r12, hp route above).

## UCM (23:15) — PulseAudio sees the card
Files in `internal-audio/ucm2/` (installed on the phone by
ucm-install.sh/ucm-update.sh, new files only):
`/usr/share/alsa/ucm2/Samsung/klte/{klte.conf,HiFi.conf}` and symlinks
`conf.d/{Samsung_Galaxy_,msm8974}/Samsung Galaxy S5.conf`. Card
driver_name is currently the truncated long name `Samsung_Galaxy_`
(msm8974.c doesn't set card->driver_name; setting it to "msm8974" later
makes the conf.d/msm8974 link the one used).
Verb HiFi: SLIMBUS_0_RX MM1 + SLIM RX1/RX2 = AIF1_PB. Devices (mutually
conflicting, same PCM): Speaker (prio 300; RX7 MIX1 INP1/INP2 = RX1/RX2,
RX7 Digital 79, SPK DRV 8, COMP0, DAC1), Headphones (200; Samsung headset
values), Earpiece (50). PulseAudio 17 makes one profile per device:
`HiFi (Speaker)` default, switch with
`pactl set-card-profile alsa_card.platform-sound 'HiFi (Headphones)'`.
No jack detection → no auto switch. PA logs the usual q6asm "woke us up ...
nothing to write" warning (harmless).
Not persistent across a clean reinstall yet — add to postinstall-fixes.sh.

## Jack detection (r13, 2026-09-24/25) — NOT working yet
r13 (pmaports 238b8e3): msm8974 card gets optional `hp-det-gpios` GPIO jack
("Headphone Jack" CARD control + input device) and driver_name "msm8974";
klte DT: hp-det-gpios = <&pma8084_gpios 20 GPIO_ACTIVE_LOW>, GPIO20 input,
no pull, S4 (Samsung "Headset Det", qpnp pull 5 = no pull).
Result: Samsung klte uses CONFIG_SAMSUNG_JACK=y (sec_jack, codec MBHC
disabled) with det = PMA8084 GPIO20 via an FSA8039 (DET out: 0 = plugged,
1 = unplugged; EN only switches MIC; fsa_en = expander pin 10 = Samsung 310,
pcal6416 gpio_start 300). On this phone GPIO20 reads **0 whether or not a
plug is inserted** — also with fsa_en held high and with a 30 µA internal
pull-up (card unbound, chardev sampling). A 90 s watch of every tlmm /
PMA8084 / expander line during plug-unplug-plug showed no jack-related
change (only gpio40 = SDC3 WLAN clock traffic). sec_jack uses no regulator
for the FSA8039. Unresolved: FSA8039 VDD / J_DET wiring; alternative is
the codec's MBHC (needs REGMAP_IRQ + MBHC port; Lumia got MBHC insertion
IRQs on gpio72).
UCM reverted to no JackControl, Speaker priority 300 (manual switching),
because the r13 jack control always reports "plugged".

## r14 (2026-09-25 00:37) — jack detection via codec MBHC comparator WORKS
pmaports 428e7bc. Codec: set_jack() writes MBHC_INSERT_DETECT = 0x6f and
polls MBHC_INSERT_DET_STATUS bit 2 every 500 ms; card hands its "Headphone
Jack" to the codec (hp-det-gpios dropped from the DT). dmesg:
`headphone inserted (insert status 0x0b)` / `removed (0x04)` on every
physical plug/unplug (130/138/143 s and 481/484 s after boot).
UCM: JackControl "Headphone Jack" on Headphones, priorities Headphones 200 >
Speaker 100. With a plug in, PA shows Headphones `available` and selected
`HiFi (Headphones)`. Unplug → Speaker switch not yet captured in a log.
Summary document: README.md in this directory.

## 2026-09-25: automatic jack routing restored

Live check: r14/build #15, MBHC 0x94a=0x6f, 0x94b=0x0b,
Headphone Jack=on and HiFi (Headphones) active with the plug connected.
Kernel detection was already functional. PulseAudio was missing
module-switch-on-port-available at runtime. Loaded it successfully as
module 25; module-switch-on-connect alone does not handle jack ports.

/etc/pulse/default.pa already loads module-switch-on-port-available before
module-udev-detect; no user default.pa exists. No persistent config edit
was needed. Why the module was absent at runtime is unknown.

User physically unplugged: Jack=off, Headphones unavailable, active
profile HiFi (Speaker), default sink HiFi__Speaker__sink. Automatic
switch on unplug is now VERIFIED. Replug verification is pending.
Evidence: jack-current.last-result.txt, jack-switch-fix.last-result.txt,
jack-unplug-verified.last-result.txt. No kernel changes were necessary.

Replug VERIFIED: user reinserted the plug; Jack=on, active profile
HiFi (Headphones), default sink HiFi__Headphones__sink. Both directions
of automatic routing now pass physical testing. Evidence:
jack-replug-verified.last-result.txt. Restart/reboot has not been tested.

## Reboot persistence fix (2026-09-25)
First reboot reproduced the missing module despite default.pa loading it.
Upstream callaudiod src/cad-pulse.c init_module_info() explicitly unloads
module-switch-on-port-available. Source saved in references/cad-pulse.c.
Installed user autostart klte-jack-routing.desktop and executable
~/.local/bin/klte-jack-routing (local copy: klte-jack-routing.sh).
It activates callaudiod over session D-Bus and restores the module if
missing every 5 seconds for the following 30 seconds, then exits.
This is a playback workaround for separate UCM output profiles; voice-call
routing is not validated. It runs at session startup, not continuously.
Early second-boot sample: Jack=off, Speaker active; session startup was
not yet complete. Evidence: jack-after-reboot-fix.last-result.txt.
No kernel change. To undo, remove the two user files; normal PulseAudio
startup configuration was not changed.

After session initialization completed, callaudiod was running and module
29 (module-switch-on-port-available) remained loaded after the helper
exited. Startup workaround VERIFIED. Jack=off and HiFi (Speaker) active;
physical plug state awaits user confirmation. Evidence:
jack-after-session-start.last-result.txt.

User confirmed headphone and speaker operation after reboot.
Publication 2026-09-26: raw device logs and reference caches omitted.
