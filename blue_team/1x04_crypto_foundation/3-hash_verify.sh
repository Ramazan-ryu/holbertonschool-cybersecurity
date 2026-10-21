#!/bin/bash
# 3-hash_verify.sh

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file> <expected_sha256>" >&2
    exit 1
fi

FILE="$1"
EXPECTED="$2"

if [ ! -f "$FILE" ]; then
    echo "INTEGRITY FAILED - file not found: $FILE" >&2
    exit 1
fi

ACTUAL=$(sha256sum "$FILE" | cut -d' ' -f1)

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "INTEGRITY OK"
    exit 0
else
    echo "INTEGRITY FAILED - expected $EXPECTED got $ACTUAL"
    exit 1
fi
