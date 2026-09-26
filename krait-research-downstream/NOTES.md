# klte Krait DVFS research (2026-09-23)

All findings below are from read-only probes on the running phone (r6 kernel)
plus the downstream LineageOS `android_kernel_samsung_msm8974` (lineage-18.1)
sources saved in this directory.

## Chip identity (qfprom0 @ 0xb0 = `9b8c000097032138`)

- speed bin **3**, PVS **2**, PVS version **1** (both blow bits set).
- amami (Z1 Compact) is speed2/pvs4/v0 - different part, different table.
- The amami OPP table used `opp-supported-hw = <0x7>` (bins 0-2), which
  gives klte zero OPPs; widened to `0xf` in patch 0027.

## Where the CPU voltage comes from

- VDD_APC on MSM8974PRO-AC + PMA8084 is the **PMA8084 S8 gang**
  (leader ctl/ps/freq at 0x2900/0x2a00/0x2b00, followers S9/S10/S11),
  on **SPMI SID 1** (`/sys/kernel/debug/regmap/0-01`).
  Downstream: `msm8974pro-ac.dtsi` -> `&krait_regulator_pmic { qcom,ctl@2900 }`.
- Reading SID **0** (`0-00`) gives zeros for every SMPS - that is the wrong
  slave, not an access restriction. (amami's "PM8841 reads all zeroes" may be
  the same mistake; unverified.)
- SID1 readback: S8 type 0x1c / subtype 0x08 (FTS2), `V_CTL1(0x40)=0x00`,
  `V_CTL2(0x41)=0xb4` -> 180 x 5 mV = **0.900 V**, enabled. S9/S10/S11 also
  0xb4. Matches downstream `CORE_VOLTAGE_BOOTUP 900000`.
- All four cores are in **pure BHS mode**: `APC_PWR_GATE_CTL = 0x403f3f7f`
  (BHS_EN=1, all 6 segments on, LDO bypass + LDO power-down all set),
  `APC_PWR_GATE_MODE = 0`. So core voltage == rail voltage; the per-core
  LDOs are out of the picture.
- Downstream sets the rail through the L2 SAW (`msm_spm_set_vdd`, vlevel =
  uV / 5000) with a hard clamp 350000..1355000 uV. The L2 SAW is currently
  VCTL=0x00010003, PMIC_DATA_*=0 and is not programmed by mainline (no
  `-l2` entry in the spm driver), so L2 power collapse does not happen.

## Downstream frequency/voltage table for this part

`msm8974pro.dtsi`, `qcom,speed3-pvs2-bin-v1` (Hz, uV, uA):

| MHz | uV | | MHz | uV |
|---|---|---|---|---|
| 300-576 | 800000 | | 1497.6 | 920000 |
| 652.8 | 810000 | | 1574.4 | 930000 |
| 729.6 | 820000 | | 1651.2 | 945000 |
| 806.4 | 830000 | | 1728.0 | 960000 |
| 883.2 | 840000 | | 1804.8 | 975000 |
| 960.0 | 850000 | | 1881.6 | 990000 |
| 1036.8 | 860000 | | 1958.4 | 1005000 |
| 1113.6 | 870000 | | 2035.2 | 1020000 |
| 1190.4 | 880000 | | 2112.0 | 1035000 |
| 1267.2 | 890000 | | 2150.4 | 1050000 |
| **1344.0** | **900000** | | 2265.6 | 1065000 |
| 1420.8 | 910000 | | 2342.4 | 1080000 |
| | | | 2457.6 | 1100000 |

## Consequences

1. **Up to 1344 MHz needs no voltage change at all** on this chip: the rail
   already sits at 0.900 V, exactly the 1344 MHz requirement for
   speed3-pvs2-v1. This is only valid for this PVS; other klte units
   (different PVS) may need more at 1344 MHz.
2. Full DVFS (to 2457.6 MHz, 1.100 V) looks feasible with mainline's
   `qcom_spmi-regulator` (`qcom,pma8084-regulators`, s8 on SID1) as
   `cpu-supply`, opp-microvolt from the table above, regulator max clamped
   to ~1.1 V. Open questions before any write:
   - does RPM also vote on S8? (downstream does not list S8-S11 under RPM)
   - do the gang followers track a direct SPMI write to the leader's
     V_CTL2, or only SPM-issued writes?
   - spmi-regulator probe side effects (mode, pull-down, OCP) on S8.
   - retention / power-collapse interaction (SPM PMIC_DATA is 0).
