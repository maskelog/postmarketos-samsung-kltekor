uname -v; cat /proc/asound/cards | head -2
amixer -c0 cget iface=CARD,name='Headphone Jack' | sed -n 's/.*: values=//p'
dmesg | grep -iE 'headphone|jack|wcd9320-slim|msm8974-snd' | grep -v 'regmap-irq' | tail -8
R=/sys/kernel/debug/regmap/217:a0:1:0/registers; L=$(head -1 $R | wc -c)
for a in 0x94a 0x94b; do dd if=$R bs=$L skip=$(($a)) count=1 2>/dev/null | tr -d '\n'; echo; done
