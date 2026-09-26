su user -c 'XDG_RUNTIME_DIR=/run/user/10000 pactl list cards' | grep -E 'Active Profile|\[Out\] (Headphones|Speaker)'
su user -c 'XDG_RUNTIME_DIR=/run/user/10000 pactl info' | grep 'Default Sink'
logread 2>/dev/null | grep pulseaudio | tail -12 | cut -c1-200
