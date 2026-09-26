ls /usr/share/alsa/ucm2/Qualcomm/
ls /usr/share/alsa/ucm2/Qualcomm/msm8916 2>/dev/null
for f in /usr/share/alsa/ucm2/Qualcomm/msm8916/HiFi.conf /usr/share/alsa/ucm2/Qualcomm/msm8916/msm8916.conf; do echo "#### $f"; cat $f 2>/dev/null | head -120; done
ls /usr/share/alsa/ucm2/conf.d/ | head -80 | tr '\n' ' '
