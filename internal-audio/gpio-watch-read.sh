date +%H:%M:%S
echo '--- change counts per line (excluding known clocks/buses) ---'
grep -E '^[-+] ?gpio' /tmp/gwatch.txt | grep -vE 'gpio(70|71|80) |gpio1[56]:' | sed 's/^[-+]//' | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
echo '--- timeline ---'
awk '/^[0-9][0-9]:/{t=$1; next} /^[-+]/{print t, $0}' /tmp/gwatch.txt | grep -vE 'gpio(70|71|80) |gpio1[56]:' | head -60
