#!/usr/bin/env bash
# Trivial script under test: prints "hello, NAME" to stdout.
# Exits 2 with usage on stderr when no name is given.

set -u

shout=0
if [ "${1:-}" = "--shout" ]; then
    shout=1
    shift
fi

if [ $# -lt 1 ] || [ -z "$1" ]; then
    echo "usage: greet.sh [--shout] <name>" >&2
    exit 2
fi

if [ "$shout" = "1" ]; then
    name=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    echo "HELLO, ${name}!"
else
    echo "hello, $1"
fi
