#!/bin/sh
echo '=== SYSTEM ==='
date; uname -a; cat /proc/asound/cards; cat /proc/asound/pcm
echo '=== AUDIO KERNEL LOG ==='
dmesg | grep -iE 'snd|sound|audio|asoc|codec|wcd|slim|lpass|adsp|q6|apr|remoteproc|firmware' | tail -160
echo '=== AUDIO KERNEL CONFIG ==='
zcat /proc/config.gz | grep -E 'CONFIG_(SND=|SND_SOC=|SND_SOC_QCOM|SND_SOC_QDSP6|SND_SOC_WCD93|QCOM_APR|SLIM|QCOM_Q6|QCOM_ADSP|RPMSG_QCOM|REMOTEPROC=)'
echo '=== DT AUDIO NODES ==='
find -L /proc/device-tree -iname '*sound*' -o -iname '*audio*' -o -iname '*slim*' -o -iname '*adsp*' -o -iname '*codec*' -o -iname '*apr*'
echo '=== SMD/APR/SLIM DEVICES ==='
ls -l /sys/bus/rpmsg/devices /sys/bus/apr/devices /sys/bus/slimbus/devices 2>/dev/null
echo '=== AVAILABLE AUDIO MODULES ==='
find /lib/modules/"$(uname -r)" -type f | grep -iE 'slim|q6|apr|wcd|sound/soc/qcom'
echo '=== REMOTEPROC ==='
for d in /sys/class/remoteproc/*; do [ -d "$d" ] || continue; echo "$d"; cat "$d/name" "$d/state" "$d/firmware"; done
echo '=== DEFERRED PROBES ==='
cat /sys/kernel/debug/devices_deferred 2>/dev/null
echo '=== AUDIO PACKAGES ==='
apk info | grep -iE 'alsa|pulse|pipewire|wireplumber|firmware|linux-postmarketos|device-samsung'
echo '=== SESSION AUDIO ==='
ps -ef | grep -E 'pipewire|wireplumber|pulseaudio'
su user -c 'XDG_RUNTIME_DIR=/run/user/10000 pactl info; XDG_RUNTIME_DIR=/run/user/10000 pactl list short cards; XDG_RUNTIME_DIR=/run/user/10000 pactl list short sinks' 2>&1
echo '=== FIRMWARE ==='
find -L /lib/firmware -maxdepth 5 -type f | grep -iE 'adsp|q6|wcd|8974|klte' | head -60
