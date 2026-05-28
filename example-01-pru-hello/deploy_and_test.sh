#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"
FIRMWARE_NAME="pru9-hellobis"
FIRMWARE_BIN="$DIR/pru9-hellobis"
REMOTEPROC_ID="remoteproc9"
EXPECTED_TRACE="Hello world, I am PRU!"

SUDO_PASS="${SUDO_PASS:-temppwd}"

echo "=== Step 01: Deploying $FIRMWARE_BIN to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new "$FIRMWARE_BIN" "$SSH_TARGET:/tmp/$FIRMWARE_NAME"

echo "Restarting remoteproc and reading trace..."
TRACE_OUTPUT=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FIRMWARE_NAME /lib/firmware/ && \
  (echo stop > /sys/class/remoteproc/$REMOTEPROC_ID/state 2>/dev/null || true) && \
  echo $FIRMWARE_NAME > /sys/class/remoteproc/$REMOTEPROC_ID/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_ID/state && \
  sleep 1.5 && \
  cat /sys/kernel/debug/remoteproc/$REMOTEPROC_ID/trace0
'")

echo "$TRACE_OUTPUT"

if echo "$TRACE_OUTPUT" | grep -F "$EXPECTED_TRACE" > /dev/null; then
  echo "SUCCESS: $FIRMWARE_BIN is running and trace output matches expectations."
else
  echo "ERROR: Trace mismatch or missing."
  exit 1
fi
