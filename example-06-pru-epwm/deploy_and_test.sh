#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"

FW_PRU0="pru0-epwm-fw"
FW_RTU0="rtu0-rpmsg-fw"

FW_PRU0_BIN="$DIR/$FW_PRU0"
FW_RTU0_BIN="$DIR/$FW_RTU0"

REMOTEPROC_PRU0="remoteproc0" # ICSSG0 PRU0 (EPWM Controller)
REMOTEPROC_RTU0="remoteproc1" # ICSSG0 RTU0 (RPMsg dynamic control)

SUDO_PASS="${SUDO_PASS:-temppwd}"

if [ ! -f "$FW_PRU0_BIN" ] || [ ! -f "$FW_RTU0_BIN" ]; then
  echo "ERROR: Compiled firmwares not found! Please run make first."
  exit 1
fi

echo "=== Step 06: Deploying firmwares to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new "$FW_PRU0_BIN" "$FW_RTU0_BIN" "$SSH_TARGET:/tmp/"

echo "Stopping remoteprocs if running..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  for rp in $REMOTEPROC_PRU0 $REMOTEPROC_RTU0; do
    if [ \"\$(cat /sys/class/remoteproc/\$rp/state)\" = \"running\" ]; then
      echo stop > /sys/class/remoteproc/\$rp/state
    fi
  done
'"

echo "Loading and starting RTU0 ($FW_RTU0) on $REMOTEPROC_RTU0 (RPMsg Dynamic Control)..."
DMESG_RTU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FW_RTU0 /lib/firmware/ && \
  echo $FW_RTU0 > /sys/class/remoteproc/$REMOTEPROC_RTU0/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_RTU0/state && \
  sleep 0.5 && \
  dmesg | tail -n 25
'")

echo "Loading and starting PRU0 ($FW_PRU0) on $REMOTEPROC_PRU0 (EPWM Controller)..."
DMESG_PRU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$FW_PRU0 /lib/firmware/ && \
  echo $FW_PRU0 > /sys/class/remoteproc/$REMOTEPROC_PRU0/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_PRU0/state && \
  sleep 0.5 && \
  dmesg | tail -n 25
'")

# Verify RTU0 is running
STATE_RTU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "cat /sys/class/remoteproc/$REMOTEPROC_RTU0/state")
echo "RTU0 state: $STATE_RTU0"
if [ "$STATE_RTU0" != "running" ]; then
  echo "ERROR: RTU0 is not running! Check dmesg on the board."
  exit 1
fi

# Verify PRU0 is running
STATE_PRU0=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "cat /sys/class/remoteproc/$REMOTEPROC_PRU0/state")
echo "PRU0 state: $STATE_PRU0"
if [ "$STATE_PRU0" != "running" ]; then
  echo "ERROR: PRU0 is not running! Check dmesg on the board."
  exit 1
fi

echo "Checking for rpmsg_pru character device..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "
  if [ -e /dev/rpmsg_pru30 ]; then
    echo 'SUCCESS: /dev/rpmsg_pru30 is available.'
  else
    echo 'WARNING: /dev/rpmsg_pru30 does not exist yet. Attempting to load rpmsg_pru module...'
    echo '$SUDO_PASS' | sudo -S modprobe rpmsg_pru
    sleep 1
    if [ -e /dev/rpmsg_pru30 ]; then
      echo 'SUCCESS: /dev/rpmsg_pru30 is now available after loading module.'
    else
      echo 'ERROR: /dev/rpmsg_pru30 still not found. Check kernel logs.'
    fi
  fi
"

echo "=== Ensuring EHRPWM0 Clock is Enabled in Kernel ==="
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  # Find which pwmchip points to 3000000.pwm (ehrpwm0)
  PWMCHIP=\"\"
  for chip in /sys/class/pwm/pwmchip*; do
    if readlink -f \"\$chip\" | grep -q \"3000000.pwm\"; then
      PWMCHIP=\$(basename \"\$chip\")
      break
    fi
  done

  if [ -n \"\$PWMCHIP\" ]; then
    echo \"SUCCESS: Found \$PWMCHIP for main_ehrpwm0 (3000000.pwm).\"
    echo \"Exporting and enabling PWM channel 0 to enable hardware clocks...\"
    if [ ! -d \"/sys/class/pwm/\$PWMCHIP/pwm0\" ]; then
      echo 0 > \"/sys/class/pwm/\$PWMCHIP/export\"
      sleep 0.5
    fi
    echo 1000000 > \"/sys/class/pwm/\$PWMCHIP/pwm0/period\"
    echo 500000 > \"/sys/class/pwm/\$PWMCHIP/pwm0/duty_cycle\"
    echo 1 > \"/sys/class/pwm/\$PWMCHIP/pwm0/enable\"
    echo \"SUCCESS: PWM channel 0 exported and enabled on \$PWMCHIP.\"
  else
    echo \"ERROR: pwmchip for main_ehrpwm0 (3000000.pwm) not found!\"
    echo \"Please ensure the bbai64-pru-epwm overlay has been enabled and the board was rebooted.\"
    exit 1
  fi
'"

echo ""
echo "=== Verifying Pin Multiplexing (Mode 6, pwm expected) ==="
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  for pin in P8_13:11c168 P8_19:11c164; do
    name=\${pin%%:*}
    addr=\${pin##*:}
    val=\$(cat /sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins | grep -i \"\$addr\" | awk \"{print \\\$6}\")
    if [ -n \"\$val\" ] && [ \"\${val: -1}\" = \"6\" ]; then
      echo \"SUCCESS: Pin \$name (\$addr) is set to \$val (Mode 6, pwm).\"
    else
      echo \"WARNING: Pin \$name (\$addr) is NOT set to Mode 6 (Current value: \$val).\"
    fi
  done
'"
