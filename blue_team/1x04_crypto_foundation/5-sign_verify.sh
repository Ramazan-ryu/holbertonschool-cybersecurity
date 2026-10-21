#!/bin/bash
set -e

# Usage:
# ./5-sign_verify.sh sign <file> <private_key>
# ./5-sign_verify.sh verify <file> <signature_file> <public_key>

MODE="$1"

if [ "$MODE" = "sign" ]; then
    if [ "$#" -ne 3 ]; then
        echo "Usage: $0 sign <file> <private_key>"
        exit 1
    fi
    FILE="$2"
    PRIVKEY="$3"
    SIGFILE="${FILE}.sig"

    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        exit 1
    fi
    if [ ! -f "$PRIVKEY" ]; then
        echo "Private key not found: $PRIVKEY"
        exit 1
    fi

    openssl dgst -sha256 -sign "$PRIVKEY" -out "$SIGFILE" "$FILE"
    echo "Signature created: $SIGFILE"

elif [ "$MODE" = "verify" ]; then
    if [ "$#" -ne 4 ]; then
        echo "Usage: $0 verify <file> <signature_file> <public_key>"
        exit 1
    fi
    FILE="$2"
    SIGFILE="$3"
    PUBKEY="$4"

    if [ ! -f "$FILE" ] || [ ! -f "$SIGFILE" ] || [ ! -f "$PUBKEY" ]; then
        echo "Missing file(s)"
        exit 1
    fi

    if openssl dgst -sha256 -verify "$PUBKEY" -signature "$SIGFILE" "$FILE"; then
        echo "SIGNATURE OK"
        exit 0
    else
        echo "SIGNATURE INVALID"
        exit 1
    fi

else
    echo "Invalid mode. Use 'sign' or 'verify'."
    exit 1
fi
