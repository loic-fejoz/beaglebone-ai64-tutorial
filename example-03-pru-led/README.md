# Step 3: Blinking LED (PRU)

This step demonstrates how to control physical GPIO pins directly from the PRU using the internal `__R30` output register, how to configure pin multiplexing (pinmux) on the BeagleBone AI-64 expansion headers, and how to safely wire an LED on a breadboard.

---

## 1. Hardware Setup (Wiring the LED)

The Programmable Real-Time Unit (PRU) can toggle pins directly at high speeds, but you must connect your external circuit safely to prevent electrical damage to the TDA4VM SoC.

> [!CAUTION]
> **Electrical Safety Rules:**
> 1. **3.3V Logic Max**: The BeagleBone AI-64 expansion header pins use **3.3V logic levels**. Connecting 5V signals directly to these pins will damage your board.
> 2. **Never Omit the Resistor**: Always use a current-limiting resistor in series with the LED. Connecting an LED directly between a pin and Ground will draw excessive current, potentially burning out the SoC pin or the LED.
> 3. **Power Off**: Always power down your BeagleBone AI-64 before making any hardware connections on the breadboard.

### Pinout Configuration
We will use **Pin 11 on the P8 Header (`P8_11`)** as our output.
- **Output Pin**: `P8_11` (routes to SoC signal `PRG0_PRU0_GPO17`, which is controlled by Bit 17 of the `pru0_0` `__R30` register).
- **Ground Pin**: `P8_01` or `P8_02` (System Ground).

### Resistor Value Calculation
We calculate the current-limiting resistor value using Ohm's Law:

$$R = \frac{V_{pru} - V_f}{I}$$

Where:
- $V_{pru} = 3.3\text{ V}$ (PRU output voltage).
- $V_f \approx 2.0\text{ V}$ (Typical forward voltage drop of a standard red LED).
- $I \approx 5\text{ to }10\text{ mA}$ (Safe and bright target current for the SoC pin).

$$R = \frac{3.3\text{ V} - 2.0\text{ V}}{0.006\text{ A}} \approx 216\ \Omega$$

A **220 $\Omega$** or **330 $\Omega$** resistor is perfect.

### Breadboard Wiring Schematic
1. Connect the **Anode** (longer leg) of the LED to **Pin 11 on the P8 Header (`P8_11`)**.
2. Connect the **Cathode** (shorter leg) of the LED to one side of the **220 $\Omega$ resistor**.
3. Connect the other side of the resistor to **Pin 1 or 2 on the P8 Header (`P8_01` / `P8_02` - GND)**.

```
       [P8_11 Pin] ───(Anode)─── [LED] ───(Cathode)─── [220 Ohm Resistor] ─── [P8_01 (GND)]
```

---

## 2. Pinmux & Device Tree Overlay Configuration

Unlike the BeagleBone Black, the BeagleBone AI-64 does not support dynamic runtime pin multiplexing via `config-pin`. Instead, pinmux settings must be loaded at boot time using a **Device Tree Overlay** (`.dtbo`).

We have created an automated script to handle this configuration over SSH.

### Step-by-Step Overlay Configuration
1. **Build the Overlay**:
   Compile the project on your host PC (see section 4). This automatically compiles the Device Tree overlay source (`bbai64-pru-led.dts`) into the binary overlay (`bbai64-pru-led.dtbo`).
   
2. **Enable the Overlay**:
   Run the `enable_overlay.sh` script to copy the overlay to the board and automatically append it to the `fdtoverlays` entry in your `/boot/firmware/extlinux/extlinux.conf` file:
   ```bash
   ./enable_overlay.sh debian@192.168.1.151
   ```
   *(Enter your sudo password when prompted, or override it by setting the `SUDO_PASS` environment variable).*

3. **Reboot the Board**:
   Restart the BeagleBone AI-64 to apply the configuration:
   ```bash
   ssh debian@192.168.1.151 sudo reboot
   ```
   During boot, U-Boot will read the modified `extlinux.conf` and apply the `bbai64-pru-led.dtbo` overlay, which configures `P8_11` to `pruout` (PRU output) mode.

---

## 3. How the Code Works

The C code in [main-pru.c](file:///home/loic/projets/beaglebone-ai64-tutorial/example-03-pru-led/main-pru.c) consists of three main parts:

### ICSSG Pin Routing Mode (`gpcfg0_reg`)
```c
CT_CFG.gpcfg0_reg = 0;
```
By default, the ICSSG output pins can be routed to internal subsystems (MAC, RTU) or general-purpose outputs. Clearing `gpcfg0_reg` (setting `gp_mux_sel` to `0` for PRU0) connects the GPO register directly to the physical external GPO pins.

### Direct GPIO Control (`__R30`)
```c
volatile register uint32_t __R30;
```
The compiler register variable `__R30` is mapped directly to the PRU's internal output register. Writing to bits of this register instantly drives the corresponding physical GPO pins.
- `__R30 ^= (1 << 17)` toggles bit 17 (linked to `PRG0_PRU0_GPO17` / `P8_11`).

### Cycle-Accurate Delay Loops
```c
__delay_cycles(100000000);
```
`__delay_cycles()` is a compiler intrinsic that stalls execution for the specified number of PRU cycles.
- The PRU on the TDA4VM SoC runs at a constant **200 MHz** (1 cycle = 5 nanoseconds).
- Therefore, a delay of 100,000,000 cycles equals exactly **500 milliseconds** (0.5 seconds), creating a 1 Hz blink rate (500 ms ON, 500 ms OFF).

> [!NOTE]
> **Blocking vs. Non-blocking Delays:**
> While `__delay_cycles()` is simple and perfect for a basic blinky example, it is a **blocking** instruction that consumes 100% of the PRU CPU cycle budget. In real-world projects that perform high-frequency tasks, you should use the PRU's internal **IEP (Industrial Ethernet Peripheral) Timer** to handle non-blocking, interrupt-driven timing.

### Resource Table Boilerplate
```c
struct my_resource_table pru_remoteproc_ResourceTable = { ... }
```
The Linux kernel's `remoteproc` loader expects a special `.resource_table` ELF section in the firmware binary. It uses this to read configuration parameters (like trace buffers or RPMsg communication channels) during boot time. Even though this simple step doesn't use any remote resources, a minimal, empty resource table structure is mandatory for the kernel to load and start the PRU core.

---

## 4. Building, Deploying, and Testing

### 1. Compile the Firmware & Overlay (Host PC)
Run the Docker build wrapper from the root of the project:
```bash
./build.sh all
```
This compiles `pru8-led-fw` and `bbai64-pru-led.dtbo`.

### 2. Configure Board Pinmux (Host PC)
Run the overlay setup script:
```bash
./example-03-pru-led/enable_overlay.sh debian@192.168.1.151
```
Then, reboot your board.

### 3. Deploy and Run the Firmware (Host PC)
Once the board reboots, load and run the PRU firmware:
```bash
./example-03-pru-led/deploy_and_test.sh debian@192.168.1.151
```
The script will load the firmware onto `remoteproc0` (ICSSG0 PRU0), start the core, and inspect `dmesg` to verify success.

Your physical LED should now start blinking at 1 Hz!

---

## 5. Troubleshooting & Bootloader Upgrade

### Issue: Firmware runs, but LED does not blink
If the test script reports `SUCCESS` for loading the firmware, but the physical LED is not blinking, check the pin register multiplexer value:
```bash
# Run the test script on the host PC:
./example-03-pru-led/deploy_and_test.sh debian@192.168.1.151
```
If the script prints a warning like `Pin P8_11 is NOT configured to Mode 0 (pruout)`, then U-Boot failed to load the `.dtbo` overlay.

#### Cause: Outdated U-Boot Bootloader
Older BeagleBone AI-64 factory images (e.g. from January 2022) ship with an outdated U-Boot bootloader that ignores the `fdtoverlays` directive in `/boot/firmware/extlinux/extlinux.conf`. 

#### Resolution: Upgrading U-Boot
To fix this, connect to your BeagleBone board over SSH and run the official bootloader upgrade scripts to flash the updated bootloader to both the eMMC and boot partition:
```bash
# Connect to BeagleBone AI-64 over SSH
ssh debian@192.168.1.151

# Run the upgrade script for the partition:
echo 'temppwd' | sudo -S /opt/u-boot/bb-u-boot-beagleboneai64/install.sh

# Run the upgrade script for the eMMC MBR:
echo 'temppwd' | sudo -S /opt/u-boot/bb-u-boot-beagleboneai64/install-emmc.sh

# Reboot the board to apply changes:
echo 'temppwd' | sudo -S reboot
```
Once the board reboots, the newer U-Boot (August 2025 version or newer) will correctly load and apply the `bbai64-pru-led.dtbo` overlay, routing pin `P8_11` into Mode 0 (`pruout`).

---

## 6. Official Reference Resources

For detailed information on BeagleBone AI-64 expansion headers, pin multiplexer modes, and register-to-PRU mappings, consult the following official documentation and references:

1. **BeagleBone AI-64 Expansion Headers Guide**:
   Detailed pinout mapping tables for the P8 and P9 headers are available in the official [BeagleBoard Expansion Documentation](https://docs.beagleboard.org/boards/beaglebone/ai-64/04-expansion.html).
   
2. **PRU Pin Mappings**:
   * **`P8_11`**: Corresponds to register `0x11c0f4` (offset `0xf4` on `11c000.pinctrl`). In Mode 0, it routes to `PRG0_PRU0_GPO17`. Hence, it requires running firmware on **ICSSG0 PRU0** (`remoteproc0`) and toggling bit 17 of `__R30`.
   * **`P8_10`**: Corresponds to register `0x11c040` (offset `0x40` on `11c000.pinctrl`). In Mode 0, it routes to `PRG1_PRU0_GPO15`. Hence, it requires running firmware on **ICSSG1 PRU0** (`remoteproc6`) and toggling bit 15 of `__R30`.

3. **PRU Core to Linux remoteproc Mapping**:
   * `remoteproc0` -> `b034000.pru` (ICSSG0 PRU0) -> Target: `&pru0_0`
   * `remoteproc3` -> `b038000.pru` (ICSSG0 PRU1) -> Target: `&pru0_1`
   * `remoteproc6` -> `b134000.pru` (ICSSG1 PRU0) -> Target: `&pru1_0`
   * `remoteproc9` -> `b138000.pru` (ICSSG1 PRU1) -> Target: `&pru1_1`

