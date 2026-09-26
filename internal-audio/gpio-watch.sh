# Watch every GPIO line (tlmm, PMA8084, expander) for changes for 90 s while
# the user plugs/unplugs the earphones. FSA8039 enable held high meanwhile.
nohup python3 /tmp/holdline.py gpiochip3 10 100 > /tmp/hold.txt 2>&1 &
cat > /tmp/gwatch.sh <<'W'
snap() { grep -E '^ gpio[0-9]+ *:|^ gpio-[0-9]+ ' /sys/kernel/debug/gpio | awk '{print $1, $2, $3, $4}'; }
snap > /tmp/g.prev; echo "$(date +%H:%M:%S) start"
end=$(( $(date +%s) + 90 ))
while [ $(date +%s) -lt $end ]; do
  snap > /tmp/g.cur
  if ! cmp -s /tmp/g.prev /tmp/g.cur; then echo "$(date +%H:%M:%S)"; diff /tmp/g.prev /tmp/g.cur | grep -E '^[-+] ?gpio'; cp /tmp/g.cur /tmp/g.prev; fi
  sleep 0.5
done
echo "$(date +%H:%M:%S) end"
W
rm -f /tmp/gwatch.txt; nohup sh /tmp/gwatch.sh > /tmp/gwatch.txt 2>&1 &
sleep 2; cat /tmp/gwatch.txt
