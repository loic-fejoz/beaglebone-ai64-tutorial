# BeagleBone AI-64 (TI TDA4VM) Technical Reference Guide

This document compiles the hardware specifications, coprocessor architectures, firmware deployment workflows, and pin multiplexing configurations for the BeagleBone AI-64 (BBAI64). It serves as a self-contained guide for future developers and LLM agents working on this platform to avoid redundant web searches.

---

## 1. System & Coprocessor Architecture

The BeagleBone AI-64 is built around the **Texas Instruments TDA4VM SoC** (Jacinto 7 architecture). It features a heterogeneous processor system:
* **Host CPU**: Dual-core ARM Cortex-A72 (64-bit, running Linux).
* **Deep Learning & DSPs**: 
  - 1x C7x DSP with Matrix Multiply Accelerator (MMA).
  - 2x C66x floating-point DSPs.
* **Real-time Control & Networking (PRUs)**:
  - 2x Industrial Communication Subsystems (ICSSG0 and ICSSG1).
  - Each ICSSG contains 2 slices (PRU0 and PRU1), containing a total of 6 programmable cores (2x PRU, 2x RT_PRU, 2x TX_PRU).
* **Main Domain R5F Cores**: 2x dual-core Cortex-R5F clusters (running in lockstep or split mode) for safety and real-time operations.

---

## 2. ICSSG PRU Subsystem Layout

On the TDA4VM SoC, the PRU (Programmable Real-Time Unit) cores are organized under two ICSSG instances. The Linux kernel exposes these cores using the `remoteproc` framework.

### Linux Kernel remoteproc Mapping

Below is the mapping from the Linux `/sys/class/remoteproc/remoteprocX` interfaces to the physical hardware cores and device tree handles:

| remoteproc ID | Hardware Core | Linux Device Tree Node | Kernel Driver Name / Path |
|---|---|---|---|
| `remoteproc0` | **ICSSG0 PRU0** (Slice 0 Coordinator) | `&pru0_0` | `b034000.pru` |
| `remoteproc1` | ICSSG0 RT_PRU0 | `&rtu0_0` | `b034000.rtu` |
| `remoteproc2` | ICSSG0 TX_PRU0 | `&txpru0_0` | `b034000.txpru` |
| `remoteproc3` | **ICSSG0 PRU1** (Slice 0 Worker) | `&pru0_1` | `b038000.pru` |
| `remoteproc4` | ICSSG0 RT_PRU1 | `&rtu0_1` | `b038000.rtu` |
| `remoteproc5` | ICSSG0 TX_PRU1 | `&txpru0_1` | `b038000.txpru` |
| `remoteproc6` | **ICSSG1 PRU0** (Slice 1 Coordinator) | `&pru1_0` | `b134000.pru` |
| `remoteproc7` | ICSSG1 RT_PRU0 | `&rtu1_0` | `b134000.rtu` |
| `remoteproc8` | ICSSG1 TX_PRU0 | `&txpru1_0` | `b134000.txpru` |
| `remoteproc9` | **ICSSG1 PRU1** (Slice 1 Worker) | `&pru1_1` | `b138000.pru` |
| `remoteproc10`| ICSSG1 RT_PRU1 | `&rtu1_1` | `b138000.rtu` |
| `remoteproc11`| ICSSG1 TX_PRU1 | `&txpru1_1` | `b138000.txpru` |

---

## 3. Firmware Management & remoteproc Controls

To interact with the PRU cores from user-space, write commands to the sysfs interface under `/sys/class/remoteproc/remoteprocX/`.

### Deployment Steps
1. **Copy Firmware**: Copy compiled ELF binaries to the target system's firmware directory:
   ```bash
   cp my-fw /lib/firmware/
   ```
2. **Assign Firmware to Core**:
   ```bash
   echo "my-fw" > /sys/class/remoteproc/remoteprocX/firmware
   ```
3. **Control Core State**:
   - **Start**: `echo start > /sys/class/remoteproc/remoteprocX/state`
   - **Stop**: `echo stop > /sys/class/remoteproc/remoteprocX/state`
   - **Check Status**: `cat /sys/class/remoteproc/remoteprocX/state` (returns `running` or `offline`)

---

## 4. Physical Expansion Headers (P8 & P9)

The BBAI64 includes two expansion headers: **P8** (46 pins) and **P9** (50 pins). 

> [!CAUTION]
> ### Electrical Safety Constraints
> 1. **3.3V Logic Level Max**: All expansion pins operate at **3.3V**. Connecting any 5V logic signals will cause irreversible electrical damage to the SoC and void the board's warranty.
> 2. **Reset Timing**: No pins may be driven until after the `SYS_RESET` line goes high during the boot sequence. Do not apply voltage to I/O pins when the board is unpowered.
> 3. **Shorted/Double Pins**: On some cape header pins, multiple SoC pins are shorted together on the board layout. **Only one signal in a shorted group should be multiplexed/active at a time.**

### Controlling GPIO via Command Line
Under Linux, you can control raw GPIO pins using the `gpiod` toolset. Pins are designated by a `gpiochip` index and a relative line number.

For example, to toggle **P8.03** (SoC Ball `AH21` mapped to GPIO chip 1, line 20 / `GPIO0_20`):
```bash
# Drive High (3.3V)
gpioset 1 20=1

# Drive Low (0V)
gpioset 1 20=0
```

### Detailed PRU Pinmux Table

To access the physical pins from the PRUs, the pin control registers must be set to **Mode 0** (`pruout` or `pruin`). Pin register values can be checked under debugfs:
`/sys/kernel/debug/pinctrl/11c000.pinctrl-pinctrl-single/pins`

The table below lists key expansion pins mapped to PRU General Purpose Outputs (`__R30`):

| Header Pin | SoC Ball | Control Register Offset | Mode 0 Function (PRU GPO Mapping) | Linux GPIO |
|---|---|---|---|---|
| **P8.11** | `AB24` | `0x00011C0F4` | `PRG0_PRU0_GPO17` (ICSSG0 PRU0 Bit 17) | `GPIO0_60` (Mode 7) |
| **P8.41** | `AD29` | `0x00011C110` | `PRG0_PRU1_GPO4` (ICSSG0 PRU1 Bit 4) | `GPIO0_67` (Mode 7) |
| **P8.42** | `AB27` | `0x00011C114` | `PRG0_PRU1_GPO5` (ICSSG0 PRU1 Bit 5) | `GPIO0_68` (Mode 7) |
| **P8.10** | `AC24` | `0x00011C040` | `PRG1_PRU0_GPO15` (ICSSG1 PRU0 Bit 15) | `GPIO0_16` (Mode 7) |
| **P9.11** | `AC23` | `0x00011C004` | `PRG1_PRU0_GPO0` (ICSSG1 PRU0 Bit 0) | `GPIO0_1` (Mode 7) |
| **P9.12** | `AE27` | `0x00011C0B8` | `PRG0_PRU0_GPO2` (ICSSG0 PRU0 Bit 2) | `GPIO0_45` (Mode 7) |
| **P9.13** | `AG22` | `0x00011C008` | `PRG1_PRU0_GPO1` (ICSSG1 PRU0 Bit 1) | `GPIO0_2` (Mode 7) |
| **P9.15** | `AD25` | `0x00011C0C0` | `PRG0_PRU0_GPO4` (ICSSG0 PRU0 Bit 4) | `GPIO0_47` (Mode 7) |

See https://docs.beagleboard.org/boards/beaglebone/ai-64/04-expansion.html

---

## 5. Device Tree Overlays & Bootloader Configuration

Unlike older BeagleBones, the BBAI64 does not support dynamic pinmux settings via the `config-pin` utility. Changes must be defined in a Device Tree Overlay source (`.dts`), compiled to a `.dtbo`, and loaded at boot time.

### Writing a DT Overlay (`bbai64-pru-pins.dts`)
To reserve and configure pins, target the pin handle node in the overlay:
```dts
/dts-v1/;
/plugin/;

// Disable default kernel-level device bindings for the pin
&bone_led_P8_11 {
    status = "disabled";
};

// Route pins to the PRU subsystem
&pru0_0 {
    pinctrl-names = "default";
    pinctrl-0 = <&P8_11_pruout_pin>;
};
```

### Compiling DT Overlays
```bash
dtc -@ -I dts -O dtb -o my_overlay.dtbo my_overlay.dts
```

### Enabling DT Overlays in extlinux.conf
The overlays are parsed and loaded by U-Boot at boot time using the `extlinux.conf` file (located at `/boot/firmware/extlinux/extlinux.conf` or `/boot/extlinux/extlinux.conf`).

To enable:
1. Copy the compiled `.dtbo` to `/boot/firmware/overlays/` (or `/boot/overlays/`).
2. Append the overlay path to the `fdtoverlays` entry under the active boot label:
   ```text
   label Linux eMMC
       kernel /Image
       initrd /initrd.img
       fdt /k3-j721e-common-proc-board.dtb
       fdtoverlays /overlays/my_overlay.dtbo
   ```
3. Reboot the board to apply changes.

### Critical Bootloader Upgrade Issue
Older BeagleBone AI-64 factory images (released around January 2022) ship with an outdated U-Boot bootloader that ignores the `fdtoverlays` block in `extlinux.conf`. 

If pinmux checks fail (register is not set to Mode 0 after rebooting), connect via SSH and upgrade the bootloader:
```bash
# Update partition bootloader
sudo /opt/u-boot/bb-u-boot-beagleboneai64/install.sh

# Update eMMC bootloader
sudo /opt/u-boot/bb-u-boot-beagleboneai64/install-emmc.sh

# Reboot to apply
sudo reboot
```

---

## 6. PRU-to-PRU Inter-Core Communication & Memory Sync

Each ICSSG subsystem contains **64KB of Shared RAM** starting at local offset `0x10000`. This shared memory allows two PRU cores in the same cluster to communicate with zero-latency overhead.

```
                  ICSSG Subsystem (e.g. ICSSG0)
┌────────────────────────────────────────────────────────┐
│                                                        │
│  ┌───────────────┐                  ┌───────────────┐  │
│  │   PRU0 Core   │                  │   PRU1 Core   │  │
│  │ (Coordinator) │                  │   (Worker)    │  │
│  └───────┬───────┘                  └───────┬───────┘  │
│          │                                  │          │
│          └─────────► ┌──────────┐ ◄─────────┘          │
│                      │Shared RAM│                      │
│                      │ (64 KB)  │                      │
│                      └──────────┘                      │
└────────────────────────────────────────────────────────┘
```

### Shared Memory Synchronization Pattern
To achieve simultaneous pin toggling across both cores:
1. Define a shared volatile flag struct pointing to the Shared RAM address:
   ```c
   #define SHARED_RAM_ADDRESS 0x10000
   volatile uint32_t *start_flag = (volatile uint32_t *)SHARED_RAM_ADDRESS;
   ```
2. **Boot Order Execution**:
   - Start the Worker core (PRU1) first. It resets `start_flag = 0` and enters a busy-wait spin lock:
     ```c
     *start_flag = 0;
     while (*start_flag == 0) {
         // Wait for coordinator to set flag
     }
     ```
   - Start the Coordinator core (PRU0) second. Once initialized, it raises the flag:
     ```c
     *start_flag = 1;
     ```

### Latency Skew Compensation
When the coordinator releases the flag, the worker core requires a few cycles to break out of the spin loop, load instructions, and perform its first pin write.
* **Without Compensation**: The worker pin toggling lags behind the coordinator pin toggling by several cycles.
* **With Compensation**: Add a hardcoded compiler-level delay in the coordinator core immediately after setting the flag to align both writes:
  ```c
  *start_flag = 1;
  __delay_cycles(7); // Exact skew offset to align both execution paths
  ```

---

## 7. Writing Jitter-Free C Code on the PRU

To prevent timing jitter and cycle variations in high-speed protocols (e.g. Polar Modulation, RF generation), the execution paths of both cores must contain a constant instruction count.

### Rules for PRU C Programming:
1. **Avoid Branching**: Conditional logic (`if/else`) compiles to branches, which can take a variable number of cycles depending on the branch outcome.
2. **Branchless Pin Assignments**: Use logical mask operations to set pin values instead of conditional branches.
   * *Bad (Variable cycle count)*:
     ```c
     if (val) {
         __R30 |= (1 << 17);
     } else {
         __R30 &= ~(1 << 17);
     }
     ```
   * *Good (Constant cycle count)*:
     ```c
     __R30 = (__R30 & ~(1 << 17)) | (val << 17);
     ```
3. **Empty Resource Table Requirement**: The Linux `remoteproc` driver mandates that any loaded ELF binary contain a `.resource_table` section, even if empty. If missing, the kernel will refuse to load the firmware:
   ```c
   #include <rsc_types.h>
   
   struct my_resource_table {
       struct resource_table base;
       uint32_t offset[1];
   };

   #pragma DATA_SECTION(pru_remoteproc_ResourceTable, ".resource_table")
   #pragma RETAIN(pru_remoteproc_ResourceTable)
   struct my_resource_table pru_remoteproc_ResourceTable = {
       { 1, 0, { 0, 0 } },
       { 0 }
   };
   ```

---

## 8. Compiler Toolchain & Development Environment

* **Compiler**: TI's proprietary PRU Compiler (`clpru`) and linker (`lnkpru`).
* **Toolchain Library**: `rtspruv3_le.lib` (runtime support library).
* **Architecture constraints**: The `clpru` compiler is a **32-bit ARM binary** (compiled for 32-bit ARM Linux/hosts).
* **Docker/CI Build Environment**:
  - Running compilation in Docker containers on x86-64 host architectures requires `qemu-user-static` configuration.
  - In GitHub Action pipelines, do **not** restrict the QEMU platform filter strictly to `linux/arm64`. Registering all architectures (specifically `linux/arm/v7` or `arm`) is necessary to execute the 32-bit `clpru` compiler binaries inside the container.

---

## 9. Advanced Coprocessor Pitfalls & Insights (Lessons Learned)

When building complex cooperative real-time applications involving multiple cores (PRU and RTU) and dynamic host interface systems (RPMsg), pay attention to the following architecture-specific details:

### A. RTU-Specific Register and Event Routing
* **Interrupt-to-Bit Mapping**: For RTU (and TX_PRU) cores, host interrupts 10-19 map to **bits 30-39 of register `__R31`** (whereas standard PRU cores map host interrupts 0 and 1 to bits 30 and 31). If you are listening for kicks on RTU0 using Host-10, check bit 30:
  ```c
  #define HOST_INT ((uint32_t) 1 << 30) // Host-10 on RTU
  if (__R31 & HOST_INT) { ... }
  ```
* **System Event Assignments**: In the TI kernel, RTU0 uses system event 20 (`TO_ARM_HOST`) and event 21 (`FROM_ARM_HOST`) for VirtIO vring mailboxes.

### B. Linker Script Segment Failures (`(COPY)` Section)
The RemoteProc driver parses the `.pru_irq_map` section from the ELF file header to configure the interrupt controller (INTC), but it must **not** attempt to load this mapping table into the PRU's physical data memory.
* **The Failure**: If defined as a loadable segment in the linker script, RemoteProc will fail to boot the core, emitting kernel errors:
  `remoteproc remoteproc1: PRU memory copy failed for da 0xXXXX memsz 0xYY`
  `remoteproc remoteproc1: Failed to load program segments: -22`
* **The Fix**: Declare the segment with the `(COPY)` attribute in the linker command script (`.cmd`) to mark the segment as non-loadable (`PT_NULL`):
  ```cmd
  .pru_irq_map (COPY) :
  {
      *(.pru_irq_map)
  }
  ```

### C. C89/C90 Language Standards Constraint
The TI `clpru` compiler enforces C89 constraints by default. Programmers accustomed to modern C/C++ standards must adjust:
* **Scope Declarations**: You cannot declare variables inline inside loops (e.g. `for(int i = 0; ...)`) or midway through blocks. **All variables must be declared at the beginning of the block scope**.
* **GCC Inline Assembly Constraint Limitations**: GCC-style inline assembly operand constraints (like `: "=r"(val)`) are **not** supported by `clpru`. Use only simple single-string `__asm("...")` blocks.

### D. Memory Size Constraints (Avoiding libc calls)
Each PRU/RTU data memory region is extremely small (typically 2 KB to 4 KB per slice partition).
* **Avoid `sprintf` / `atoi` / `sscanf`**: Calling standard library parsing and formatting functions imports extensive helper code from `rtspruv3_le.lib`, inflating the firmware binary size and consuming massive stack space, which can easily overflow the 2 KB DMEM stack limit.
* **The Alternative**: Write custom, lightweight ASCII-to-integer parsers and integer-to-string formatters directly in your source code.

