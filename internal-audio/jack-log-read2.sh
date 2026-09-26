date +%H:%M:%S
awk '{k=$2" "$3" "$4" "$5" "$6; if (k!=prev) print; prev=k}' /tmp/jacklog.txt
grep -c . /tmp/jacklog.txt
grep -iE 'jack|gpio' /proc/interrupts | head
