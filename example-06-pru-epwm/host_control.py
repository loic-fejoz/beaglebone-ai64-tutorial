#!/usr/bin/env python3
import os
import time
import sys
import argparse
import signal

DEVICE = "/dev/rpmsg_pru30"
fd = None

def stop_pwm_and_exit():
    global fd
    if fd is not None:
        try:
            print("\nStopping PWM (Forced LOW)...")
            os.write(fd, b"0\n")
            response = os.read(fd, 64)
            print(f"Response from RTU: {response.decode().strip()}")
        except Exception as e:
            print(f"Error stopping PWM: {e}")
        finally:
            try:
                os.close(fd)
            except Exception:
                pass
            fd = None

def sigterm_handler(signum, frame):
    sys.exit(0)

def check_clock_rate():
    path = "/sys/kernel/debug/clk/clk_summary"
    if not os.path.exists(path):
        return
    try:
        with open(path, "r") as f:
            for line in f:
                if "clk:83:0" in line:
                    parts = line.strip().split()
                    if len(parts) >= 5:
                        try:
                            rate = int(parts[4])
                            if rate != 125000000:
                                print(f"WARNING: EHRPWM0 clock (clk:83:0) is {rate / 1000000:.1f} MHz, not 125.0 MHz.")
                                print("The PRU firmware calculations assume a 125 MHz base frequency.")
                                print("Physical output frequency will be scaled incorrectly.\n")
                        except ValueError:
                            pass
                    break
    except Exception:
        pass

def main():
    global fd
    
    parser = argparse.ArgumentParser(description="Control BeagleBone AI-64 EPWM via PRU/RTU cores.")
    parser.add_argument("--freq", "-f", type=int, help="Target frequency in Hz. If 0, turns PWM off and exits.")
    parser.add_argument("--duration", "-d", type=float, help="Duration in seconds to run at the fixed frequency. Only applicable with --freq.")
    args = parser.parse_args()

    # Check that EHRPWM0 clock is configured correctly
    check_clock_rate()

    if not os.path.exists(DEVICE):
        print(f"ERROR: Character device {DEVICE} does not exist.")
        print("Ensure the RTU firmware is loaded and rpmsg_pru driver is active.")
        sys.exit(1)

    if args.freq is not None and args.freq < 0:
        print("ERROR: Frequency must be a non-negative integer.")
        sys.exit(1)

    if args.duration is not None:
        if args.freq is None:
            print("ERROR: --duration requires --freq to be specified.")
            sys.exit(1)
        if args.duration <= 0:
            print("ERROR: Duration must be positive.")
            sys.exit(1)

    # Register SIGTERM to raise SystemExit so finally block runs
    signal.signal(signal.SIGTERM, sigterm_handler)

    try:
        fd = os.open(DEVICE, os.O_RDWR)
    except PermissionError:
        print(f"Permission denied. Please run with sudo: 'sudo python3 {sys.argv[0]}'")
        sys.exit(1)

    try:
        if args.freq is not None:
            freq = args.freq
            if freq == 0:
                print("Sending: 0 Hz -> Turning PWM OFF (Forced LOW)")
                os.write(fd, b"0\n")
                response = os.read(fd, 64)
                print(f"Response from RTU: {response.decode().strip()}")
                os.close(fd)
                fd = None
                return

            print(f"Sending frequency: {freq} Hz")
            msg = f"{freq}\n"
            os.write(fd, msg.encode())
            response = os.read(fd, 64)
            print(f"Response from RTU: {response.decode().strip()}")

            if args.duration is not None:
                print(f"Running for {args.duration} seconds...")
                time.sleep(args.duration)
            else:
                print("Running indefinitely. Press Ctrl+C to stop.")
                while True:
                    time.sleep(1)
        else:
            print("=== Sweep Enhanced PWM (EPWM0_B) Frequency on P8.13 via PRU0 + RTU0 ===")
            print(f"Opening {DEVICE} for writing/reading...")
            
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
                msg = f"{freq}\n"
                if freq == 0:
                    print("Sending: 0 Hz -> Turning PWM OFF (Forced LOW)")
                else:
                    print(f"Sending frequency: {freq:8d} Hz")
                
                os.write(fd, msg.encode())
                response = os.read(fd, 64)
                print(f"Response from RTU: {response.decode().strip()}")
                time.sleep(1.5)
                
            print("\nSweep completed successfully!")
            os.close(fd)
            fd = None
            
    except KeyboardInterrupt:
        print("\nTerminated by user.")
    finally:
        stop_pwm_and_exit()

if __name__ == "__main__":
    main()
