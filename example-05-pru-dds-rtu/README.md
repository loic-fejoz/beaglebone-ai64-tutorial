# Step 5 & 6: Cooperative Waveform Generator with RPMsg Dynamic Tuning

This example demonstrates how to build a 4-bit **R-2R Resistor Ladder Digital-to-Analog Converter (DAC)** and drive it using a cooperative, split-core real-time architecture inside the ICSSG0 subsystem.

---

## 1. Cooperative Architecture & Shared RAM Details

In high-speed, real-time signal generation, execution timing must be absolutely predictable. If a single core tries to generate a high-speed wave *and* process asynchronous communication (like incoming RPMsg mailboxes), the timing loop will suffer from **interrupt latency jitter** whenever a message arrives.

To solve this, we divide labor between two separate cores in the same ICSSG0 cluster:
1. **PRU0 Core** (`remoteproc0` / `pru0-dds-fw`): Runs a tight, branchless output loop that reads a delay parameter from a specific memory address and drives the output pins. It is completely dedicated to timing and is never interrupted.
2. **RTU0 Core** (`remoteproc1` / `rtu0-rpmsg-fw`): Manages the VirtIO RPMsg framework, listens for incoming frequency tuning words from Linux, parses them, and updates the delay parameter at the shared memory address.

### The Shared RAM Bridge
Both cores have concurrent, zero-latency access to the subsystem's **64 KB Local Shared RAM** located at offset `0x10000` in the PRU/RTU local address space. This memory acts as a lock-free, zero-overhead bridge:
* RTU0 writes the value: `*shared_frequency = val;`
* PRU0 reads the value: `delay_cycles = *shared_frequency;`

---

## 2. Hardware Theory: The 4-Bit R-2R Resistor Ladder

An **R-2R Resistor Ladder** is a simple, highly effective circuit that implements digital-to-analog conversion using only two values of resistors: $R$ and $2R$.

```
  [P8_16 (D3 - MSB)] ────[ 2R ]────┐
                                   ├───[ R ]───┐
  [P8_15 (D2)] ──────────[ 2R ]────┘           ├───[ R ]───┐
                                               │           ├───[ R ]───┐
  [P8_11 (D1)] ──────────[ 2R ]────────────────┘           │           │
                                                           │           ├───► [ Analog Output ]
  [P8_12 (D0 - LSB)] ────[ 2R ]─────────────────────────────┘           │
                                                                       [ 2R ]
                                                                       │
  [P8_01 (GND)] ───────────────────────────────────────────────────────┴───► [ GND Output ]
```

### The Physics of the Ladder
At any node in the ladder, looking back toward the inputs, the **Thévenin equivalent resistance** is exactly $R$. 
* The input pins act as voltage sources ($0\text{ V}$ or $3.3\text{ V}$).
* The binary weights are achieved because the current splits equally at each node (half going to the right, and half going down).
* The final output voltage equation is:
  
  $$V_{out} = V_{ref} \times \frac{D_3 \cdot 2^3 + D_2 \cdot 2^2 + D_1 \cdot 2^1 + D_0 \cdot 2^0}{16}$$

  With $V_{ref} = 3.3\text{ V}$ (the PRU high output level), this yields 16 discrete analog steps ranging from $0\text{ V}$ (digital `0000`) up to $3.09\text{ V}$ (digital `1111` or $\frac{15}{16} \cdot 3.3\text{ V}$).

### Practical Resistor Selection & Impedance Loading
* **Typical Values**: Choose $R = 1\text{ k}\Omega$ and $2R = 2\text{ k}\Omega$ (or $10\text{ k}\Omega$ and $20\text{ k}\Omega$). Using 1% tolerance metal film resistors is recommended to prevent step size non-linearity.
* **Output Impedance**: The Thévenin output impedance of an R-2R ladder is always equal to $R$, regardless of the digital input pattern.
* **Loading Effects**: If you connect a low-impedance load (like a speaker or headphones) directly to the output, the load will draw current, distorting the divider network and causing the voltage steps to collapse. In professional circuits, an **Op-Amp Voltage Follower (Buffer)** is connected to the output to provide high input impedance and low output impedance.

---

## 3. Linker Memory Partitioning & Interrupt Maps

Unlike standard application binaries, microcontroller and coprocessor development requires strict management of physical memory.

### DMEM Core Partitions for RTU0
The RTU0 core has access to two Local Data RAM sections: `RTU0_DMEM_0` (2 KB) and `RTU0_DMEM_1` (2 KB). To prevent stack overflows (a common source of silent crashes in embedded systems), we partition our memory sections in [J721E_RTU0.cmd](file:///home/loic/projets/beaglebone-ai64-tutorial/example-05-pru-dds-rtu/J721E_RTU0.cmd):
* **`.stack` section**: Placed in `RTU0_DMEM_1` (PAGE 1), giving the call stack a dedicated 2 KB region.
* **`.bss`, `.data`, and `.cio` sections**: Placed in `RTU0_DMEM_0` (PAGE 1), keeping static data isolated from the active stack pointer.

### Interrupt Mapping and `(COPY)` Sections
To enable RemoteProc interrupts (which Linux uses to notify the RTU core that it has sent an RPMsg), we define the interrupt controller resource map in our code.
However, this structure `my_irq_rsc` is parsed by the Linux kernel **directly from the ELF headers** on the host's filesystem, and it should not be loaded into the PRU's physical data memory.
In the linker script, we use the `(COPY)` attribute:
```cmd
    .pru_irq_map (COPY) :
    {
        *(.pru_irq_map)
    }
```
`(COPY)` flags this segment as **non-loadable** in the ELF program headers. If you omit `(COPY)`, the RemoteProc loader will attempt to write the IRQ table bytes into the RTU's data memory during boot, which will fail with a kernel memory copy error (`PRU memory copy failed for da 0x1250`).

---

## 4. Software Timing Loops & C89 Compiler Constraints

### Why a C Loop instead of `__delay_cycles`?
The `__delay_cycles(const)` intrinsic is a compiler-specific macro that inserts a precise sequence of static instructions. It requires a **compile-time constant** argument.
Because the delay cycles in our program are adjusted dynamically at runtime via RPMsg, we must write a variable loop in C:
```c
volatile uint32_t temp = delay_cycles;
while (temp > 0) {
    temp--;
    __asm("  NOP");
}
```
* **Optimizer Preservation**: The `__asm(" NOP")` instruction is crucial. Since `temp` is a local variable whose final value is never read, a standard compiler optimizer would see this loop as a "no-op" and completely remove it. The inline assembly NOP statement forces the compiler to retain and execute the loop structure.
* **Cycle Predictability**: Each iteration of this loop compiles to a subtract (`sub`), a NOP (`nop`), and a quick conditional branch (`qbne`), taking roughly 3 to 4 clock cycles per loop iteration. At 200 MHz, this translates to 15-20 ns per increment.

### C89 Variable Declaration Constraints
TI's `clpru` compiler enforces C89/C90 standard constraints by default. One of the most important rules of C89 is that **all variables must be declared at the beginning of a block scope** before any executable code statements.
* *Incorrect (C99 style)*:
  ```c
  for (uint16_t i = 0; i < len; i++) { ... }
  ```
* *Correct (C89 style)*:
  ```c
  uint16_t i;
  for (i = 0; i < len; i++) { ... }
  ```

---

## 5. Linux RPMsg and VirtIO Framework

RPMsg (Remote Processor Messaging) is a standard virtio-based messaging bus that allows the Linux host and the coprocessor cores to communicate over shared memory buffers:

1. **Vrings Allocation**: The Linux kernel allocates shared ring buffers (vring0 and vring1) in host DDR memory.
2. **Kick Notification**:
   - When the host writes to `/dev/rpmsg_pru30`, it places the message in vring0 and triggers a **hardware mailbox kick**.
   - This kick raises system event 21 on the ICSSG interrupt controller, which triggers Host Interrupt 10.
   - The RTU0 core detects this by checking bit 30 of register R31 (`__R31 & (1 << 30)`), clears the interrupt, and reads the buffer using `pru_rpmsg_receive()`.
3. **Response**: The RTU0 core processes the buffer, writes the response to vring1, and calls `pru_rpmsg_send()`, which kicks the host back to trigger a Linux read interrupt.

---

## 6. How to Build and Run

### 1. Compile the Firmwares & Overlay
On your Host PC, run the build script:
```bash
./build.sh example-05-pru-dds-rtu
```
This compiles the sawtooth generator, the RPMsg receiver, and the DTBO.

### 2. Copy and Enable the Overlay
Deploy the DTBO overlay to set the expansion pins to `pruout` Mode 0:
```bash
./example-05-pru-dds-rtu/enable_overlay.sh debian@192.168.1.151
```
Reboot the BeagleBone board to apply:
```bash
ssh debian@192.168.1.151 sudo reboot
```

### 3. Load and Start the Cores
Run the deployment script to load and initialize both cores:
```bash
./example-05-pru-dds-rtu/deploy_and_test.sh debian@192.168.1.151
```
This script starts the RTU0 core first (to announce the `"rpmsg-pru"` channel) and then PRU0. It will output `SUCCESS: /dev/rpmsg_pru30 is available.` if successful.

### 4. Vary the Waveform Frequency dynamically
Copy and run the Python sweeping script on the BeagleBone board to vary the delay dynamically:
```bash
# Copy python script to the board
scp example-05-pru-dds-rtu/host_control.py debian@192.168.1.151:/tmp/

# Run the sweeper script
ssh -t debian@192.168.1.151 "sudo python3 /tmp/host_control.py"
```

You will see the dynamic delay updates printed to the console. If you connect an oscilloscope or multimeter to the R-2R ladder output, you will see the staircase sawtooth waveform frequency scale dynamically in response to your host commands!
