set -eu
mkdir -p /mnt/pmos-storage/var-cache-apk
cp -a /var/cache/apk/. /mnt/pmos-storage/var-cache-apk/
echo "/mnt/pmos-storage/var-cache-apk /var/cache/apk none bind 0 0" >> /etc/fstab
# Reclaim root space: apk cache is just re-downloadable package files,
# unlike /home this copy is safe to delete from root once verified above.
diff -rq /var/cache/apk /mnt/pmos-storage/var-cache-apk
rm -rf /var/cache/apk/*
mount /var/cache/apk
echo '=== verify ==='
mount | grep 'on /var/cache/apk'
ls /var/cache/apk | wc -l
df -h /
echo '=== write test ==='
touch /var/cache/apk/.write-test && rm /var/cache/apk/.write-test && echo write-ok
