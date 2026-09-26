set -eu
stamp=$(date +%Y%m%d-%H%M%S)
backup="$HOME/.local/state/stevia-fix-$stamp"
mkdir -p "$backup" "$HOME/.config/autostart"
cp -p /usr/share/applications/sm.puri.OSK0.desktop "$backup/system-sm.puri.OSK0.desktop"
if [ -e "$HOME/.config/autostart/sm.puri.OSK0.desktop" ]; then
    cp -p "$HOME/.config/autostart/sm.puri.OSK0.desktop" "$backup/user-sm.puri.OSK0.desktop"
fi
python3 - <<'PY'
import ctypes
from pathlib import Path
lib = ctypes.CDLL('libglib-2.0.so.0')
lib.g_strsplit.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
lib.g_strsplit.restype = ctypes.POINTER(ctypes.c_char_p)
for name in ['mobi.phosh.Shell', 'sm.puri.OSK0']:
    text = Path('/usr/share/applications/'+name+'.desktop').read_text()
    value = next(s.split('=',1)[1] for s in text.splitlines() if s.startswith('X-GNOME-Provides='))
    result = lib.g_strsplit(value.encode(), b';', -1)
    tokens = []
    i = 0
    while result[i] is not None:
        tokens.append(result[i].decode())
        i += 1
    print(name, 'GNOME Session parser tokens:', repr(tokens))
src = Path('/usr/share/applications/sm.puri.OSK0.desktop').read_text()
lines = ['X-GNOME-Provides=inputmethod' if s.startswith('X-GNOME-Provides=') else s for s in src.splitlines()]
dst = Path.home()/'.config/autostart/sm.puri.OSK0.desktop'
dst.write_text('\n'.join(lines)+'\n')
print('Installed override:', dst)
PY
echo "BACKUP=$backup"
grep -E '^(Exec|OnlyShowIn|X-GNOME-Provides|X-GNOME-AutoRestart)=' "$HOME/.config/autostart/sm.puri.OSK0.desktop"
