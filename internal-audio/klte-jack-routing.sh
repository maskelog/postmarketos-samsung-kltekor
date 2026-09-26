#!/bin/sh
# klte playback: callaudiod unloads PulseAudio jack routing on startup.
# Start it first, then restore routing for the separate UCM output profiles.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
gdbus call --session --dest org.mobian_project.CallAudio \
    --object-path /org/mobian_project/CallAudio \
    --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1 || exit 1
# Allow asynchronous PulseAudio initialization to finish; retry for 30 s.
i=0
while [ "$i" -lt 6 ]; do
    sleep 5
    modules=$(pactl list short modules) || exit 1
    if ! printf '%s\n' "$modules" | grep -q 'module-switch-on-port-available'; then
        pactl load-module module-switch-on-port-available || exit 1
    fi
    i=$((i + 1))
done
