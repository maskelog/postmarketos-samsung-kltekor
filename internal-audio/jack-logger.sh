# Log jack state + PulseAudio profile every 2 s for 120 s (background).
cat > /tmp/jacklog.sh <<'L'
export XDG_RUNTIME_DIR=/run/user/$(id -u)
end=$(( $(date +%s) + 180 ))
while [ $(date +%s) -lt $end ]; do
  j=$(amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p')
  p=$(pactl list cards | sed -n 's/.*Active Profile: //p')
  echo "$(date +%H:%M:%S) jack=$j profile=$p"
  sleep 2
done
L
rm -f /tmp/jacklog.txt; nohup sh /tmp/jacklog.sh > /tmp/jacklog.txt 2>&1 &
sleep 1; cat /tmp/jacklog.txt; date +%H:%M:%S
