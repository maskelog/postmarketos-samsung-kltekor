date +%H:%M:%S
awk '{k=$2" "$3" "$4" "$5; if (k!=prev) print; prev=k}' /tmp/proflog.txt
dmesg | grep -iE 'headphone (inserted|removed)' | tail -4
logread 2>/dev/null | grep -iE 'pulseaudio.*(profile|port|switch)' | tail -5 | cut -c1-180
