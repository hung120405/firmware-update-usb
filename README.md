🚀 Secure Firmware Update System via USB 🚀

A "brick-proof" solution for safely and automatically updating software on the Raspberry Pi Zero 2W (or similar devices) in the field.

Context: Ever "bricked" an embedded device while trying a remote firmware update? I have. This project was born to solve that exact pain point. It uses the classic A/B partitioning mechanism to ensure that even if an update fails (power loss, bad file, etc.), the device can automatically "roll back" to the last known stable firmware version.

✨ Key Features
🛡️ Brick-Proof: Uses A/B partitioning. The update process always happens on the "inactive" partition.

🔌 100% Automatic: Just plug in a USB drive with the new firmware. The system automatically detects, validates, and updates. No manual intervention is needed.

🔐 Secure: Firmware is verified with an RSA digital signature and a SHA256 checksum before installation. This prevents any tampered or corrupt files.

🔄 Automatic Rollback: Integrates with the Bootloader (U-Boot) to monitor boot success. If the new firmware fails to boot multiple times, the system automatically reverts to the old partition.

💡 Lightweight & Fast: Written mainly in Bash script (for logic) and C (for raw flash writing), ensuring it runs smoothly on low-power devices like the Pi Zero.

🏗️ Architecture & Flow
This system works based on 3 main components:

Detection (udev): A rule in /udev/ "catches" the event when a USB drive is plugged in.

Activation (systemd): udev triggers a service in /systemd/ to run the update script.

Execution (scripts): The main brain is in /scripts/. It performs:

Mounts the USB drive.

Checks the package's signature (RSA) and checksum (SHA256).

Determines which partition (A or B) is currently inactive.

Calls the C program (flash_updater) to write the new firmware to the inactive partition.

Updates the U-Boot environment variables to boot from the new partition.

Reboots the device.

📂 Directory Structure
firmware-update-system/
├── udev/                 # Rule to "catch" the USB plug-in event
├── systemd/              # Service to run the update script
├── scripts/              # 🧠 THE BRAIN OF THE SYSTEM (check, validate, flash, swap boot)
├── examples/             # Example scripts (key generation, bundling)
└── README.md             # This file!
⚡ Quick Start
Here are the 3 basic steps to see it in action.

1. On the Target Device (Pi Zero): Installation
(Only needs to be done once)

Bash

# Clone this repo
git clone https://github.com/hung120405/firmware-update-usb.git
cd firmware-update-system

# Run the install script (will copy files to the correct locations)
# You will need sudo privileges
sudo ./scripts/install.sh
(The install.sh script will guide you to copy the public_key.pem file to /etc/fw_update/)

2. On the Build Machine (Your PC): Package the Firmware
Bash

cd firmware-update-system/examples

# 1. Generate a public/private keypair (only run once)
./generate_keypair.sh
# (Remember to copy the public_key.pem to the Target Device as in step 1)

# 2. Assuming you have a new firmware file named "my_app.bin"
# Run the script to package it (version 1.1.0)
./build_bundle.sh my_app.bin 1.1.0
This command will create the signed and bundled firmware_bundle.bin file.

3. On the Target Device: Update
Copy the firmware_bundle.bin file onto a USB drive (formatted as FAT32).

Plug the USB into the Raspberry Pi Zero 2W.

That's it. The system will handle the rest.

🔧 Troubleshooting
Nothing seems to happen?

Check the logs: journalctl -f -u fw-update

Ensure the USB is formatted as FAT32.

Make sure the public_key.pem file was copied correctly to /etc/fw_update/public_key.pem on the Pi.

Device is "frozen" or "boot-looping" after an update?

Don't worry. Wait 3-5 minutes. If the U-Boot A/B logic is set up correctly, the device will try to boot 3 times and then automatically roll back to the old, stable firmware version.
