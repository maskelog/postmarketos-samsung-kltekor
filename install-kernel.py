"""Upload a kernel apk to the phone, install it, verify, then reboot.

python install-kernel.py kernel-pkgs/linux-...-r10.apk [--no-reboot]
Prompts for the SSH password (also used for sudo). Output is saved to
install-kernel.last-result.txt.
"""
import getpass
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / '.diagnostic-tools'))
import paramiko

args = [a for a in sys.argv[1:] if not a.startswith('--')]
apk = pathlib.Path(args[0] if args else pathlib.Path(__file__).parent / 'kernel-pkgs' /
                   'linux-postmarketos-qcom-msm8974-6.16.12-r10.apk')
if not apk.is_file():
    sys.exit(f'apk not found: {apk}')
remote = '/tmp/' + apk.name
log = []


def out(text):
    log.append(text)
    print(text.encode('ascii', 'replace').decode('ascii'))


def run(client, password, cmd, root=False):
    full = f'sudo -S -p "" sh -c {cmd!r}' if root else cmd
    stdin, stdout, stderr = client.exec_command(full, timeout=600)
    if root:
        stdin.write(password + '\n')
        stdin.flush()
    stdin.channel.shutdown_write()
    text = stdout.read().decode('utf-8', 'replace') + stderr.read().decode('utf-8', 'replace')
    code = stdout.channel.recv_exit_status()
    out(f'$ {cmd}\n{text}[exit {code}]')
    return code, text


client = paramiko.SSHClient()
client.load_system_host_keys(str(pathlib.Path.home() / '.ssh' / 'known_hosts'))
import os
pw_file = os.environ.get('PW_FILE')
password = (pathlib.Path(pw_file).read_text(encoding='utf-8').strip()
            if pw_file else getpass.getpass('SSH password: '))
client.connect('192.168.1.144', username='user', password=password,
               look_for_keys=False, allow_agent=False, timeout=10)
try:
    run(client, password, 'uname -a; df -h / /boot; apk info -v linux-postmarketos-qcom-msm8974')
    sftp = client.open_sftp()
    sftp.put(str(apk), remote)
    sftp.close()
    out(f'uploaded {apk.name} ({apk.stat().st_size} bytes)')
    code, added = run(client, password, f'apk add --allow-untrusted {remote}', root=True)
    run(client, password, f'rm -f {remote}', root=True)
    _, info = run(client, password,
                  'apk info -v linux-postmarketos-qcom-msm8974; ls -la /boot; '
                  'ls /lib/modules/*/kernel/drivers/soc/qcom/apr.ko*; '
                  'dtc -I dtb -O dts /boot/dtbs/qcom-msm8974pro-samsung-klte.dtb 2>/dev/null | grep -c apr_audio_svc || true; df -h /')
    pkgver = apk.name.rsplit('-', 2)[-1].removesuffix('.apk')
    # apk info -v on the phone prints no version; trust apk add's own line
    ok = code == 0 and f'-{pkgver})' in added and 'boot-deploy completed' in added
    out('INSTALL OK' if ok else 'INSTALL NOT CONFIRMED - not rebooting')
    if ok and '--no-reboot' not in sys.argv:
        run(client, password, 'sync; (sleep 2; reboot) >/dev/null 2>&1 &', root=True)
        out('reboot scheduled')
finally:
    client.close()
    pathlib.Path(__file__).with_suffix('.last-result.txt').write_text('\n'.join(log), encoding='utf-8')
