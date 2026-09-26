import getpass
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / '.diagnostic-tools'))
import paramiko

client = paramiko.SSHClient()
client.load_system_host_keys(str(pathlib.Path.home() / '.ssh' / 'known_hosts'))
password = getpass.getpass('SSH password: ')
client.connect('192.168.1.144', username='user', password=password, look_for_keys=False, allow_agent=False, timeout=10)
script = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
command = 'sudo -S -p "" sh -s' if '--root' in sys.argv else 'sh -s'
stdin, stdout, stderr = client.exec_command(command, timeout=120)
if '--root' in sys.argv:
    stdin.write(password + '\n')
stdin.write(script)
stdin.channel.shutdown_write()
output = stdout.read().decode('utf-8', 'replace')
errors = stderr.read().decode('utf-8', 'replace')
pathlib.Path(sys.argv[1]).with_suffix('.last-result.txt').write_text(output + errors, encoding='utf-8')
print(output)
print(errors, file=sys.stderr)
code = stdout.channel.recv_exit_status()
client.close()
sys.exit(code)
