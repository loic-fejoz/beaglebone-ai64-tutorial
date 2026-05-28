#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"
FIRMWARE_NAME="pru9-fw"
FIRMWARE_BIN="$DIR/main-pru"
REMOTEPROC_ID="remoteproc9"
EXPECTED_LOG="remote processor b138000.pru is now up"

SUDO_PASS="${SUDO_PASS:-temppwd}"

echo "=== Step 00: Deploying $FIRMWARE_BIN to $SSH_TARGET ==="
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
