#!/usr/bin/env python3
import os
import time
import sys

DEVICE = "/dev/rpmsg_pru30"

if not os.path.exists(DEVICE):
    print(f"ERROR: Character device {DEVICE} does not exist.")
    print("Ensure the RTU firmware is loaded and rpmsg_pru driver is active.")
    sys.exit(1)

print(f"=== Sweep dynamic delay frequency on PRU0 via RTU0 ===")
print(f"Opening {DEVICE} for writing/reading...")

try:
    fd = os.open(DEVICE, os.O_RDWR)
except PermissionError:
    print(f"Permission denied. Please run with sudo: 'sudo python3 {sys.argv[0]}'")
    sys.exit(1)

try:
    # Sweeping from slow to fast (shorter delays)
    delays = [2000000, 1000000, 500000, 200000, 100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100, 50, 20, 10]
    
    for delay in delays:
        # We append a newline so our lightweight parser knows where digits end
        msg = f"{delay}\n"
        print(f"Sending delay value: {delay:8d} cycles (approx {2 * delay * 5 / 1000000:.3f} ms per step)")
        
        # Write to the RTU core via RPMsg
        os.write(fd, msg.encode())
        
        # Read back acknowledgment
        response = os.read(fd, 64)
        print(f"Response from RTU: {response.decode().strip()}")
        
        time.sleep(1.0)
        
    print("\nSweep completed successfully!")
finally:
    os.close(fd)
