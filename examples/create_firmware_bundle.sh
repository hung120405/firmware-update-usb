#!/bin/bash
#
# Script to create firmware bundle (.bin file)
# This script packages firmware, manifest, and signature into a single bundle
#
# Usage: ./create_firmware_bundle.sh <firmware.img> <manifest.json> <signature.sig> <output.bin>

set -euo pipefail

if [ $# -ne 4 ]; then
    echo "Usage: $0 <firmware.img> <manifest.json> <signature.sig> <output.bin>"
    echo ""
    echo "Example:"
    echo "  $0 build/firmware.img build/manifest.json build/signature.sig firmware_bundle.bin"
    exit 1
fi

FIRMWARE_IMG="$1"
MANIFEST_JSON="$2"
SIGNATURE_SIG="$3"
OUTPUT_BIN="$4"

# Check if files exist
for file in "$FIRMWARE_IMG" "$MANIFEST_JSON" "$SIGNATURE_SIG"; do
    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        exit 1
    fi
done

echo "Creating firmware bundle..."
echo "Firmware: $FIRMWARE_IMG"
echo "Manifest: $MANIFEST_JSON"
echo "Signature: $SIGNATURE_SIG"
echo "Output: $OUTPUT_BIN"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy files to temp directory
cp "$FIRMWARE_IMG" "$TEMP_DIR/firmware.img"
cp "$MANIFEST_JSON" "$TEMP_DIR/manifest.json"
cp "$SIGNATURE_SIG" "$TEMP_DIR/signature.sig"

# Create tar archive (gzipped)
cd "$TEMP_DIR"
tar -czf "$OUTPUT_BIN" firmware.img manifest.json signature.sig

# Move to final location
mv "$OUTPUT_BIN" "$(dirname "$(realpath "$OUTPUT_BIN")")/"

echo ""
echo "Firmware bundle created successfully: $OUTPUT_BIN"
echo ""
echo "Bundle contents:"
tar -tzf "$OUTPUT_BIN" 2>/dev/null || echo "  - firmware.img"
echo "  - manifest.json"
echo "  - signature.sig"

