#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"

FW_PRU0="pru0-dual-core-fw"
FW_PRU1="pru1-dual-core-fw"

FW_PRU0_BIN="$DIR/$FW_PRU0"
FW_PRU1_BIN="$DIR/$FW_PRU1"

REMOTEPROC_PRU0="remoteproc0" # ICSSG0 PRU0 (Coordinator)
REMOTEPROC_PRU1="remoteproc3" # ICSSG0 PRU1 (Worker)

EXPECTED_LOG_PRU0="remote processor b034000.pru is now up"
EXPECTED_LOG_PRU1="remote processor b038000.pru is now up"

SUDO_PASS="${SUDO_PASS:-temppwd}"

if [ ! -f "$FW_PRU0_BIN" ] || [ ! -f "$FW_PRU1_BIN" ]; then
  echo "ERROR: Compiled firmwares not found! Please run make first."
  exit 1
fi

echo "=== Step 04: Deploying firmwares to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new "$FW_PRU0_BIN" "$FW_PRU1_BIN" "$SSH_TARGET:/tmp/"

echo "Loading and starting Subsystem 0, PRU 1 ($FW_PRU1) on $REMOTEPROC_PRU1 (Worker Core)..."
DMESG_PRU1=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FW_PRU1 /lib/firmware/ && \
  ( [ \"\$(cat /sys/class/remoteproc/$REMOTEPROC_PRU1/state)\" = \"offline\" ] || echo stop > /sys/class/remoteproc/$REMOTEPROC_PRU1/state ) && \
  echo $FW_PRU1 > /sys/class/remoteproc/$REMOTEPROC_PRU1/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_PRU1/state && \
  sleep 0.5 && \
  dmesg | tail -n 25
'")

echo "Loading and starting Subsystem 0, PRU 0 ($FW_PRU0) on $REMOTEPROC_PRU0 (Coordinator Core)..."
DMESG_PRU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FW_PRU0 /lib/firmware/ && \
  ( [ \"\$(cat /sys/class/remoteproc/$REMOTEPROC_PRU0/state)\" = \"offline\" ] || echo stop > /sys/class/remoteproc/$REMOTEPROC_PRU0/state ) && \
  echo $FW_PRU0 > /sys/class/remoteproc/$REMOTEPROC_PRU0/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_PRU0/state && \
  sleep 0.5 && \
  dmesg | tail -n 25
'")

# Verify PRU1 started
if echo "$DMESG_PRU1" | grep -F "$EXPECTED_LOG_PRU1" > /dev/null; then
  echo "SUCCESS: $FW_PRU1 successfully loaded on $REMOTEPROC_PRU1."
else
  echo "WARNING: Could not verify PRU1 boot in recent dmesg. Checking state files..."
  STATE_PRU1=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "cat /sys/class/remoteproc/$REMOTEPROC_PRU1/state")
  echo "PRU1 state: $STATE_PRU1"
  if [ "$STATE_PRU1" != "running" ]; then
    echo "ERROR: PRU1 is not running!"
    exit 1
  fi
fi

# Verify PRU0 started
if echo "$DMESG_PRU0" | grep -F "$EXPECTED_LOG_PRU0" > /dev/null; then
  echo "SUCCESS: $FW_PRU0 successfully loaded on $REMOTEPROC_PRU0."
else
  echo "WARNING: Could not verify PRU0 boot in recent dmesg. Checking state files..."
  STATE_PRU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "cat /sys/class/remoteproc/$REMOTEPROC_PRU0/state")
  echo "PRU0 state: $STATE_PRU0"
  if [ "$STATE_PRU0" != "running" ]; then
    echo "ERROR: PRU0 is not running!"
    exit 1
  fi
fi

echo ""
echo "=== Verifying Pin Multiplexing for P8_11 (Subsystem 0, PRU0 Output) ==="
PINMUX_P8_11=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S cat /sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins | grep -i '11c0f4'")
VAL_P8_11=$(echo "$PINMUX_P8_11" | awk '{print $6}')

if [ -n "$VAL_P8_11" ] && [ "${VAL_P8_11: -1}" = "0" ]; then
  echo "SUCCESS: Pin P8_11 register 11c0f4 is set to $VAL_P8_11 (Mode 0, pruout)."
else
  echo "WARNING: Pin P8_11 is NOT configured to Mode 0 (pruout)!"
  if [ -n "$VAL_P8_11" ]; then
    echo "Current register value: $VAL_P8_11 (Mode ${VAL_P8_11: -1})"
  else
    echo "Could not read register status for P8_11."
  fi
fi

echo ""
echo "=== Verifying Pin Multiplexing for P8_41 (Subsystem 0, PRU1 Output) ==="
PINMUX_P8_41=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S cat /sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins | grep -i '11c110'")
VAL_P8_41=$(echo "$PINMUX_P8_41" | awk '{print $6}')

if [ -n "$VAL_P8_41" ] && [ "${VAL_P8_41: -1}" = "0" ]; then
  echo "SUCCESS: Pin P8_41 register 11c110 is set to $VAL_P8_41 (Mode 0, pruout)."
else
  echo "WARNING: Pin P8_41 is NOT configured to Mode 0 (pruout)!"
  if [ -n "$VAL_P8_41" ]; then
    echo "Current register value: $VAL_P8_41 (Mode ${VAL_P8_41: -1})"
  else
    echo "Could not read register status for P8_41."
  fi
fi

if [ "${VAL_P8_11: -1}" != "0" ] || [ "${VAL_P8_41: -1}" != "0" ]; then
  echo ""
  echo "To resolve pinmux warnings, please run:"
  echo "  ./example-04-pru-dual-led/enable_overlay.sh $SSH_TARGET"
  echo "and then reboot the BeagleBone board."
fi
