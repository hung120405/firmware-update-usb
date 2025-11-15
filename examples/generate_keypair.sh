#!/bin/bash
#
# Script to generate RSA key pair for firmware signing
# Run this once to create the private/public key pair
#
# Usage: ./generate_keypair.sh [key_size] [output_directory]
#
# Default: 2048-bit key, output to ./keys/

set -euo pipefail

KEY_SIZE=${1:-2048}
OUTPUT_DIR=${2:-./keys}

echo "Generating RSA key pair for firmware signing..."
echo "Key size: $KEY_SIZE bits"
echo "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Generate private key
echo "Generating private key..."
openssl genrsa -out "$OUTPUT_DIR/private_key.pem" "$KEY_SIZE"

# Generate public key from private key
echo "Generating public key..."
openssl rsa -in "$OUTPUT_DIR/private_key.pem" -pubout -out "$OUTPUT_DIR/public_key.pem"

# Set appropriate permissions
chmod 600 "$OUTPUT_DIR/private_key.pem"
chmod 644 "$OUTPUT_DIR/public_key.pem"

echo ""
echo "Key pair generated successfully!"
echo ""
echo "Private key: $OUTPUT_DIR/private_key.pem (KEEP SECRET - use for signing)"
echo "Public key:  $OUTPUT_DIR/public_key.pem (deploy to target device)"
echo ""
echo "IMPORTANT:"
echo "  - Keep the private key secure and never share it"
echo "  - Deploy public_key.pem to /etc/firmware-update/public_key.pem on target device"
echo "  - Use private_key.pem to sign firmware during build process"

