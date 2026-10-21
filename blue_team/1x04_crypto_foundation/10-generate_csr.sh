#!/bin/bash
# 10-generate_csr.sh
# Usage: ./10-generate_csr.sh <key_file> <csr_file> <common_name>
# Generates ECC P-256 key and CSR with SAN entries for MedDefense patient portal

set -e

KEY_FILE="$1"
CSR_FILE="$2"
CN="$3"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <key_file> <csr_file> <common_name>"
    exit 1
fi

# Generate ECC P-256 private key
openssl ecparam -genkey -name prime256v1 -out "$KEY_FILE"

# Generate CSR with SAN entries
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" \
-subj "/C=US/ST=California/L=San Francisco/O=MedDefense Health Systems/OU=Information Technology/CN=$CN" \
-addext "subjectAltName = DNS:$CN,DNS:www.$CN,DNS:portal.mobile.meddefense.local"

echo "CSR generated successfully: $CSR_FILE"
