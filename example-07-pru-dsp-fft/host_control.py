#!/usr/bin/env python3
import os
import time
import sys
import argparse
import signal
import threading

DEVICE = "/dev/rpmsg_pru30"
TRACE_FILE = "/sys/kernel/debug/remoteproc/remoteproc12/trace0"
fd = None
running = True
action_log = []

def log_status(msg):
    global action_log
    action_log.append(f"[{time.strftime('%H:%M:%S')}] {msg}")
    if len(action_log) > 6:
        action_log.pop(0)
    print(f"[*] {msg}")

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
    global running
    running = False
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
                                log_status(f"WARNING: EHRPWM0 clock (clk:83:0) is {rate / 1000000:.1f} MHz, not 125.0 MHz.")
                                log_status("The PRU firmware calculations assume a 125 MHz base frequency.")
                                log_status("Physical output frequency will be scaled incorrectly.\n")
                            else:
                                log_status("EHRPWM0 clock is verified at 125.0 MHz.")
                        except ValueError:
                            pass
                    break
    except Exception:
        pass

# Background thread to monitor the DSP live spectrum
def monitor_dsp_trace():
    global running
    last_block = ""
    
    while running:
        if os.path.exists(TRACE_FILE):
            try:
                with open(TRACE_FILE, "r") as f:
                    content = f.read()
                
                # Find the start of the last spectrum block
                marker = "--- Live Spectrum"
                idx = content.rfind(marker)
                if idx != -1:
                    current_block = content[idx:]
                    if current_block != last_block:
                        last_block = current_block
                        # Clear screen for live dashboard look
                        os.system('clear' if os.name == 'posix' else 'cls')
                        print("==========================================================")
                        print("     ICSSG0 PRU1 (Sampler) + C66x DSP (FFT) Dashboard")
                        print("         Loopback Wiring Required: P8_13 -> P8_41")
                        print("==========================================================")
                        print("  To view raw DSP log history, run in another terminal:")
                        print(f"    sudo tail -f {TRACE_FILE}")
                        print("==========================================================")
                        print(f"Current Target Frequency: {current_target_freq_str}")
                        print("----------------------------------------------------------")
                        print(current_block.strip())
                        print("----------------------------------------------------------")
                        print("Recent Actions / System Status:")
                        for log in action_log:
                            print(f"  {log}")
                        print("==========================================================")
                        print("Press Ctrl+C to terminate.")
            except Exception as e:
                # Silently ignore read conflicts during start
                pass
        time.sleep(0.3)

current_target_freq_str = "Sweeping..."

def main():
    global fd, running, current_target_freq_str
    
    parser = argparse.ArgumentParser(description="Control BeagleBone AI-64 EPWM signal and view DSP FFT spectrum.")
    parser.add_argument("--freq", "-f", type=int, help="Target frequency in Hz. If 0, turns PWM off and exits.")
    parser.add_argument("--duration", "-d", type=float, help="Duration in seconds to run. Only applicable with --freq.")
    args = parser.parse_args()

    print("==========================================================")
    print("     ICSSG0 PRU1 (Sampler) + C66x DSP (FFT) Dashboard")
    print("         Loopback Wiring Required: P8_13 -> P8_41")
    print("==========================================================")
    print("  To view raw DSP log history, run in another terminal:")
    print(f"    sudo tail -f {TRACE_FILE}")
    print("==========================================================\n")
    print("[*] Starting in 2 seconds... Open another terminal and run the tail command now!")
    time.sleep(2.0)

    log_status("Checking character device...")
    if not os.path.exists(DEVICE):
        print(f"ERROR: Character device {DEVICE} does not exist.")
        print("Ensure the remoteprocs (RTU0, PRU0, PRU1, and DSP1) are loaded and active.")
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

    # Validate clock rate
    log_status("Validating clock tree configuration...")
    check_clock_rate()

    # Register SIGTERM to raise SystemExit so finally block runs
    signal.signal(signal.SIGTERM, sigterm_handler)

    log_status(f"Opening {DEVICE}...")
    try:
        fd = os.open(DEVICE, os.O_RDWR)
        log_status("Device opened successfully.")
    except PermissionError:
        print(f"Permission denied. Please run with sudo: 'sudo python3 {sys.argv[0]}'")
        sys.exit(1)

    # Start trace monitor thread
    log_status("Starting background trace monitoring thread...")
    monitor_thread = threading.Thread(target=monitor_dsp_trace, daemon=True)
    monitor_thread.start()

    try:
        if args.freq is not None:
            freq = args.freq
            if freq == 0:
                current_target_freq_str = "0 Hz (Forced LOW)"
                log_status("Sending: 0 Hz -> Turning PWM OFF (Forced LOW)")
                os.write(fd, b"0\n")
                response = os.read(fd, 64)
                log_status(f"Response from RTU: {response.decode().strip()}")
                os.close(fd)
                fd = None
                running = False
                return

            current_target_freq_str = f"{freq / 1000000:.3f} MHz"
            log_status(f"Sending target frequency: {freq} Hz ({freq / 1000000:.3f} MHz)...")
            msg = f"{freq}\n"
            os.write(fd, msg.encode())
            response = os.read(fd, 64)
            log_status(f"Response from RTU: {response.decode().strip()}")
            
            if args.duration is not None:
                log_status(f"Running for {args.duration} seconds...")
                time.sleep(args.duration)
                running = False
            else:
                log_status("Running indefinitely. Press Ctrl+C to stop.")
                while running:
                    time.sleep(0.5)
        else:
            # Default: Sweep frequencies from 500 kHz to 9.5 MHz to stay within Nyquist (10 MHz)
            frequencies = [
                500000,   # 0.5 MHz
                1000000,  # 1.0 MHz
                2000000,  # 2.0 MHz
                3000000,  # 3.0 MHz
                4000000,  # 4.0 MHz
                5000000,  # 5.0 MHz
                6000000,  # 6.0 MHz
                7000000,  # 7.0 MHz
                8000000,  # 8.0 MHz
                9000000,  # 9.0 MHz
                5000000,  # 5.0 MHz
                2000000,  # 2.0 MHz
                0         # Off
            ]

            for freq in frequencies:
                if not running:
                    break
                if freq == 0:
                    current_target_freq_str = "0 Hz (Forced LOW)"
                    log_status("Sending: 0 Hz -> Turning PWM OFF (Forced LOW)")
                else:
                    current_target_freq_str = f"{freq / 1000000:.3f} MHz"
                    log_status(f"Sending target frequency: {freq} Hz ({freq / 1000000:.3f} MHz)...")
                
                msg = f"{freq}\n"
                os.write(fd, msg.encode())
                response = os.read(fd, 64)
                log_status(f"Response from RTU: {response.decode().strip()}")
                
                # Observe and hold frequency for 6 seconds to see updates
                for _ in range(12):
                    if not running:
                        break
                    time.sleep(0.5)
                    
            log_status("Sweep completed successfully!")
            os.close(fd)
            fd = None
            running = False
            
    except KeyboardInterrupt:
        log_status("Terminated by user.")
        running = False
    finally:
        stop_pwm_and_exit()

if __name__ == "__main__":
    main()
