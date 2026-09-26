cat > /tmp/proflog.sh <<'L'
end=$(( $(date +%s) + 300 ))
while [ $(date +%s) -lt $end ]; do
  j=$(amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p')
  p=$(su user -c 'XDG_RUNTIME_DIR=/run/user/10000 pactl list cards' 2>/dev/null | sed -n 's/.*Active Profile: //p')
  echo "$(date +%H:%M:%S) jack=$j profile=$p"
  sleep 1
done
L
rm -f /tmp/proflog.txt; nohup sh /tmp/proflog.sh > /tmp/proflog.txt 2>&1 &
sleep 2; cat /tmp/proflog.txt
