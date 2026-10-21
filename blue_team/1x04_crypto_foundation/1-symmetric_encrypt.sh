#!/bin/bash
set -e

INPUT="$1"
OUTPUT="$2"
MODE="$3"
PASSWORD="StrongPassword123"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_file> <output_file> <cbc|gcm>"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file does not exist"
    exit 1
fi

if [ "$MODE" = "cbc" ]; then

    openssl enc -aes-256-cbc \
    -in "$INPUT" \
    -out "$OUTPUT" \
    -salt \
    -pbkdf2 \
    -pass pass:"$PASSWORD"

elif [ "$MODE" = "gcm" ]; then

    openssl enc -aes-256-gcm \
    -in "$INPUT" \
    -out "$OUTPUT" \
    -salt \
    -pbkdf2 \
    -pass pass:"$PASSWORD"

else

    echo "Invalid mode"
    echo "Use: cbc or gcm"
    exit 1

fi

echo "Encryption completed"
