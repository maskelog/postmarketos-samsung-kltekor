#!/bin/sh
# Temporary RPMSG binding; only ADSP state/version queries, no playback commands.
set -eu
python3 - <<'PY'
import os
import pathlib
import select
import signal
import struct
import time

channel = pathlib.Path('/sys/bus/rpmsg/devices/remoteproc1:smd-edge.apr_audio_svc.-1.-1')
driver = pathlib.Path('/sys/bus/rpmsg/drivers/rpmsg_chrdev')
header = struct.Struct('<HHBBHBBHII')
queries = [(0x1290c, 0x1290d, 'GET_STATE'),
           (0x1292c, 0x1292d, 'GET_FWK_VERSION'),
           (0x12905, 0x12906, 'GET_VERSIONS')]
fd = None
changed = False

def stop(signum, frame):
    raise TimeoutError('probe interrupted or overall timeout')

def decode(raw, token, command, response):
    if len(raw) < header.size:
        raise ValueError('short APR header')
    field, size, ss, sd, sp, ds, dd, dp, actual_token, opcode = header.unpack_from(raw)
    hsize = ((field >> 4) & 15) * 4
    # This ADSP answers with APR header v1 (one extra header word, 24 bytes).
    if (field & 15) > 1 or hsize < header.size or size != len(raw) or hsize > size:
        raise ValueError('invalid APR header sizes/version')
    if (ss, sd, ds, dd, sp, dp) != (3, 4, 3, 5, 0, 0) or actual_token != token:
        print('Ignoring unrelated APR packet', raw.hex(), flush=True)
        return False
    payload = raw[hsize:]
    if len(payload) % 4:
        raise ValueError('unaligned APR response')
    words = struct.unpack('<' + 'I' * (len(payload) // 4), payload)
    if opcode == 0x110e8:
        if len(words) != 2 or words[0] != command:
            raise ValueError('unexpected basic response')
        print('BASIC_RESPONSE command=0x%x status=%d' % words, flush=True)
        return True
    if opcode != response:
        print('Ignoring other opcode 0x%x' % opcode, flush=True)
        return False
    if opcode == 0x1290d:
        if len(words) != 1:
            raise ValueError('invalid state response')
        print('ADSP_STATE=%d' % words[0], flush=True)
    else:
        base, stride = (5, 3) if opcode == 0x1292d else (2, 2)
        if len(words) < base:
            raise ValueError('short version response')
        count = words[base - 1]
        if count > 64 or len(words) != base + count * stride:
            raise ValueError('invalid service count/response length')
        print('BUILD=%s SERVICES=%d' % (words[:base - 1], count), flush=True)
        for i in range(count):
            item = words[base + i * stride:base + (i + 1) * stride]
            print('SERVICE id=%d version=%s' % (item[0], item[1:]), flush=True)
    return True

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGALRM, stop)
signal.alarm(25)
try:
    if pathlib.Path('/sys/class/remoteproc/remoteproc1/name').read_text().strip() != 'adsp':
        raise RuntimeError('remoteproc1 is not the ADSP')
    if pathlib.Path('/sys/class/remoteproc/remoteproc1/state').read_text().strip() != 'running':
        raise RuntimeError('ADSP is not running')
    if not channel.is_dir() or not driver.is_dir() or (channel / 'driver').exists():
        raise RuntimeError('APR channel missing, driver unavailable, or channel already bound')
    old = (channel / 'driver_override').read_text().strip()
    if old not in ('', '(null)'):
        raise RuntimeError('channel has an existing driver override: ' + old)
    print('Binding idle apr_audio_svc to existing rpmsg_chrdev temporarily', flush=True)
    changed = True
    (channel / 'driver_override').write_text('rpmsg_chrdev\n')
    (driver / 'bind').write_text(channel.name + '\n')
    endpoints = list((channel / 'rpmsg').glob('rpmsg[0-9]*'))
    if len(endpoints) != 1:
        raise RuntimeError('expected one endpoint, got ' + repr(endpoints))
    node = pathlib.Path('/dev') / endpoints[0].name
    for _ in range(50):
        if node.exists():
            break
        time.sleep(0.02)
    fd = os.open(node, os.O_RDWR | os.O_NONBLOCK)
    for token, (opcode, response, label) in enumerate(queries, 0x4b4c0001):
        packet = header.pack(0x250, header.size, 3, 5, 0, 3, 4, 0, token, opcode)
        print('QUERY %s bytes=%s' % (label, packet.hex()), flush=True)
        if os.write(fd, packet) != len(packet):
            raise RuntimeError('short APR write')
        deadline = time.monotonic() + 3
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([fd], [], [], remaining)[0]:
                print('TIMEOUT ' + label, flush=True)
                break
            raw = os.read(fd, 4096)
            if not raw:
                raise RuntimeError('APR endpoint closed')
            print('RESPONSE ' + raw.hex(), flush=True)
            if decode(raw, token, opcode, response):
                break
finally:
    signal.alarm(0)
    if fd is not None:
        os.close(fd)
    if changed:
        try:
            if (channel / 'driver').exists():
                if (channel / 'driver').resolve() != driver.resolve():
                    raise RuntimeError('unexpected driver; refusing to unbind it')
                (driver / 'unbind').write_text(channel.name + '\n')
        finally:
            (channel / 'driver_override').write_text('\n')
        print('RESTORED bound=%s override=%s' % (
            (channel / 'driver').exists(),
            (channel / 'driver_override').read_text().strip()), flush=True)
PY
echo '=== FINAL ADSP / ALSA STATE ==='
cat /sys/class/remoteproc/remoteproc1/state /proc/asound/cards
dmesg | tail -15
