#!/usr/bin/env bash
printf 'BASH_RUN %s\n' "${1:-default}"
printf 'BASH_STDERR\n' >&2
pwd >run-cwd.txt
exit "${2:-0}"
