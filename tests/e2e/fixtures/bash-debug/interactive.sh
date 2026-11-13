#!/usr/bin/env bash
printf '%s %s\n' "$$" "$PPID" > forge-interactive-pids
for ((i=1; i<=120; i++)); do
    printf 'FORGE_SCROLL_%03d\n' "$i"
done
printf 'FORGE_READY_TO_READ\n'
IFS= read -r -p 'FORGE_INPUT> ' reply
printf 'FORGE_ECHO:%s\n' "$reply"
printf 'FORGE_AFTER_READ\n'
