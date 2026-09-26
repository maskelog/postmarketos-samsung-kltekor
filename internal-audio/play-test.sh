# r12: headphone then loudspeaker test tones; read codec PA registers.
R=/sys/kernel/debug/regmap/217:a0:1:0/registers
L=$(head -1 $R | wc -c); rd() { dd if=$R bs=$L skip=$(($1)) count=1 2>/dev/null | tr -d '\n'; }
route() { for kv in "$@"; do amixer -q -c0 cset name="${kv%=*}" "${kv#*=}" || echo "  no control: ${kv%=*}"; done; }
tone() { timeout $1 speaker-test -D hw:0,0 -c2 -r48000 -t sine -f 440 > /tmp/st.log 2>&1 & }
echo '=== headphones ==='
route "SLIM RX1 MUX=AIF1_PB" "SLIM RX2 MUX=AIF1_PB" "RX1 MIX1 INP1=RX1" "RX2 MIX1 INP1=RX2" \
      "CLASS_H_DSM MUX=DSM_HPHL_RX1" "HPHL DAC Switch=1" "HPHL Volume=12" "HPHR Volume=12" \
      "SLIMBUS_0_RX Audio Mixer MultiMedia1=1"
echo "idle:    $(rd 0x9b3) $(rd 0x9b9)"
tone 5; sleep 3; echo "playing: $(rd 0x9b3) $(rd 0x9b9)"; sleep 3
route "HPHL DAC Switch=0" "CLASS_H_DSM MUX=ZERO" "RX1 MIX1 INP1=ZERO" "RX2 MIX1 INP1=ZERO"
echo '=== loudspeaker ==='
route "RX7 MIX1 INP1=RX1" "SPK DRV Volume=4"
echo "idle:    en $(rd 0x9df) gain $(rd 0x9e0) pwrstg $(rd 0x9e7)"
tone 5; sleep 3; echo "playing: en $(rd 0x9df) gain $(rd 0x9e0) pwrstg $(rd 0x9e7)"; sleep 3
echo "after:   en $(rd 0x9df) pwrstg $(rd 0x9e7)"
route "RX7 MIX1 INP1=ZERO" "SLIM RX1 MUX=ZERO" "SLIM RX2 MUX=ZERO" "SLIMBUS_0_RX Audio Mixer MultiMedia1=0"
head -3 /tmp/st.log
dmesg | tail -20 | grep -v 'SB xfer' | cut -c1-160
