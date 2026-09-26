date +%H:%M:%S
awk '{k=$2" "$3" "$4" "$5; if (k!=prev) print; prev=k}' /tmp/jacklog.txt
amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p'
export XDG_RUNTIME_DIR=/run/user/$(id -u); pactl list cards | grep -E 'Active Profile|\[Out\] Headphones'
logread 2>/dev/null | grep -iE 'pulseaudio.*(port|profile|jack|switch)' | tail -8 | cut -c1-200
