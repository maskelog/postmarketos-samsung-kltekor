# Headphone path test (klte): route MM1 -> SLIMBUS_0_RX -> WCD9320 HPH, play a
# 440 Hz tone, read the HPH PA status registers (0x04 idle, 0x08 driving).
grep -E '^ gpio78 ' /sys/kernel/debug/gpio
python3 /tmp/hold78.py 60 & sleep 1
grep -E '^ gpio78 ' /sys/kernel/debug/gpio
command -v amixer speaker-test aplay
cat /proc/asound/cards
route() { for kv in "$@"; do amixer -q -c0 cset name="${kv%=*}" "${kv#*=}" || echo "  no control: ${kv%=*}"; done; }
route "SLIM RX1 MUX=AIF1_PB" "SLIM RX2 MUX=AIF1_PB" "RX1 MIX1 INP1=RX1" "RX2 MIX1 INP1=RX2" \
      "CLASS_H_DSM MUX=DSM_HPHL_RX1" "HPHL DAC Switch=1" "HPHL Volume=12" "HPHR Volume=12" \
      "SLIMBUS_0_RX Audio Mixer MultiMedia1=1"
R=/sys/kernel/debug/regmap/217:a0:1:0/registers
L=$(head -1 $R | wc -c); rd() { dd if=$R bs=$L skip=$(($1)) count=1 2>/dev/null | tr -d '\n'; }
echo "idle: $(rd 0x9b3) $(rd 0x9b9)"
timeout 10 speaker-test -D hw:0,0 -c2 -r48000 -t sine -f 440 > /tmp/st.log 2>&1 &
sleep 4
echo "playing: $(rd 0x9b3) $(rd 0x9b9)  hph_l_gain $(rd 0x1ab 2>/dev/null)"
sleep 7
head -12 /tmp/st.log
dmesg | tail -15 | grep -v 'SB xfer' | cut -c1-200
