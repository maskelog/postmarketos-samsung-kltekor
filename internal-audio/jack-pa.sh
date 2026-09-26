amixer -c0 cget iface=CARD,name='Headphone Jack' 2>&1 | tail -2
export XDG_RUNTIME_DIR=/run/user/$(id -u)
pulseaudio -k; sleep 2; pulseaudio --start --log-target=syslog; sleep 5
pactl list cards | grep -E 'Active Profile|\[Out\]|available' | head -12
pactl info | grep 'Default Sink'
