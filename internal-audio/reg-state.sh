grep -E '^ *(s[0-9]+|l[0-9]+|lvs[0-9]|mvs[0-9]|5vs[0-9]) ' /sys/kernel/debug/regulator/regulator_summary
for r in /sys/class/regulator/*; do n=$(cat $r/name); printf '%s=%s ' "$n" "$(cat $r/state 2>/dev/null)"; done; echo
