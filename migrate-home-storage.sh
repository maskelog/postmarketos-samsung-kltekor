set -eu
storage=/mnt/pmos-storage
target=$storage/home-user-active
stamp=$(date +%Y%m%d-%H%M%S)
test "$(id -u)" = 0
test -d /home/user
test -f /home/user/.config/autostart/sm.puri.OSK0.desktop
test ! -e "$target"
findmnt -rn -M "$storage" -o SOURCE | grep -qx /dev/mmcblk0p26
test "$(blkid -s UUID -o value /dev/mmcblk0p26)" = 2da457f9-89dd-4287-89bb-89473c8983e8
test "$(df -Pk "$storage" | awk 'NR==2 {print $4}')" -gt 1048576
if findmnt -rn -M /home/user >/dev/null; then
    echo 'Home is already a mount point; stopping.' >&2
    exit 1
fi
cp -a /etc/fstab "/etc/fstab.before-home-storage-$stamp"
echo "FSTAB_BACKUP=/etc/fstab.before-home-storage-$stamp"
rc-service greetd stop
trap 'rc-service greetd start || true' EXIT
sleep 2
mkdir -m 700 "$target"
cp -a /home/user/. "$target/"
chown user:user "$target"
test -f "$target/.config/autostart/sm.puri.OSK0.desktop"
cmp /home/user/.config/dconf/user "$target/.config/dconf/user"
cmp /home/user/.config/autostart/sm.puri.OSK0.desktop "$target/.config/autostart/sm.puri.OSK0.desktop"
mount --bind "$target" /home/user
python3 - <<'PY'
from pathlib import Path
p = Path('/etc/fstab')
s = p.read_text()
assert not any(line.split()[1:2] == ['/home/user'] for line in s.splitlines() if line.strip() and not line.lstrip().startswith('#'))
s += '\n# User files and app data on the existing 26 GiB internal userdata partition\n/mnt/pmos-storage/home-user-active /home/user none bind 0 0\n'
p.write_text(s)
PY
su user -s /bin/sh -c 'testfile=$(mktemp /home/user/.storage-write-test.XXXXXX); printf "storage-write-ok\n" > "$testfile"; cat "$testfile"; rm "$testfile"'
findmnt -rn -M /home/user -o SOURCE,TARGET,FSTYPE,OPTIONS
df -h / /home/user /mnt/pmos-storage
rc-service greetd start
trap - EXIT
echo 'MIGRATION_COMPLETE'
