#!/usr/bin/env bash
# Explicit optional test-stand preparation; never called by editor/startup.
set -euo pipefail
stand='/workspace/.tests/sdk selection'
mkdir -p "$stand"
export TEMP=/tmp TMP=/tmp TMPDIR=/tmp
export GOENV=off GOTOOLCHAIN=go1.23.3 GOSUMDB=sum.golang.org GOPROXY=https://proxy.golang.org
export GOMODCACHE="$stand/go-mod" GOPATH="$stand/go-home" GOCACHE="$stand/go-build" GOMAXPROCS=2
/opt/go/bin/go version
export RUSTUP_HOME="$stand/rustup" CARGO_HOME="$stand/cargo"
/opt/forge/cargo/bin/rustup toolchain install 1.91.1 --profile minimal --no-self-update
printf 'SDK stand ready: %s\n' "$stand"
