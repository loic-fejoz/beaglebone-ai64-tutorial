#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"
FIRMWARE_NAME="pru8-led-fw"
FIRMWARE_BIN="$DIR/pru8-led-fw"
REMOTEPROC_ID="remoteproc0"
EXPECTED_LOG="remote processor b034000.pru is now up"

SUDO_PASS="${SUDO_PASS:-temppwd}"

if [ ! -f "$FIRMWARE_BIN" ]; then
  echo "ERROR: Compiled firmware $FIRMWARE_NAME not found! Please build it first."
  exit 1
fi

echo "=== Step 03: Deploying $FIRMWARE_BIN to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new "$FIRMWARE_BIN" "$SSH_TARGET:/tmp/$FIRMWARE_NAME"

echo "Restarting remoteproc and checking dmesg..."
DMESG_OUTPUT=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FIRMWARE_NAME /lib/firmware/ && \
  ( [ \"\$(cat /sys/class/remoteproc/$REMOTEPROC_ID/state)\" = \"offline\" ] || echo stop > /sys/class/remoteproc/$REMOTEPROC_ID/state ) && \
  echo $FIRMWARE_NAME > /sys/class/remoteproc/$REMOTEPROC_ID/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_ID/state && \
  sleep 1.5 && \
  dmesg | tail -n 50
'")

echo "$DMESG_OUTPUT"

if echo "$DMESG_OUTPUT" | grep -F "$EXPECTED_LOG" > /dev/null; then
  echo "SUCCESS: $FIRMWARE_BIN successfully loaded on $REMOTEPROC_ID."
else
  echo "ERROR: Verification failed. Log entry not found."
  exit 1
fi

echo ""
echo "=== Verifying Pin Multiplexing for P8_11 ==="
PINMUX_STATUS=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S cat /sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins | grep -i '11c0f4'")
VAL=$(echo "$PINMUX_STATUS" | awk '{print $6}')

if [ -n "$VAL" ] && [ "${VAL: -1}" = "0" ]; then
  echo "SUCCESS: Pin P8_11 register 11c0f4 is set to $VAL (Mode 0, pruout)."
else
  echo "WARNING: Pin P8_11 is NOT configured to Mode 0 (pruout)!"
  if [ -n "$VAL" ]; then
    echo "Current register value: $VAL (Mode ${VAL: -1})"
  else
    echo "Could not read pin multiplexer register status."
  fi
  echo "To resolve this, please run:"
  echo "  ./example-03-pru-led/enable_overlay.sh $SSH_TARGET"
  echo "and then reboot the BeagleBone board."
fi

