#!/bin/bash
#
# Firmware Update Check Script
# This script is triggered by systemd service when USB is detected
# It validates and flashes firmware to the inactive partition (A/B partitioning)
#
# Author: Firmware Update System
# Version: 1.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ============================================================================
# Configuration Variables
# ============================================================================
USB_MOUNT_POINT="/media/usb_update"
FIRMWARE_BUNDLE_NAME="firmware_bundle.bin"
TEMP_EXTRACT_DIR="/tmp/fw_update_extract"
PUBLIC_KEY_PATH="/etc/firmware-update/public_key.pem"
CURRENT_HARDWARE_ID="my_device_v1"  # Should be read from device config
CURRENT_VERSION_FILE="/etc/firmware-version"
BOOT_PARTITION_A="/dev/mmcblk0p2"  # Adjust based on your partition layout
BOOT_PARTITION_B="/dev/mmcblk0p3"  # Adjust based on your partition layout
ACTIVE_PARTITION_FILE="/sys/firmware/devicetree/base/chosen/bootargs"  # Method to detect active partition
LOG_FILE="/var/log/firmware-update.log"

# ============================================================================
# Logging Functions
# ============================================================================
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_warn() {
    log "WARN" "$@"
}

# ============================================================================
# Cleanup Function
# ============================================================================
cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."
    
    # Unmount USB if mounted
    if mountpoint -q "$USB_MOUNT_POINT" 2>/dev/null; then
        umount "$USB_MOUNT_POINT" 2>/dev/null || log_warn "Failed to unmount $USB_MOUNT_POINT"
    fi
    
    # Remove temporary extraction directory
    if [ -d "$TEMP_EXTRACT_DIR" ]; then
        rm -rf "$TEMP_EXTRACT_DIR" || log_warn "Failed to remove $TEMP_EXTRACT_DIR"
    fi
    
    # Remove mount point if empty
    if [ -d "$USB_MOUNT_POINT" ] && [ -z "$(ls -A $USB_MOUNT_POINT 2>/dev/null)" ]; then
        rmdir "$USB_MOUNT_POINT" 2>/dev/null || true
    fi
    
    if [ $exit_code -ne 0 ]; then
        log_error "Script exited with error code: $exit_code"
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# ============================================================================
# Helper Functions
# ============================================================================

# Detect which partition is currently active (A or B)
detect_active_partition() {
    # Method 1: Check root filesystem
    local root_dev=$(findmnt -n -o SOURCE /)
    log_info "Root device: $root_dev"
    
    if [[ "$root_dev" == *"p2"* ]] || [[ "$root_dev" == *"p2" ]]; then
        echo "A"
    elif [[ "$root_dev" == *"p3"* ]] || [[ "$root_dev" == *"p3" ]]; then
        echo "B"
    else
        log_error "Cannot determine active partition from: $root_dev"
        return 1
    fi
}

# Get inactive partition device path
get_inactive_partition() {
    local active=$(detect_active_partition)
    if [ "$active" = "A" ]; then
        echo "$BOOT_PARTITION_B"
    else
        echo "$BOOT_PARTITION_A"
    fi
}

# Get current firmware version
get_current_version() {
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        cat "$CURRENT_VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Compare version numbers (returns 1 if new_version > current_version)
compare_versions() {
    local current=$1
    local new=$2
    
    # Simple version comparison (assumes semantic versioning)
    if [ "$(printf '%s\n' "$new" "$current" | sort -V | head -n1)" != "$new" ]; then
        return 0  # new_version is newer
    else
        return 1  # new_version is not newer
    fi
}

# ============================================================================
# USB Detection and Mounting
# ============================================================================
mount_usb() {
    log_info "Searching for USB device with firmware bundle..."
    
    # Find USB block devices
    for dev in /dev/sd[a-z][0-9]*; do
        if [ ! -e "$dev" ]; then
            continue
        fi
        
        # Create mount point
        mkdir -p "$USB_MOUNT_POINT"
        
        # Try to mount (try different filesystem types)
        if mount -t vfat "$dev" "$USB_MOUNT_POINT" 2>/dev/null || \
           mount -t ext4 "$dev" "$USB_MOUNT_POINT" 2>/dev/null || \
           mount -t ntfs "$dev" "$USB_MOUNT_POINT" 2>/dev/null; then
            log_info "Mounted USB device $dev to $USB_MOUNT_POINT"
            
            # Check if firmware bundle exists
            if [ -f "$USB_MOUNT_POINT/$FIRMWARE_BUNDLE_NAME" ]; then
                log_info "Found firmware bundle: $FIRMWARE_BUNDLE_NAME"
                return 0
            else
                log_info "Firmware bundle not found on $dev, trying next device..."
                umount "$USB_MOUNT_POINT" 2>/dev/null || true
            fi
        fi
    done
    
    log_warn "No USB device with firmware bundle found"
    return 1
}

# ============================================================================
# Firmware Bundle Extraction
# ============================================================================
extract_firmware_bundle() {
    local bundle_path="$USB_MOUNT_POINT/$FIRMWARE_BUNDLE_NAME"
    
    log_info "Extracting firmware bundle..."
    
    # Create temporary extraction directory
    mkdir -p "$TEMP_EXTRACT_DIR"
    
    # Extract .bin file (assuming it's a tar archive)
    # Adjust extraction method based on your bundle format
    if file "$bundle_path" | grep -q "tar"; then
        tar -xf "$bundle_path" -C "$TEMP_EXTRACT_DIR"
    elif file "$bundle_path" | grep -q "gzip"; then
        tar -xzf "$bundle_path" -C "$TEMP_EXTRACT_DIR"
    else
        # Try as tar anyway
        tar -xf "$bundle_path" -C "$TEMP_EXTRACT_DIR" 2>/dev/null || {
            log_error "Failed to extract firmware bundle. Unsupported format?"
            return 1
        }
    fi
    
    log_info "Firmware bundle extracted to $TEMP_EXTRACT_DIR"
    
    # Verify required files exist
    if [ ! -f "$TEMP_EXTRACT_DIR/manifest.json" ]; then
        log_error "manifest.json not found in firmware bundle"
        return 1
    fi
    
    if [ ! -f "$TEMP_EXTRACT_DIR/signature.sig" ]; then
        log_error "signature.sig not found in firmware bundle"
        return 1
    fi
    
    local firmware_file=$(find "$TEMP_EXTRACT_DIR" -name "*.img" -o -name "firmware.bin" | head -n1)
    if [ -z "$firmware_file" ]; then
        log_error "Firmware image file not found in bundle"
        return 1
    fi
    
    echo "$firmware_file"  # Return firmware file path
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate Hardware ID
validate_hardware_id() {
    local manifest_path="$TEMP_EXTRACT_DIR/manifest.json"
    local hw_id=$(jq -r '.hardware_id' "$manifest_path" 2>/dev/null)
    
    if [ -z "$hw_id" ] || [ "$hw_id" = "null" ]; then
        log_error "Invalid or missing hardware_id in manifest.json"
        return 1
    fi
    
    log_info "Firmware hardware_id: $hw_id, Device hardware_id: $CURRENT_HARDWARE_ID"
    
    if [ "$hw_id" != "$CURRENT_HARDWARE_ID" ]; then
        log_error "Hardware ID mismatch! Firmware is for '$hw_id', but device is '$CURRENT_HARDWARE_ID'"
        return 1
    fi
    
    log_info "Hardware ID validation: PASSED"
    return 0
}

# Validate Version (optional check)
validate_version() {
    local manifest_path="$TEMP_EXTRACT_DIR/manifest.json"
    local new_version=$(jq -r '.version' "$manifest_path" 2>/dev/null)
    local current_version=$(get_current_version)
    
    if [ -z "$new_version" ] || [ "$new_version" = "null" ]; then
        log_error "Invalid or missing version in manifest.json"
        return 1
    fi
    
    log_info "Current version: $current_version, New version: $new_version"
    
    # Check if new version is newer (optional - comment out if you want to allow downgrades)
    if ! compare_versions "$current_version" "$new_version"; then
        log_warn "New firmware version ($new_version) is not newer than current ($current_version)"
        # Uncomment below to enforce version check
        # return 1
    fi
    
    log_info "Version validation: PASSED"
    return 0
}

# Validate Signature using OpenSSL
validate_signature() {
    local manifest_path="$TEMP_EXTRACT_DIR/manifest.json"
    local signature_path="$TEMP_EXTRACT_DIR/signature.sig"
    
    if [ ! -f "$PUBLIC_KEY_PATH" ]; then
        log_error "Public key not found at $PUBLIC_KEY_PATH"
        return 1
    fi
    
    log_info "Validating signature..."
    
    # Verify signature of manifest.json
    # The signature should be of the manifest.json file
    if openssl dgst -sha256 -verify "$PUBLIC_KEY_PATH" -signature "$signature_path" "$manifest_path" >/dev/null 2>&1; then
        log_info "Signature validation: PASSED"
        return 0
    else
        log_error "Signature validation: FAILED - Firmware may be tampered or corrupted!"
        return 1
    fi
}

# Validate Checksum
validate_checksum() {
    local manifest_path="$TEMP_EXTRACT_DIR/manifest.json"
    local firmware_file=$1
    local expected_checksum=$(jq -r '.checksum_md5' "$manifest_path" 2>/dev/null)
    
    if [ -z "$expected_checksum" ] || [ "$expected_checksum" = "null" ]; then
        log_error "Invalid or missing checksum_md5 in manifest.json"
        return 1
    fi
    
    log_info "Calculating MD5 checksum of firmware..."
    local actual_checksum=$(md5sum "$firmware_file" | cut -d' ' -f1)
    
    log_info "Expected checksum: $expected_checksum"
    log_info "Actual checksum:   $actual_checksum"
    
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        log_error "Checksum validation: FAILED - Firmware file is corrupted!"
        return 1
    fi
    
    log_info "Checksum validation: PASSED"
    return 0
}

# ============================================================================
# Flashing Process
# ============================================================================
flash_firmware() {
    local firmware_file=$1
    local target_partition=$(get_inactive_partition)
    
    log_info "Flashing firmware to inactive partition: $target_partition"
    log_info "Firmware file: $firmware_file"
    
    # Verify target partition exists
    if [ ! -b "$target_partition" ]; then
        log_error "Target partition $target_partition does not exist!"
        return 1
    fi
    
    # Get partition size
    local partition_size=$(blockdev --getsize64 "$target_partition")
    local firmware_size=$(stat -c%s "$firmware_file")
    
    log_info "Partition size: $partition_size bytes"
    log_info "Firmware size: $firmware_size bytes"
    
    if [ "$firmware_size" -gt "$partition_size" ]; then
        log_error "Firmware is too large for partition!"
        return 1
    fi
    
    # Unmount target partition if mounted (safety check)
    if mountpoint -q "$target_partition" 2>/dev/null; then
        log_warn "Target partition is mounted, unmounting..."
        umount "$target_partition" || {
            log_error "Cannot unmount target partition. Aborting flash operation."
            return 1
        }
    fi
    
    # Flash firmware using dd
    log_info "Starting firmware flash operation (this may take several minutes)..."
    if dd if="$firmware_file" of="$target_partition" bs=1M status=progress oflag=sync; then
        log_info "Firmware flash completed successfully"
        
        # Verify write by reading back and comparing checksum
        log_info "Verifying written firmware..."
        local written_checksum=$(dd if="$target_partition" bs=1M count=$((firmware_size / 1024 / 1024 + 1)) 2>/dev/null | \
                                head -c "$firmware_size" | md5sum | cut -d' ' -f1)
        local original_checksum=$(md5sum "$firmware_file" | cut -d' ' -f1)
        
        if [ "$written_checksum" = "$original_checksum" ]; then
            log_info "Firmware verification: PASSED"
            return 0
        else
            log_error "Firmware verification: FAILED - Written data does not match!"
            return 1
        fi
    else
        log_error "Firmware flash operation FAILED!"
        return 1
    fi
}

# ============================================================================
# Bootloader Integration (U-Boot)
# ============================================================================
update_bootloader() {
    local active_partition=$(detect_active_partition)
    local new_partition
    
    if [ "$active_partition" = "A" ]; then
        new_partition="B"
    else
        new_partition="A"
    fi
    
    log_info "Updating bootloader to boot from partition $new_partition on next reboot"
    
    # Update U-Boot environment variables
    # Method 1: Using fw_setenv (if available)
    if command -v fw_setenv >/dev/null 2>&1; then
        # Set boot partition
        fw_setenv boot_partition "$new_partition" || {
            log_error "Failed to set boot_partition environment variable"
            return 1
        }
        
        # Reset boot counter (for rollback mechanism)
        fw_setenv bootcount 0 || {
            log_warn "Failed to reset bootcount (may not be critical)"
        }
        
        # Set boot attempt flag
        fw_setenv boot_attempt 1 || {
            log_warn "Failed to set boot_attempt (may not be critical)"
        }
        
        log_info "Bootloader environment updated successfully"
        return 0
    else
        log_error "fw_setenv command not found. Cannot update bootloader."
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_info "=========================================="
    log_info "Firmware Update Process Started"
    log_info "=========================================="
    
    # Step 1: Mount USB and find firmware bundle
    if ! mount_usb; then
        log_info "No firmware update found. Exiting."
        exit 0  # Not an error - just no update available
    fi
    
    # Step 2: Extract firmware bundle
    local firmware_file
    firmware_file=$(extract_firmware_bundle) || {
        log_error "Failed to extract firmware bundle"
        exit 1
    }
    
    # Step 3: Validate firmware
    log_info "Starting firmware validation..."
    
    if ! validate_hardware_id; then
        log_error "Hardware ID validation failed. Aborting update."
        exit 1
    fi
    
    if ! validate_version; then
        log_error "Version validation failed. Aborting update."
        exit 1
    fi
    
    if ! validate_signature; then
        log_error "Signature validation failed. Aborting update."
        exit 1
    fi
    
    if ! validate_checksum "$firmware_file"; then
        log_error "Checksum validation failed. Aborting update."
        exit 1
    fi
    
    log_info "All validations passed!"
    
    # Step 4: Flash firmware to inactive partition
    if ! flash_firmware "$firmware_file"; then
        log_error "Firmware flash failed. Aborting update."
        exit 1
    fi
    
    # Step 5: Update bootloader
    if ! update_bootloader; then
        log_error "Bootloader update failed. Firmware is flashed but may not boot."
        exit 1
    fi
    
    # Step 6: Update version file
    local new_version=$(jq -r '.version' "$TEMP_EXTRACT_DIR/manifest.json")
    echo "$new_version" > "$CURRENT_VERSION_FILE" || log_warn "Failed to update version file"
    
    log_info "=========================================="
    log_info "Firmware Update Completed Successfully!"
    log_info "System will reboot in 10 seconds..."
    log_info "=========================================="
    
    # Reboot system
    sleep 10
    reboot
}

# Run main function
main "$@"

