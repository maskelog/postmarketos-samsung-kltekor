# Release hp-det (unbind the card), sample PMA8084 GPIO20 with an internal
# pull-up for 90 s, then rebind the card. FSA8039 enable is re-held too.
CHIP=$(for c in /sys/bus/gpio/devices/gpiochip*; do case "$(readlink -f $c/..)" in *pma8084*gpio*) basename $c;; esac; done | head -1)
echo "pmic gpio chip: $CHIP"
nohup python3 /tmp/holdline.py gpiochip3 10 200 > /tmp/hold.txt 2>&1 &
echo sound > /sys/bus/platform/drivers/msm8974-snd/unbind && echo unbound
cat > /tmp/sample.py <<'PY'
import fcntl, os, struct, time, sys
chip, line, secs = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
IN, PULL_UP = 1 << 2, 1 << 8
offsets = [line] + [0]*63
config = struct.pack('<QI5I', IN | PULL_UP, 0, 0,0,0,0,0) + b'\0'*24*10
req = struct.pack('<64I', *offsets) + b'hpdet-test'.ljust(32, b'\0') + config + struct.pack('<II5Ii', 1, 0, 0,0,0,0,0, 0)
IOC = (3 << 30) | (len(req) << 16) | (0xB4 << 8) | 0x07
fd = os.open('/dev/' + chip, os.O_RDONLY); buf = bytearray(req); fcntl.ioctl(fd, IOC, buf)
lfd = struct.unpack_from('<i', buf, len(req) - 4)[0]
GETV = (3 << 30) | (16 << 16) | (0xB4 << 8) | 0x0E   # GPIO_V2_LINE_GET_VALUES_IOCTL
prev = None; end = time.time() + secs
while time.time() < end:
    v = bytearray(struct.pack('<QQ', 0, 1)); fcntl.ioctl(lfd, GETV, v)
    val = struct.unpack('<QQ', v)[0] & 1
    if val != prev:
        print(time.strftime('%H:%M:%S'), 'gpio20 =', val, flush=True); prev = val
    time.sleep(0.5)
PY
nohup sh -c "python3 /tmp/sample.py $CHIP 19 90 > /tmp/sample.txt 2>&1; echo sound > /sys/bus/platform/drivers/msm8974-snd/bind; echo rebound >> /tmp/sample.txt" > /dev/null 2>&1 &
sleep 2; cat /tmp/sample.txt; date +%H:%M:%S
