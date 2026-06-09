# Step 6: Hardware-Accelerated Blinking via EPWM (Enhanced PWM)

This example demonstrates how to control the BeagleBone AI-64's dedicated **Enhanced High-Resolution Pulse Width Modulation (EHRPWM)** hardware module from the PRU cores. 

By leveraging the hardware PWM controller, we can offload the PRU0 CPU from manually bit-banging pins (which consumes 100% CPU and is timing-sensitive). Instead, the PRU0 core dynamically configures the hardware PWM registers. On the TI TDA4VM SoC, the EHRPWM0 module's functional clock (`fck`, device ID 83 in the device tree `arch/arm64/boot/dts/ti/k3-j721e-main.dtsi`) is configured to run at **125 MHz** by default. With this base clock, the PRU0 core can output stable frequencies ranging from **1.06 Hz to 62.5 MHz** with a 50% duty cycle, while the RTU0 core manages the host-to-coprocessor RPMsg interface.

---

## 1. EPWM Hardware Architecture & Memory Translation (RAT)

On the TI TDA4VM SoC, the EHRPWM modules are standard peripherals located in the SoC's main domain register space. `EHRPWM0` has its base register address at `0x03000000` in the system memory map.

### Region Address Translation (RAT)
The PRU is a 32-bit local Harvard architecture core. To access main domain system peripherals located at physical address `0x03000000`, we must configure a **Region Address Translation (RAT)** window.

* **RemoteProc IOMMU Constraint**: On the AM65x/TDA4VM, the PRU subsystem does not have an IOMMU. Attempting to define mappings in the resource table using `TYPE_DEVMEM` will fail during firmware loading, emitting kernel error: `remoteproc remoteproc0: Failed to process resources: -22`.
* **Manual RAT Configuration**: Instead of resource table entries, program the hardware RAT registers directly from the PRU C code. The RAT configuration registers are located at local address `0x00008000` (mapped to Constant Register 22 in `J721E_PRU0.cmd`).
* **C Register Access Model (`SBCO` vs `SBBO` instructions)**: We must configure the RAT registers using the compiler's `__far` and `cregister` attributes (mapping to `PRU_RTU_RAT0`) to generate `SBCO` instructions. Standard memory pointers map to `SBBO` instructions, which route accesses through the PRU local RAM bus and fail to map to the peripheral configuration space.
* **RAT Region Layout**: The translation regions start at offset `0x20` inside the RAT register block (offsets `0x00` and `0x04` hold the PID and CONFIG registers, respectively). 

For example, to map local `0x60000000` to system physical `0x03000000` (1 MB) using Region 1:
```c
typedef struct {
    volatile uint32_t CTRL;
    volatile uint32_t BASE;
    volatile uint32_t TRANS_L;
    volatile uint32_t TRANS_H;
} rat_region;

typedef struct {
    volatile uint32_t PID;
    volatile uint32_t CONFIG;
    uint32_t rsvd8[6]; /* Offset 0x08 to 0x1f */
    volatile rat_region REGION[16];
} my_rat;

volatile __far my_rat CT_RAT __attribute__ ((cregister("PRU_RTU_RAT0", far), peripheral));

/* Configure Region 1 */
CT_RAT.REGION[1].BASE = 0x60000000;
CT_RAT.REGION[1].TRANS_L = 0x03000000;
CT_RAT.REGION[1].TRANS_H = 0;
CT_RAT.REGION[1].CTRL = (1U << 31) | 19; /* Enable, 1 MB size */
```

NB: Documentation from Zephyr was really usefull here. See https://github.com/zephyrproject-rtos/zephyr/blob/main/drivers/mm/mm_drv_ti_rat.c and https://github.com/zephyrproject-rtos/zephyr/blob/main/include/zephyr/drivers/mm/rat.h

## 2. Critical Pitfall: K3 Clock Gating & Bus Faults

On the AM65x and TDA4VM SoCs, peripherals are aggressively clock-gated by the System Controller (DMSC/TIFS) to save power. 
* If a hardware module is disabled, its registers are inaccessible and the clocks are turned off.
* **The Failure**: If the PRU attempts to read or write to `0x60000000` when `EHRPWM0` is clock-gated, the bus request will timeout and trigger a **bus abort (data exception)**, causing the PRU core to crash instantly.

### The Solution: Linux Kernel Driver Synchronization
To safely enable the `EHRPWM0` peripheral clocks:
1. We enable the `&main_ehrpwm0` node in our device tree overlay (`status = "okay"`), which registers it as a `pwmchipX` in Linux.
2. In the deployment script `deploy_and_test.sh`, we locate the correct `pwmchip` for `3000000.pwm` and export/enable channel 0:
   ```bash
   echo 0 > /sys/class/pwm/pwmchipX/export
   echo 1 > /sys/class/pwm/pwmchipX/pwm0/enable
   ```
This signals the kernel to request the active clock from the system co-processor. Once the clocks are enabled, the PRU can safely manipulate the hardware registers. The hardware runs autonomously, allowing the PRU to overwrite settings with zero interference from Linux.

---

## 3. Register Configuration & Dynamic Divisor Search

We map `P8_13` to Mode 6 (`EHRPWM0_B`). Thus, we utilize channel B registers.

### Action Qualifiers (`AQCTLB` & `AQCSFRC`)
* `AQCTLB = 0x0102`: Action-Qualifier Control B. This configures standard Active-High PWM:
  - When the counter `TBCNT` is `0`, set the output HIGH (`0x2` in bits 1:0).
  - When the counter matches `CMPB` (compare B), clear the output LOW (`0x1` in bits 9:8).
* `AQCSFRC`: Action-Qualifier Continuous Software Force.
  - Frequency `0 Hz` (Off): Set `AQCSFRC = 0x0004` (forces output B continuously low).
  - Frequency `> 0 Hz` (On): Set `AQCSFRC = 0x0000` (disables force, allowing PWM output).

### Dynamic Frequency Scaling (Divisor Search)
The Time-Base Clock (TBCLK) runs at **$125\text{ MHz}$** by default (derived from the SoC's peripheral PLL clock tree, referenced as `clk:83:0` in Linux's `/sys/kernel/debug/clk/clk_summary`). The 16-bit Period Register `TBPRD` has a maximum limit of $65535$. For lower frequencies, the clock divider must be increased.
We use a nested search algorithm in PRU C code to find the smallest clock division factor ($D = \text{CLKDIV} \times \text{HSPCLKDIV}$) that allows the period to fit in 16 bits:

$$\text{divisor} = f_{target} \times D$$

$$\text{TBPRD} = \frac{125,000,000}{\text{divisor}} - 1$$

To prevent integer overflows during calculation, we skip evaluations where $f_{target} > \frac{2^{32}-1}{D}$.
Once found, we update `TBPRD`, set `CMPB = (TBPRD + 1) / 2` (for 50% duty cycle), and write the new dividers to `TBCTL`.

---

## 4. How to Build and Run

### 1. Compile the Firmwares & Overlay
On your Host PC, build the target firmware files and the overlay:
```bash
./build.sh -C example-06-pru-epwm
```

### 2. Copy and Enable the Overlay
Enable the device tree overlay on the board to route pin `P8_13` to Mode 6 (`pwm`):
```bash
./example-06-pru-epwm/enable_overlay.sh debian@192.168.1.151
```
Reboot the board:
```bash
ssh debian@192.168.1.151 sudo reboot
```

### 3. Deploy and Start the Cores
Execute the deployment script to load RTU0 (RPMsg control) and PRU0 (EPWM configuration):
```bash
./example-06-pru-epwm/deploy_and_test.sh debian@192.168.1.151
```
This script will output `SUCCESS: /dev/rpmsg_pru30 is available` and verify `Pin P8_13 (11c168) is set to Mode 6, pwm`.

### 4. Run the Frequency Sweeper

Copy and execute the Python control script on the board:
```bash
scp example-06-pru-epwm/host_control.py debian@192.168.1.151:/tmp/
```

By default, running the script sweeps through a range of frequencies (0 Hz to 50 MHz):
```bash
ssh -t debian@192.168.1.151 "sudo python3 /tmp/host_control.py"
```

You can also specify a fixed target frequency in Hz using the `--freq` (or `-f`) option. Set `--freq 0` to turn the PWM off and exit:
```bash
ssh -t debian@192.168.1.151 "sudo python3 /tmp/host_control.py --freq 10"
```

To run a fixed frequency for a specific duration in seconds and then stop the PWM, add the `--duration` (or `-d`) option:
```bash
ssh -t debian@192.168.1.151 "sudo python3 /tmp/host_control.py --freq 1000 --duration 5"
```

If an LED is connected to `P8_13` (via a suitable resistor), you will see it flash at low frequencies (1–20 Hz), and glow continuously at higher frequencies. On an oscilloscope, you will see a clean, hardware-generated square wave scaling dynamically through the entire frequency range.
The program automatically cleans up and forces the PWM output low when terminating or upon receiving system signals (like SIGINT/Ctrl+C or SIGTERM).
