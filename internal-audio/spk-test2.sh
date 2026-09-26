# Loudspeaker with Samsung klte mixer_paths "speaker" values; dump SPKR regs.
R=/sys/kernel/debug/regmap/217:a0:1:0/registers
L=$(head -1 $R | wc -c); rd() { dd if=$R bs=$L skip=$(($1)) count=1 2>/dev/null | tr -d '\n' | sed 's/.*: //'; }
dump() { s=""; for a in $(seq $((0x9df)) $((0x9ef))); do s="$s $(printf %x $a)=$(rd $a)"; done; echo "$1:$s"; }
route() { for kv in "$@"; do amixer -q -c0 cset name="${kv%=*}" "${kv#*=}" || echo "  no control: ${kv%=*}"; done; }
date +%H:%M:%S
route "SLIM RX1 MUX=AIF1_PB" "RX7 MIX1 INP1=RX1" "DAC1 Switch=1" "RX7 Digital Volume=79" "SPK DRV Volume=8" "COMP0 Switch=1" \
      "SLIMBUS_0_RX Audio Mixer MultiMedia1=1"
dump idle
timeout 8 speaker-test -D hw:0,0 -c2 -r48000 -t sine -f 440 > /tmp/st.log 2>&1 &
sleep 3; dump play1; sleep 2; dump play2; sleep 4
dump after
route "RX7 MIX1 INP1=ZERO" "DAC1 Switch=0" "COMP0 Switch=0" "SLIM RX1 MUX=ZERO" "SLIMBUS_0_RX Audio Mixer MultiMedia1=0"
dmesg | tail -40 | grep -v 'SB xfer' | grep -vE '^\[[ 0-9.]+\] [0-9a-f]{2} 00 0' | cut -c1-160 | tail -15
