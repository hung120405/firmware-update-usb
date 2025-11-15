#!/bin/bash
#
# Script to create firmware signature during build process
# This script should be run on the build machine (not on target device)
#
# Usage: ./create_firmware_signature.sh <private_key.pem> <manifest.json> <output_signature.sig>

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 <private_key.pem> <manifest.json> <output_signature.sig>"
    echo ""
    echo "Example:"
    echo "  $0 build_keys/private_key.pem firmware/manifest.json firmware/signature.sig"
    exit 1
fi

PRIVATE_KEY="$1"
MANIFEST_FILE="$2"
SIGNATURE_FILE="$3"

# Check if files exist
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "Error: Private key file not found: $PRIVATE_KEY"
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "Creating signature for manifest.json..."
echo "Private key: $PRIVATE_KEY"
echo "Manifest: $MANIFEST_FILE"
echo "Output signature: $SIGNATURE_FILE"

# Create signature using SHA256
openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$SIGNATURE_FILE" "$MANIFEST_FILE"

if [ $? -eq 0 ]; then
    echo "Signature created successfully: $SIGNATURE_FILE"
    echo ""
    echo "You can verify the signature with:"
    echo "  openssl dgst -sha256 -verify <public_key.pem> -signature $SIGNATURE_FILE $MANIFEST_FILE"
else
    echo "Error: Failed to create signature"
    exit 1
fi

