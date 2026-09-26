# Enable the FSA8039 jack switch (pcal6416 @4-0020 pin 10 = Samsung gpio 310)
# for 240 s via the GPIO chardev, and log jack state meanwhile.
CHIP=$(for c in /sys/bus/gpio/devices/gpiochip*; do [ -e $c/of_node ] || true; n=$(basename $c); dev=$(readlink -f $c/..); case "$dev" in *4-0020*) echo $n;; esac; done | head -1)
echo "expander chip: $CHIP"
grep -A3 -E '4-0020' /sys/kernel/debug/gpio | head -5
cat > /tmp/holdline.py <<'PY'
import fcntl, os, struct, time, sys
chip, line, secs = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
offsets = [line] + [0]*63
attrs = struct.pack('<IIQQ', 2, 0, 1, 1) + b'\0'*24*9
config = struct.pack('<QI5I', 1 << 3, 1, 0,0,0,0,0) + attrs
req = struct.pack('<64I', *offsets) + b'fsa-en-test'.ljust(32, b'\0') + config + struct.pack('<II5Ii', 1, 0, 0,0,0,0,0, 0)
IOC = (3 << 30) | (len(req) << 16) | (0xB4 << 8) | 0x07
fd = os.open('/dev/' + chip, os.O_RDONLY); buf = bytearray(req); fcntl.ioctl(fd, IOC, buf)
print('holding', chip, line, 'high', flush=True); time.sleep(secs)
PY
nohup python3 /tmp/holdline.py $CHIP 10 240 > /tmp/hold.txt 2>&1 &
sleep 2; cat /tmp/hold.txt
grep -A12 -E '4-0020' /sys/kernel/debug/gpio | grep -E 'gpio-698|fsa' 
grep -E '^ gpio20:' /sys/kernel/debug/gpio
amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p'
cat > /tmp/jacklog.sh <<'L'
end=$(( $(date +%s) + 220 ))
while [ $(date +%s) -lt $end ]; do
  j=$(amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p')
  g=$(grep -E '^ gpio20:' /sys/kernel/debug/gpio | awk '{print $3}')
  p=$(XDG_RUNTIME_DIR=/run/user/10000 su user -c 'pactl list cards' 2>/dev/null | sed -n 's/.*Active Profile: //p')
  echo "$(date +%H:%M:%S) gpio20=$g jack=$j profile=$p"
  sleep 2
done
L
rm -f /tmp/jacklog.txt; nohup sh /tmp/jacklog.sh > /tmp/jacklog.txt 2>&1 &
sleep 1; cat /tmp/jacklog.txt; date +%H:%M:%S
