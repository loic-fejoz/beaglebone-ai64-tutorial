# Step 4: Concurrent dual-core PRU execution and shared memory synchronization

Running independent code loops on two PRU cores (`ICSSG0 PRU0` and `ICSSG0 PRU1`) in the same subsystem cluster (ICSSG0) lets you bypass the timing lag of sequential writes. When you bit-bang multiple channels on a single core, each instruction adds latency. Running them on separate, parallel cores solves this.

To keep the outputs aligned, both cores read the same signal pattern from the cluster's shared local RAM and synchronize their start sequence using a memory flag.

---

## Pin routing and hardware constraints

On the BeagleBone AI-64 (TI TDA4VM SoC), the expansion headers connect through a complex pin multiplexer. Unlike the older AM3358 processor on the BeagleBone Black, the TDA4VM pins have fixed hardware paths to specific PRU cores:

*   **P8.41** connects to SoC pad `AD29`. In Mode 0 (`pruout`), this pad routes to **ICSSG0 PRU1** (`PRG0_PRU1_GPO4`).
*   **P8.42** connects to SoC pad `AB27`. In Mode 0 (`pruout`), this pad routes to **ICSSG0 PRU1** (`PRG0_PRU1_GPO5`).

Since both pins belong to the same core (`PRU 1`), you cannot drive them independently from separate PRU cores. Additionally, the GPO0 pins for both cores (`PRG0_PRU0_GPO0` and `PRG0_PRU1_GPO0`) do not route to the physical header at all on this board.

To get true concurrent execution using two PRU cores in the same subsystem cluster, you need to use this mapping:
*   **LED 1**: Driven by **Subsystem 0, PRU 0** (`ICSSG0 PRU0`) using pin **P8_11** (`PRG0_PRU0_GPO17` / bit 17 of `__R30` on PRU0).
*   **LED 2**: Driven by **Subsystem 0, PRU 1** (`ICSSG0 PRU1`) using pin **P8_41** (`PRG0_PRU1_GPO4` / bit 4 of `__R30` on PRU1).

### Breadboard wiring
Connect two parallel LED circuits back to Ground:

```
        [P8_11 Pin] ───(Anode)─── [LED 1] ───(Cathode)─── [220 Ohm Resistor] ───┐
                                                                                ├─── [P8_01 (GND)]
        [P8_41 Pin] ───(Anode)─── [LED 2] ───(Cathode)─── [220 Ohm Resistor] ───┘
```

---

## Device tree overlay (`bbai64-pru-dual-led.dts`)

The overlay file disables default configurations (like the LEDs and keys assigned to P8_11 by the base device tree) and sets the pin multiplexer for both targets:

```dts
/dts-v1/;
/plugin/;

&bone_led_P8_11 {
    status = "disabled";
};

&bone_key_P8_11 {
    status = "disabled";
};

&pru0_0 {
    pinctrl-names = "default";
    pinctrl-0 = <&P8_11_pruout_pin>;
};

&pru0_1 {
    pinctrl-names = "default";
    pinctrl-0 = <&P8_41_pruout_pin>;
};
```
*Note: P8_41 does not have any default conflicts in the base device tree, so it does not need a corresponding disable node.*

---

## Shared memory layout and boot synchronization

The ICSSG0 subsystem has a 64 KB shared RAM block. Both cores access this block at local address `0x10000` (mapped to Constant Register 28).

We map a structure to this base address to store the pattern configurations:

```c
#define SHARED_RAM_BASE 0x10000

typedef struct {
    volatile uint32_t start_flag;
    volatile uint32_t pattern_len;
    volatile uint32_t patterns[16];
} SharedConfig;

volatile SharedConfig *config = (volatile SharedConfig *)SHARED_RAM_BASE;
```

### The synchronization sequence:
1.  **Boot order**: The deployment script starts the worker core (`remoteproc3` / PRU1) first.
2.  **Worker wait**: PRU1 boots and immediately sets `config->start_flag = 0` to clear any leftover flags from previous runs. It then spins in a loop waiting for the flag to change:
    ```c
    config->start_flag = 0;
    while (config->start_flag == 0);
    ```
3.  **Pattern setup**: The coordinator core (`remoteproc0` / PRU0) starts second. It writes the pattern to the shared memory array:
    ```c
    config->pattern_len = 8;
    config->patterns[0] = 1; // High
    config->patterns[1] = 0; // Low
    ...
    ```
4.  **Signal and align**: PRU0 writes `config->start_flag = 1`. Then it pauses for a tiny delay:
    ```c
    config->start_flag = 1;
    __delay_cycles(7);
    ```
    *Why the 7-cycle delay?*
    It takes PRU1 a few clock cycles to read the updated flag from RAM, break out of its spin loop, and initialize its own loop index (`idx = 0`). The 7-cycle delay on PRU0 holds it back just long enough to compensate for this overhead. Once the delay ends, both cores enter their pattern execution loops on the exact same clock cycle.

---

## Branchless code to avoid jitter

High-speed RF or synthesis signals require consistent timing. A standard conditional approach looks like this:

```c
// DO NOT DO THIS
if (val) {
    __R30 |= (1 << 17);
} else {
    __R30 &= ~(1 << 17);
}
```

The compiler translates this into branch instructions (like `QBEQ` or `QBNE`). If the branch is taken, the CPU pipeline flushes, which costs extra clock cycles. Because the path length varies depending on whether the output transitions high or low, you get timing jitter.

To eliminate this, use a branchless bitwise assignment:

*   **PRU0**: `__R30 = (__R30 & ~(1 << 17)) | (val << 17);`
*   **PRU1**: `__R30 = (__R30 & ~(1 << 4)) | (val << 4);`

Since the pattern array contains only `0` and `1`, shifting the value matches the target GPO bit position. This compiles to exactly three deterministic assembly instructions (`AND`, `LSL`/`AND`, and `ORR`). The execution path remains identical on every cycle, giving you jitter-free outputs.

---

## Compiling, deploying, and running

### 1. Compile the firmware (Host PC)
Run the build script to compile the binaries and Device Tree overlay:
```bash
./build.sh -C example-04-pru-dual-led
```
This builds:
*   `pru0-dual-core-fw` (compiled from `main-pru0.c` and linked via `J721E_PRU8.cmd`)
*   `pru1-dual-core-fw` (compiled from `main-pru1.c` and linked via `J721E_PRU9.cmd`)
*   `bbai64-pru-dual-led.dtbo` (compiled from `bbai64-pru-dual-led.dts`)

### 2. Copy and enable the overlay (Host PC)
Deploy the overlay configuration to the board:
```bash
./example-04-pru-dual-led/enable_overlay.sh debian@192.168.1.151
```
Reboot the board to load the overlay:
```bash
ssh debian@192.168.1.151 sudo reboot
```

### 3. Run the test script (Host PC)
Deploy and start both cores:
```bash
./example-04-pru-dual-led/deploy_and_test.sh debian@192.168.1.151
```
The script starts `remoteproc3` first, followed by `remoteproc0`, and checks that `P8_11` and `P8_41` are configured in Mode 0 (`pruout`).

Both LEDs will blink in synchronization.
