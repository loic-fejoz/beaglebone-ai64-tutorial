#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"

FW_PRU0="pru0-epwm-fw"
FW_RTU0="rtu0-rpmsg-fw"
FW_PRU1="pru1-sampler-fw"
FW_DSP12="dsp12-fft"
DTBO="bbai64-pru-dsp-fft.dtbo"

REMOTEPROC_PRU0="remoteproc0"   # ICSSG0 PRU0 (EPWM Controller)
REMOTEPROC_RTU0="remoteproc1"   # ICSSG0 RTU0 (RPMsg dynamic control)
REMOTEPROC_PRU1="remoteproc3"   # ICSSG0 PRU1 (Sampler)
REMOTEPROC_DSP12="remoteproc12" # C66x_1 DSP (FFT Computation)

SUDO_PASS="${SUDO_PASS:-temppwd}"

# Check for binaries and scripts
for f in "$FW_PRU0" "$FW_RTU0" "$FW_PRU1" "$FW_DSP12" "$DTBO" "host_control.py"; do
  if [ ! -f "$DIR/$f" ]; then
    echo "ERROR: Compiled file or script $f not found!"
    exit 1
  fi
done

echo "=== Step 07: Deploying overlays, firmwares, and controller to $SSH_TARGET ==="
scp -o StrictHostKeyChecking=accept-new \
  "$DIR/$FW_PRU0" "$DIR/$FW_RTU0" "$DIR/$FW_PRU1" "$DIR/$FW_DSP12" "$DIR/$DTBO" "$DIR/host_control.py" \
  "$SSH_TARGET:/tmp/"

# Stop remoteprocs if running
echo "Stopping remoteprocs..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  for rp in $REMOTEPROC_PRU0 $REMOTEPROC_RTU0 $REMOTEPROC_PRU1 $REMOTEPROC_DSP12; do
    if [ -f /sys/class/remoteproc/\$rp/state ] && [ \"\$(cat /sys/class/remoteproc/\$rp/state)\" = \"running\" ]; then
      echo stop > /sys/class/remoteproc/\$rp/state
    fi
  done
'"

# Copy overlay and firmwares
echo "Installing firmware and overlay..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  mv /tmp/$DTBO /boot/firmware/overlays/ && \
  mv /tmp/$FW_PRU0 /lib/firmware/ && \
  mv /tmp/$FW_RTU0 /lib/firmware/ && \
  mv /tmp/$FW_PRU1 /lib/firmware/ && \
  mv /tmp/$FW_DSP12 /lib/firmware/
'"

# Start C66x_1 DSP first
echo "Loading and starting C66x_1 DSP ($FW_DSP12) on $REMOTEPROC_DSP12..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  echo $FW_DSP12 > /sys/class/remoteproc/$REMOTEPROC_DSP12/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_DSP12/state
'"

# Start RTU0
echo "Loading and starting RTU0 ($FW_RTU0) on $REMOTEPROC_RTU0..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  echo $FW_RTU0 > /sys/class/remoteproc/$REMOTEPROC_RTU0/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_RTU0/state
'"

# Start PRU0
echo "Loading and starting PRU0 ($FW_PRU0) on $REMOTEPROC_PRU0..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  echo $FW_PRU0 > /sys/class/remoteproc/$REMOTEPROC_PRU0/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_PRU0/state
'"

# Start PRU1
echo "Loading and starting PRU1 ($FW_PRU1) on $REMOTEPROC_PRU1..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  echo $FW_PRU1 > /sys/class/remoteproc/$REMOTEPROC_PRU1/firmware && \
  echo start > /sys/class/remoteproc/$REMOTEPROC_PRU1/state
'"

# Verify core states
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "
  for rp in $REMOTEPROC_DSP12 $REMOTEPROC_RTU0 $REMOTEPROC_PRU0 $REMOTEPROC_PRU1; do
    state=\$(cat /sys/class/remoteproc/\$rp/state)
    echo \"\$rp State: \$state\"
    if [ \"\$state\" != \"running\" ]; then
      echo \"ERROR: \$rp failed to start! Check dmesg on the board.\"
      exit 1
    fi
  done
"

# Check for rpmsg character device
echo "Checking for /dev/rpmsg_pru30..."
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "
  if [ -e /dev/rpmsg_pru30 ]; then
    echo 'SUCCESS: /dev/rpmsg_pru30 is available.'
  else
    echo 'WARNING: /dev/rpmsg_pru30 does not exist yet. Loading rpmsg_pru module...'
    echo '$SUDO_PASS' | sudo -S modprobe rpmsg_pru
    sleep 1
    if [ -e /dev/rpmsg_pru30 ]; then
      echo 'SUCCESS: /dev/rpmsg_pru30 is now available.'
    else
      echo 'ERROR: /dev/rpmsg_pru30 still missing.'
    fi
  fi
"

# Enable clocks for EHRPWM0
echo "=== Enabling EHRPWM0 Clocks in Kernel ==="
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  PWMCHIP=\"\"
  for chip in /sys/class/pwm/pwmchip*; do
    if readlink -f \"\$chip\" | grep -q \"3000000.pwm\"; then
      PWMCHIP=\$(basename \"\$chip\")
      break
    fi
  done

  if [ -n \"\$PWMCHIP\" ]; then
    echo \"Found \$PWMCHIP for main_ehrpwm0.\"
    if [ ! -d \"/sys/class/pwm/\$PWMCHIP/pwm0\" ]; then
      echo 0 > \"/sys/class/pwm/\$PWMCHIP/export\"
      sleep 0.5
    fi
    echo 1000000 > \"/sys/class/pwm/\$PWMCHIP/pwm0/period\"
    echo 500000 > \"/sys/class/pwm/\$PWMCHIP/pwm0/duty_cycle\"
    echo 1 > \"/sys/class/pwm/\$PWMCHIP/pwm0/enable\"
    echo \"SUCCESS: Clocks activated on \$PWMCHIP.\"
  else
    echo \"ERROR: pwmchip not found! Make sure overlay is enabled.\"
    exit 1
  fi
'"

# Verify Pinmux
echo "=== Verifying Pinmux Configuration ==="
ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
  for pin in P8_13:11c168 P8_41:11c110; do
    name=\${pin%%:*}
    addr=\${pin##*:}
    val=\$(cat /sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins | grep -i \"\$addr\" | awk \"{print \\\$6}\")
    echo \"Pin \$name (\$addr) Register: \$val\"
  done
'"

echo ""
echo "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="
echo "Connect a jumper wire from P8_13 (PWM Generator) to P8_41 (PRU Sampler)."
echo "Then, start the host controller:"
echo "  sudo python3 /tmp/host_control.py"
echo "And monitor the DSP live output in another terminal:"
echo "  sudo tail -f /sys/kernel/debug/remoteproc/remoteproc12/trace0"
