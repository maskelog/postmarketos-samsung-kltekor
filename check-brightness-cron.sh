echo '=== user crontab ==='
crontab -l -u user 2>&1
echo '=== root crontab ==='
crontab -l -u root 2>&1
echo '=== /etc/crontabs ==='
ls -la /etc/crontabs/ 2>/dev/null
cat /etc/crontabs/user 2>/dev/null
cat /etc/crontabs/root 2>/dev/null
echo '=== cron service running? ==='
ps -ef 2>/dev/null | grep -i cron | grep -v grep
rc-status 2>/dev/null | grep -i cron
