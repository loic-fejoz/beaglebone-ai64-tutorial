# Step 7: Cooperative Spectrum Analyzer (Linux + PRU + RTU + DSP)

This advanced example demonstrates the full heterogeneous potential of the TI TDA4VM SoC on the BeagleBone AI-64. We build a complete, self-contained **Digital Spectrum Analyzer** using cooperative processing across four different cores:

1. **Linux Host (Cortex-A72)**: Runs a Python controller dashboard that sends frequency commands to the generator and reads/displays a live ASCII spectrum analyzer in your terminal.
2. **RTU0 (ICSSG0 RT_PRU0)**: Manages host-to-coprocessor RPMsg messages and writes frequency commands to Shared RAM.
3. **PRU0 (ICSSG0 PRU0)**: Acts as the **Signal Generator**, dynamically configuring the EHRPWM0 hardware registers (outputting on `P8_13`) based on Shared RAM frequency commands.
4. **PRU1 (ICSSG0 PRU1)**: Acts as the **High-Speed Sampler**, reading digital input pin `P8_41` at exactly **20 MSPS** (20 MHz) and streaming sample frames into Shared RAM.
5. **DSP1 (C66x_1 DSP)**: Reads the raw samples from Shared RAM, converts them to floats, computes a **1024-point Cooley-Tukey FFT**, and formats the spectrum into the RemoteProc trace log buffer.

---

## 1. System Architecture & Memory Map

All cores communicate through the **ICSSG0 Shared RAM** (64 KB, base physical address `0x0B010000`). Because the C66x DSP has its lower 256 MB of address space reserved for local memory and internal registers, it cannot access the physical address `0x0B010000` directly. 

To overcome this, the DSP firmware configures its **Region Address Translator (RAT) Region 15** to map the DSP virtual address `0x30000000` to the system physical address `0x0B000000` (1 MB size). 

By partitioning the Shared RAM, we establish lock-free, zero-latency registers:

| Subsystem Offset | System Physical Address | DSP Virtual Address | Variable | Size | Writer | Reader |
|---|---|---|---|---|---|---|
| `0x10000` | `0x0B010000` | `0x30010000` | `shared_frequency` | 4 bytes | RTU0 (RPMsg) | PRU0 (PWM Gen) |
| `0x10004` | `0x0B010004` | `0x30010004` | `sample_ready` | 4 bytes | PRU1 (Sampler) / DSP | PRU1 / DSP |
| `0x10008` | `0x0B010008` | `0x30010008` | `sample_buffer` | 1024 bytes | PRU1 (Sampler) | DSP (FFT) |

```
                       ICSSG0 Subsystem (Physical Base: 0x0B000000)
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌────────────────┐           ┌──────────────┐          ┌────────────────┐  │
│  │   PRU0 Core    │           │   RTU0 Core  │          │   PRU1 Core    │  │
│  │ (PWM Gen P8.13)│           │   (RPMsg)    │          │(Sampler P8.41) │  │
│  └───────┬────────┘           └──────┬───────┘          └───────┬────────┘  │
│          │                           │                          │           │
│          ▼                           ▼                          ▼           │
│  ┌───────────────┐           ┌───────────────┐          ┌───────────────┐   │
│  │  freq (10000) │           │  freq (10000) │          │ ready (10004) │   │
│  └───────┬───────┘           └───────┬───────┘          │ buffer(10008) │   │
│          │                           │                  └───────┬───────┘   │
│          ▼                           ▼                          ▼           │
│         [================= Shared RAM (64 KB) ==================]           │
└─────────────────────────────────────▲───────────────────────────────────────┘
                                      │ (System Physical: 0x0B010000)
                                      ▼
                             ┌─────────────────┐
                             │    C66x DSP     │
                             │ (FFT Engine)    │
                             │   (RAT Map to   │
                             │   0x30010000)   │
                             └────────┬────────┘
                                      │
                                      ▼ (Trace Buffer)
                             ┌─────────────────┐
                             │   Linux Host    │
                             │ (Dashboard UI)  │
                             └─────────────────┘
```

---

## 2. High-Speed 20 MSPS Sampling Loop (PRU1)

The PRU1 core runs a cycle-accurate loop designed to sample the state of `__R31` bit 4 (mapped to physical header pin `P8_41`). 
Since the PRU runs at 200 MHz, 1 cycle is exactly 5 ns. To achieve a **20 MSPS** sampling rate ($50\text{ ns}$ period), the loop must take exactly **10 CPU cycles**:

* **Read & Mask** (`__R31 & (1 << 4)`): ~2 cycles.
* **Store in Shared RAM** (`sample_buffer[i] = val`): ~2 cycles.
* **Loop overhead** (increment and boundary check): ~3 cycles.
* **Compiler padding** (`__delay_cycles(3)`): 3 cycles.
* **Total**: **10 cycles (50 ns)**.

Once 1024 samples are stored, PRU1 raises `sample_ready = 1` and spins until the DSP clears it (`sample_ready = 0`).

---

## 3. FFT Computation & ASCII Spectrogram (C66x DSP)

The C66x DSP core continuously polls the translated virtual address of the flag: `0x30010004` (which translates to physical address `0x0B010004` in the system bus via RAT). 
When `sample_ready` goes to `1`:
1. It copies the 1024 samples from `0x30010008` to its local memory.
2. It resets the flag to `0`, releasing PRU1 to sample the next frame.
3. It converts the 1-bit samples ($0$ or $1$) to float values ($-1.0\text{f}$ and $1.0\text{f}$) to form the real part of a complex array.
4. It performs a **1024-point Radix-2 Cooley-Tukey FFT** directly in C.
5. It computes the magnitude spectrum:
   $$\text{magnitude}[i] = \sqrt{\text{real}[i]^2 + \text{imag}[i]^2}$$
6. Since the input is real, the FFT is symmetric. The DSP analyzes the first 512 bins (covering DC to 10 MHz). It groups these bins into **16 frequency bands of 625 kHz each**, finds the peak band, and formats a visual ASCII horizontal bar graph written directly into its `trace0` logging buffer.

With $f_s = 20\text{ MHz}$ and $N = 1024$ points, the resolution of each bin is:
$$\Delta f = \frac{20,000,000}{1024} \approx 19.53\text{ kHz}$$

---

## 4. How to Build, Wire, and Run

### 1. Wire the Loopback Jumper
Using a female-to-female breadboard jumper wire:
* Connect **`P8_13`** (EPWM0_B output) 
* Directly to **`P8_41`** (PRU1 general-purpose input).

> [!WARNING]
> Ensure you connect `P8_13` to `P8_41` only. Double-check expansion header labels on the BeagleBone AI-64 board. Operating expansion header pins above 3.3V or routing signals incorrectly can permanently damage the SoC.

### 2. Compile the Firmwares & Overlay
On your Host PC, build the firmwares and the overlay:
```bash
./build.sh -C example-07-pru-dsp-fft
```

### 3. Deploy and Start the Cores
Run the deployment script to load U-Boot overlays and start the 4 cores:
```bash
./example-07-pru-dsp-fft/deploy_and_test.sh debian@192.168.1.151
```
This script will load:
- `dsp12-fft` on `remoteproc12` (DSP1)
- `rtu0-rpmsg-fw` on `remoteproc1` (RTU0)
- `pru0-epwm-fw` on `remoteproc0` (PRU0)
- `pru1-sampler-fw` on `remoteproc3` (PRU1)

It also enables the kernel clocks for `main_ehrpwm0` via sysfs and confirms pin multiplexing.

### 4. Run the Spectrum Dashboard
Copy the dashboard script to the board and execute it:
```bash
scp example-07-pru-dsp-fft/host_control.py debian@192.168.1.151:/tmp/
ssh -t debian@192.168.1.151 "sudo python3 /tmp/host_control.py"
```

The script will begin sweeping frequencies from 500 kHz to 9.5 MHz (staying under the 10 MHz Nyquist limit).
In the terminal, you will see a live dashboard updating once per second:

```
==========================================================
     ICSSG0 PRU1 (Sampler) + C66x DSP (FFT) Dashboard
         Loopback Wiring Required: P8_13 -> P8_41
==========================================================
Current Target Frequency: 2.000 MHz
----------------------------------------------------------
--- Live Spectrum (Sampling rate: 20 MSPS) ---
  0.00 -  0.62 MHz : *
  0.62 -  1.25 MHz : *
  1.25 -  1.88 MHz : ***
  1.88 -  2.50 MHz : *************************
  2.50 -  3.12 MHz : *
  3.12 -  3.75 MHz : 
  3.75 -  4.38 MHz : *
  4.38 -  5.00 MHz : *
  5.00 -  5.62 MHz : 
  5.62 -  6.25 MHz : **
  6.25 -  6.88 MHz : 
  6.88 -  7.50 MHz : *
  7.50 -  8.12 MHz : 
  8.12 -  8.75 MHz : 
  8.75 -  9.38 MHz : 
  9.38 - 10.00 MHz : 
>> Peak Frequency detected at: 2.012 MHz (Bin 103, Amplitude: 512.0)
==========================================================
Press Ctrl+C to terminate.
```

As the generator steps through the frequencies, you will see the peak asterisks band move dynamically up and down the spectrum, and the detected peak frequency match the generated signal!
