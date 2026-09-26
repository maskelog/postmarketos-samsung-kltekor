export XDG_RUNTIME_DIR=/run/user/$(id -u)
pactl info 2>&1 | grep -E 'Server Name|Default Sink'
pulseaudio -k; sleep 2
pulseaudio --start --log-target=syslog; sleep 4
pactl info 2>&1 | grep -E 'Server Name|Default Sink'
pactl list short sinks
pactl list cards 2>&1 | grep -E 'Name:|Active Profile|HiFi|Speaker|Headphones|Earpiece|available' | head -30
