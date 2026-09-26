echo '=== current kernel ==='
uname -r
apk info -v | grep -i linux-postmarketos
echo '=== apk update ==='
apk update
echo '=== upgradable packages ==='
apk list -u 2>/dev/null
echo '=== specifically kernel/firmware ==='
apk list -u 2>/dev/null | grep -iE 'linux-postmarketos|linux-firmware|mesa|phoc|phosh|webkit'
