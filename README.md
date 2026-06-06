# BeagleBone AI 64 Tutorial

A step by step introduction to programming the [BeagleBone AI 64 Tutorial](https://www.beagleboard.org/boards/beaglebone-ai-64) board,
especially with DSP target in mind.

## How to Build

This project supports two compilation workflows: native compilation directly on the BeagleBone board, and cross-compilation on a host PC using Docker.

### 1. Native Compilation (On the BeagleBone AI-64 itself)

Install the necessary TI compilers, support packages, and headers:
```bash
sudo apt update
sudo apt install ti-c7000-cgt-v2.1 ti-c6000-cgt-v8.3 ti-pru-cgt-v2.3 ti-pru-software linux-headers-$(uname -r)
```

Compile all examples from the root of the project:
```bash
make
```
Or build a single example by navigating into its directory and running `make`.

### 2. Cross-Compilation (On a Host Linux PC via Docker)

This method containerizes the exact same compiler toolchain so you can build the firmware on your computer without modifying your host's package manager.

1. **Install Prerequisites**: Install QEMU user emulation so your host can execute ARM64 container instructions:
   ```bash
   sudo apt update
   sudo apt install qemu-user-static binfmt-support
   ```
2. **Build and Compile**: Use the helper script to build the compiler container and run the Makefiles:
   ```bash
   # Compile all examples
   ./build.sh all
   
   # Clean build files
   ./build.sh clean
   
   # Compile a specific example folder
   ./build.sh -C example-00-pru
   ```

## Tutorial Steps

0. [simplest PRU software](./example-00-pru)
1. [Simple Hello World with remoteproc trace](./example-01-pru-hello)
2. [Simplest DSP firmware](./example-02-c6x-dsp/)
3. [Blinking LED (PRU)](./example-03-pru-led/)
4. [Dual Blinking LEDs (PRU Simultaneous Toggling)](./example-04-pru-dual-led/)
5. [Direct Digital Synthesis & RPMsg (PRU + RTU)](./example-05-pru-dds-rtu/)
6. [Hardware-Accelerated Blinking via EPWM (Enhanced PWM)](./example-06-pru-epwm/)


## Inspiration

* https://www.glennklockwood.com/embedded/
* https://markayoder.github.io/PRUCookbook/
* https://github.com/RoSchmi/Beaglebone-PRU-RPMsg-HelloWorld
* https://solidmodeling.calliope.us/index.php/2016/09/11/beaglebone-remoteproc-hello-world/
* https://github.com/PierrickRauby/PRU-RPMsg-Setup-BeagleBoneBlack/blob/master/PRU%20Rpmsg%20documentation.pdf
* https://github.com/kevinacahalan/BeagleBoneAI64_Heterogeneous_App_Example

