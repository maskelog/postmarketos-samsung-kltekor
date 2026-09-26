ps -o pid,user,args | grep -E 'pulse|pipewire|wireplumber' | grep -v grep
cat /proc/asound/card0/id; cat /sys/class/sound/card0/device/uevent 2>/dev/null | head -3
amixer -c0 info 2>/dev/null | head -5
ls /usr/share/alsa/ucm2/ | head; ls /usr/share/alsa/ucm2/conf.d | grep -iE 'msm|samsung|sdm|apq|qcom' | head
apk info -v 2>/dev/null | grep -E '^(alsa-ucm-conf|alsa-lib|pulseaudio|pipewire|wireplumber|alsa-utils)-[0-9]'
command -v alsaucm pactl
U=$(ps -o user,args | grep -E 'pulseaudio|pipewire' | grep -v grep | awk '{print $1}' | head -1); echo "server user: $U"
