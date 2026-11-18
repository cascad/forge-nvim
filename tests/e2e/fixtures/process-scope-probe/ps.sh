#!/bin/sh
# Native command boundary, только частный PATH тестового controller.
printf '%s\n' "$*" >> "$FORGE_PS_PROBE_CALLS"
case "$FORGE_PS_PROBE_CASE" in
  code)
    printf 'FORGE_PS_STDOUT\n'
    exit 17
    ;;
  signal)
    printf 'FORGE_PS_STDOUT\n'
    printf 'FORGE_PS_STDERR\n' >&2
    kill -KILL "$$"
    ;;
  real)
    exec "$FORGE_PS_PROBE_REAL" "$@"
    ;;
  *) exit 99 ;;
esac
