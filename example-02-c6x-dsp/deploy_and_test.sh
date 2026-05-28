#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_TARGET="${1:-debian@192.168.1.151}"
SUDO_PASS="${SUDO_PASS:-temppwd}"

deploy_and_test_core() {
  local bin="$DIR/$1"
  local name="$2"
  local rproc="$3"
  local expected="$4"

  echo "Deploying $bin to $SSH_TARGET..."
  scp -o StrictHostKeyChecking=accept-new "$bin" "$SSH_TARGET:/tmp/$name"

  echo "Restarting $rproc and reading trace..."
  TRACE_OUTPUT=$(ssh -n -o StrictHostKeyChecking=accept-new "$SSH_TARGET" "echo '$SUDO_PASS' | sudo -S bash -c '
    mv /tmp/$name /lib/firmware/ && \
    (echo stop > /sys/class/remoteproc/$rproc/state 2>/dev/null || true) && \
    echo $name > /sys/class/remoteproc/$rproc/firmware && \
    echo start > /sys/class/remoteproc/$rproc/state && \
    sleep 1.5 && \
    cat /sys/kernel/debug/remoteproc/$rproc/trace0
  '")

  echo "$TRACE_OUTPUT"

  if echo "$TRACE_OUTPUT" | grep -F "$expected" > /dev/null; then
    echo "SUCCESS: $bin is successfully running on $rproc."
  else
    echo "ERROR: $bin verification failed on $rproc."
    exit 1
  fi
}

echo "=== Step 02: Deploying DSP firmware to $SSH_TARGET ==="
deploy_and_test_core "dsp12-hello" "dsp12-hello" "remoteproc12" "Hello world, I am c66_x!"
echo ""
deploy_and_test_core "dsp14-hello" "dsp14-hello" "remoteproc14" "Hello world, I am c7_0!"
