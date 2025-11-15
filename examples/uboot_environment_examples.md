# U-Boot Environment Variable Management Examples

This document provides examples of managing U-Boot environment variables for A/B partitioning and rollback mechanism.

## Prerequisites

On the target device, you need to have `fw_setenv` and `fw_printenv` tools installed. These are typically provided by the `u-boot-fw-utils` package in Yocto.

## Basic Commands

### View Current Environment Variables

```bash
# Print all environment variables
fw_printenv

# Print specific variable
fw_printenv boot_partition
fw_printenv bootcount
```

### Set Environment Variables

```bash
# Set boot partition to A
fw_setenv boot_partition A

# Set boot partition to B
fw_setenv boot_partition B

# Set boot counter (for rollback mechanism)
fw_setenv bootcount 0

# Set boot attempt flag
fw_setenv boot_attempt 1
```

## A/B Partitioning Setup

### Initial Setup

```bash
# Set default boot partition to A
fw_setenv boot_partition A

# Initialize boot counter
fw_setenv bootcount 0

# Set maximum boot attempts before rollback
fw_setenv max_boot_attempts 3
```

### Switching Boot Partition

```bash
# Switch to partition B
fw_setenv boot_partition B
fw_setenv bootcount 0
fw_setenv boot_attempt 1

# Switch back to partition A
fw_setenv boot_partition A
fw_setenv bootcount 0
fw_setenv boot_attempt 1
```

## Rollback Mechanism Variables

The following environment variables should be set up in U-Boot to implement rollback:

```bash
# Current boot partition (A or B)
fw_setenv boot_partition A

# Boot counter (incremented on each boot attempt)
fw_setenv bootcount 0

# Maximum allowed boot attempts before rollback
fw_setenv max_boot_attempts 3

# Boot attempt flag (set to 1 when trying new firmware)
fw_setenv boot_attempt 0

# Rollback flag (set to 1 if rollback occurred)
fw_setenv rollback_flag 0
```

## U-Boot Boot Script Example

You would need to add logic to your U-Boot boot script (e.g., `boot.scr` or `boot.cmd`) to implement the rollback mechanism. Here's a conceptual example:

```bash
# In U-Boot boot script (boot.cmd)
# Check boot counter
if test "${bootcount}" -gt "${max_boot_attempts}"; then
    # Rollback to previous partition
    if test "${boot_partition}" = "B"; then
        setenv boot_partition A
    else
        setenv boot_partition B
    fi
    setenv bootcount 0
    setenv rollback_flag 1
    saveenv
fi

# Load kernel from appropriate partition
if test "${boot_partition}" = "A"; then
    setenv bootargs 'root=/dev/mmcblk0p2 rootfstype=ext4 ...'
    load mmc 0:2 ${kernel_addr_r} /boot/zImage
else
    setenv bootargs 'root=/dev/mmcblk0p3 rootfstype=ext4 ...'
    load mmc 0:3 ${kernel_addr_r} /boot/zImage
fi

# Increment boot counter if this is a boot attempt
if test "${boot_attempt}" = "1"; then
    setexpr bootcount ${bootcount} + 1
    saveenv
fi

# Boot kernel
bootz ${kernel_addr_r}
```

## Testing Commands

### Simulate Boot Failure

```bash
# Increment boot counter manually
fw_setenv bootcount 3

# Check if rollback would trigger
fw_printenv bootcount
fw_printenv max_boot_attempts
```

### Reset Boot Counter

```bash
# Reset boot counter (after successful boot)
fw_setenv bootcount 0
fw_setenv boot_attempt 0
```

## Integration with update_check.sh

The `update_check.sh` script automatically updates these variables:

```bash
# After successful firmware flash
fw_setenv boot_partition B    # Switch to new partition
fw_setenv bootcount 0          # Reset counter
fw_setenv boot_attempt 1       # Mark as boot attempt
```

## Troubleshooting

### Check if fw_setenv is available

```bash
which fw_setenv
which fw_printenv
```

### View all boot-related variables

```bash
fw_printenv | grep boot
```

### Manual rollback

If automatic rollback fails, you can manually rollback:

```bash
# Switch to partition A
fw_setenv boot_partition A
fw_setenv bootcount 0
reboot
```

