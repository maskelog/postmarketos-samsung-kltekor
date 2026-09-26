date +%H:%M:%S; cat /proc/uptime
dmesg | grep -iE 'headphone (inserted|removed)' | tail -10
amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p'
