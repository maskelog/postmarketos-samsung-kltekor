#!/bin/sh
set -eu
cd /mnt/d/code/active/postmarketos/internal-audio
mkdir -p source
tar -xzf /home/hana/.local/var/pmbootstrap/cache_distfiles/linux-v6.16.12-msm8974.tar.gz -C source \
 linux-6.16.12-msm8974/arch/arm/boot/dts/qcom/qcom-msm8974.dtsi \
 linux-6.16.12-msm8974/arch/arm/boot/dts/qcom/qcom-msm8974pro-samsung-klte.dts \
 linux-6.16.12-msm8974/arch/arm/boot/dts/qcom/qcom-msm8974pro-samsung-klte-common.dtsi \
 linux-6.16.12-msm8974/sound/soc/qcom/Kconfig \
 linux-6.16.12-msm8974/sound/soc/qcom/Makefile \
 linux-6.16.12-msm8974/sound/soc/codecs/Kconfig \
 linux-6.16.12-msm8974/sound/soc/codecs/Makefile \
 linux-6.16.12-msm8974/drivers/slimbus/Kconfig \
 linux-6.16.12-msm8974/drivers/soc/qcom/Kconfig
echo '=== ADSP DT ==='
grep -A65 -B8 'adsp' source/linux-6.16.12-msm8974/arch/arm/boot/dts/qcom/qcom-msm8974.dtsi
echo '=== AUDIO DRIVERS ==='
grep -nE '8974|WCD93|QDSP6|SLIM|APR' source/linux-6.16.12-msm8974/sound/soc/qcom/Kconfig source/linux-6.16.12-msm8974/sound/soc/codecs/Kconfig source/linux-6.16.12-msm8974/drivers/slimbus/Kconfig
echo '=== KLTE AUDIO CONNECTIONS ==='
grep -nE 'remoteproc_adsp|sound|audio|codec|slim|apr' source/linux-6.16.12-msm8974/arch/arm/boot/dts/qcom/qcom-msm8974pro-samsung-klte-common.dtsi || true
