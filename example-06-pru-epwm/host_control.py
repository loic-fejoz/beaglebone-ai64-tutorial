#!/usr/bin/env python3
import os
import time
import sys

DEVICE = "/dev/rpmsg_pru30"

if not os.path.exists(DEVICE):
    print(f"ERROR: Character device {DEVICE} does not exist.")
    print("Ensure the RTU firmware is loaded and rpmsg_pru driver is active.")
    sys.exit(1)

print(f"=== Sweep Enhanced PWM (EPWM0_B) Frequency on P8.13 via PRU0 + RTU0 ===")
print(f"Opening {DEVICE} for writing/reading...")

try:
    fd = os.open(DEVICE, os.O_RDWR)
except PermissionError:
    print(f"Permission denied. Please run with sudo: 'sudo python3 {sys.argv[0]}'")
    sys.exit(1)

try:
    # Sweeping from 0 Hz (off) to 50 MHz
    frequencies = [
        0,          # Off (Forced LOW)
        1,          # 1 Hz (Visible blinking)
        2,          # 2 Hz
        5,          # 5 Hz
        10,         # 10 Hz
        20,         # 20 Hz
        50,         # 50 Hz
        100,        # 100 Hz (Solid light but visible on scope)
        500,        # 500 Hz
        1000,       # 1 kHz
        5000,       # 5 kHz
        10000,      # 10 kHz
        50000,      # 50 kHz
        100000,     # 100 kHz
        500000,     # 500 kHz
        1000000,    # 1 MHz
        5000000,    # 5 MHz
        10000000,   # 10 MHz
        25000000,   # 25 MHz
        50000000,   # 50 MHz
        0           # Off (Forced LOW)
    ]
    
    for freq in frequencies:
        # We append a newline so our lightweight parser knows where digits end
        msg = f"{freq}\n"
        if freq == 0:
            print("Sending: 0 Hz -> Turning PWM OFF (Forced LOW)")
        else:
            print(f"Sending frequency: {freq:8d} Hz")
        
        # Write to the RTU core via RPMsg
        os.write(fd, msg.encode())
        
        # Read back acknowledgment
        response = os.read(fd, 64)
        print(f"Response from RTU: {response.decode().strip()}")
        
        # Sleep to observe change
        time.sleep(1.5)
        
    print("\nSweep completed successfully!")
finally:
    os.close(fd)
