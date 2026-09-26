export XDG_RUNTIME_DIR=/run/user/$(id -u)
pulseaudio -k; sleep 2; pulseaudio --start --log-target=syslog; sleep 4
pactl list cards | grep 'Active Profile'; pactl info | grep 'Default Sink'
date +%H:%M:%S
timeout 3 speaker-test -D pulse -c2 -t sine -f 660 >/dev/null 2>&1
echo '--- switch to headphones and back'
pactl set-card-profile alsa_card.platform-sound 'HiFi: Headphones' 2>&1 || pactl set-card-profile alsa_card.platform-sound 'HiFi (Headphones)' 2>&1
pactl list cards | grep 'Active Profile'
pactl list cards | sed -n '/Profiles:/,/Active/p' | head -8
