# Capture the return value of qcom_slim_ngd_get_laddr with a kretprobe
# (tracefs, runtime only), then reload the codec once.
T=/sys/kernel/tracing; [ -d $T/events ] || mount -t tracefs nodev $T
ls $T/kprobe_events >/dev/null 2>&1 || { echo 'no kprobe_events'; zcat /proc/config.gz | grep -E 'KPROBE|FTRACE=|DYNAMIC_FTRACE=' ; exit 0; }
echo 0 > $T/tracing_on; echo > $T/trace
echo 'r:ngdla qcom_slim_ngd_get_laddr ret=$retval:s32' > $T/kprobe_events 2>&1 || echo 'kprobe add failed'
echo 'p:ngdxfer qcom_slim_ngd_xfer_msg_sync' >> $T/kprobe_events 2>&1
echo 'r:ngdxferret qcom_slim_ngd_xfer_msg_sync ret=$retval:s32' >> $T/kprobe_events 2>&1
cat $T/kprobe_events
echo 1 > $T/events/kprobes/enable 2>&1; echo 1 > $T/tracing_on
modprobe -r snd_soc_wcd9320; sleep 1; modprobe snd_soc_wcd9320; sleep 4
echo 0 > $T/tracing_on
grep -v '^#' $T/trace | head -40
echo 0 > $T/events/kprobes/enable; echo > $T/kprobe_events
dmesg | tail -5 | cut -c1-160
