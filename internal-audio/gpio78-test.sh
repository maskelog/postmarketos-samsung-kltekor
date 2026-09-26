# Test: is tlmm gpio78 the WCD9320 SYS_RST_N (Samsung klte gpiomux)?
# Hold gpio78 high via the GPIO v2 chardev (runtime only; released when the
# holder process exits), then reload the codec module.
grep -E '^ gpio(63|78) ' /sys/kernel/debug/gpio
cat > /tmp/hold78.py <<'PY'
import fcntl, os, struct, time, sys
# struct gpio_v2_line_request: offsets[64] u32, consumer[32], config
# (flags u64, num_attrs u32, padding[5] u32, attrs[10]*(id u32,pad u32,val u64, mask u64)),
# num_lines u32, event_buffer_size u32, padding[5] u32, fd s32
GPIO_V2_LINE_FLAG_OUTPUT = 1 << 3
GPIO_V2_LINE_ATTR_ID_OUTPUT_VALUES = 2
offsets = [78] + [0]*63
attrs = struct.pack('<IIQQ', GPIO_V2_LINE_ATTR_ID_OUTPUT_VALUES, 0, 1, 1) + b'\0'*24*9
config = struct.pack('<QI5I', GPIO_V2_LINE_FLAG_OUTPUT, 1, 0,0,0,0,0) + attrs
req = struct.pack('<64I', *offsets) + b'wcd-reset-test'.ljust(32, b'\0') + config + struct.pack('<II5Ii', 1, 0, 0,0,0,0,0, 0)
size = len(req)
IOC = (3 << 30) | (size << 16) | (0xB4 << 8) | 0x07   # _IOWR(0xB4, 0x07, gpio_v2_line_request)
fd = os.open('/dev/gpiochip0', os.O_RDONLY)
buf = bytearray(req)
fcntl.ioctl(fd, IOC, buf)
print('held gpio78 high, line fd', struct.unpack_from('<i', buf, size-4)[0], flush=True)
time.sleep(float(sys.argv[1]))
PY
python3 /tmp/hold78.py 40 &
sleep 2
grep -E '^ gpio78 ' /sys/kernel/debug/gpio
M=$(cat /proc/uptime | cut -d' ' -f1); echo "mark $M"
modprobe -r snd_soc_wcd9320; sleep 1; modprobe snd_soc_wcd9320; sleep 8
for d in /sys/bus/slimbus/devices/*; do echo "$(basename $d) driver=$(basename "$(readlink $d/driver 2>/dev/null)" 2>/dev/null)"; done
cat /proc/asound/cards
dmesg | awk -v m="$M" '{t=$0; sub(/^\[ */,"",t); sub(/\].*/,"",t); if (t+0 >= m+0) print}' | grep -v 'Modules linked in' | tail -40 | cut -c1-200
