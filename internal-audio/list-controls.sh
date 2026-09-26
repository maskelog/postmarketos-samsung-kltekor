amixer -c0 controls | grep -iE "RX7|SPK|EAR|LINEOUT|RX1 MIX|RX2 MIX|HPH|SLIM RX|DSM|SLIMBUS_0_RX Audio" | head -60
amixer -c0 cget name='RX7 MIX1 INP1' 2>&1 | tail -3
amixer -c0 cget name='SPK DRV Volume' 2>&1 | tail -3
