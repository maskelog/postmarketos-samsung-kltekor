for c in 'RX7 Digital Volume' 'RX1 Digital Volume' 'SPK DRV Volume' 'COMP0 Switch' 'DAC1 Switch' 'HPHL Volume'; do echo "== $c"; amixer -c0 cget name="$c" 2>&1 | grep -E 'type=|: values|dBscale'; done
amixer -c0 controls | grep -iE 'COMP|DAC1|Digital Volume' | head -20
