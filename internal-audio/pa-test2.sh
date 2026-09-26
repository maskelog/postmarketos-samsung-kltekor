export XDG_RUNTIME_DIR=/run/user/$(id -u)
pactl set-card-profile alsa_card.platform-sound 'HiFi (Speaker)'; sleep 1
pactl list cards | grep 'Active Profile'; pactl list short sinks
date +%H:%M:%S; timeout 3 speaker-test -D pulse -c2 -t sine -f 660 2>&1 | head -4
logread 2>/dev/null | grep -i pulse | tail -8 | cut -c1-200
