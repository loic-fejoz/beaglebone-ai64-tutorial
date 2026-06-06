#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"
SUDO_PASS="${SUDO_PASS:-temppwd}"
DTBO_NAME="bbai64-pru-dsp-fft.dtbo"
DTBO_PATH="$DIR/$DTBO_NAME"

if [ ! -f "$DTBO_PATH" ]; then
  echo "ERROR: Compiled overlay $DTBO_NAME not found! Please build it first."
  exit 1
fi

echo "=== Copying DTBO overlay to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new "$DTBO_PATH" "$SSH_TARGET:/tmp/$DTBO_NAME"

echo "=== Enabling overlay on target board ==="
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S python3 -c '
import sys, os

# Find active extlinux.conf
filepath = None
for p in [\"/boot/firmware/extlinux/extlinux.conf\", \"/boot/extlinux/extlinux.conf\"]:
    if os.path.exists(p):
        filepath = p
        break

if not filepath:
    print(\"ERROR: extlinux.conf not found on target board!\")
    sys.exit(1)

overlay_dir = os.path.dirname(filepath) + \"/../overlays\"
if not os.path.exists(overlay_dir):
    os.makedirs(overlay_dir, exist_ok=True)

# Copy overlay to firmware overlays folder
os.system(f\"cp /tmp/$DTBO_NAME {overlay_dir}/$DTBO_NAME\")
print(f\"Copied overlay to {overlay_dir}/$DTBO_NAME\")

with open(filepath, \"r\") as f:
    lines = f.readlines()

new_lines = []
found_label = False
added = False
overlay_path = \"/overlays/$DTBO_NAME\"

for line in lines:
    stripped = line.strip()
    if stripped.startswith(\"label Linux eMMC\") or stripped.startswith(\"label Linux microSD\"):
        found_label = True
    elif found_label and stripped.startswith(\"fdtoverlays\"):
        parts = stripped.split()
        new_parts = [parts[0]]
        for p in parts[1:]:
            if \"bbai64-pru-\" not in p:
                new_parts.append(p)
        if overlay_path not in new_parts:
            new_parts.append(overlay_path)
        line = \"    \" + \" \".join(new_parts) + \"\\n\"
        added = True
    elif found_label and stripped.startswith(\"label \"):
        if not added:
            new_lines.append(\"    fdtoverlays \" + overlay_path + \"\\n\")
            added = True
        found_label = False
    
    new_lines.append(line)

if found_label and not added:
    new_lines.append(\"    fdtoverlays \" + overlay_path + \"\\n\")

with open(filepath, \"w\") as f:
    f.writelines(new_lines)

print(f\"Successfully enabled overlay in {filepath}.\")
'"

echo "---------------------------------------------------------"
echo "SUCCESS: Overlay $DTBO_NAME successfully copied and enabled."
echo "Please run: 'ssh $SSH_TARGET sudo reboot' to restart the board"
echo "and apply the pinmux configuration changes."
echo "---------------------------------------------------------"
