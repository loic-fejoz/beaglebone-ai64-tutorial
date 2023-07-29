# Example 00 -- Hello from PRU

Architecture looks like:

* Dual Arm core A72
* 6 (=4+2) Arm Cortex R5F
* 2 C66x DSP
* 1 c7x DSP
* GPU PowerVR Rogue 8XE
* ...

![](https://www.ti.com/ds_dgm/images/fbd_sprsp36j.gif)

Out of the box, the beaglebone AI 64 comes with a Debian GNU/Linux 11 (bullseye) but customized. In particular, most of those could (co)processors could be accessed trough `remoteproc`.

`ls -al /sys/class/remoteproc`

```
remoteproc0  -> ../../devices/platform/bus@100000/b000000.icssg/b034000.pru/remoteproc/remoteproc0
remoteproc1  -> ../../devices/platform/bus@100000/b000000.icssg/b004000.rtu/remoteproc/remoteproc1
remoteproc2  -> ../../devices/platform/bus@100000/b000000.icssg/b00a000.txpru/remoteproc/remoteproc2
remoteproc3  -> ../../devices/platform/bus@100000/b000000.icssg/b038000.pru/remoteproc/remoteproc3
remoteproc4  -> ../../devices/platform/bus@100000/b000000.icssg/b006000.rtu/remoteproc/remoteproc4
remoteproc5  -> ../../devices/platform/bus@100000/b000000.icssg/b00c000.txpru/remoteproc/remoteproc5
remoteproc6  -> ../../devices/platform/bus@100000/b100000.icssg/b134000.pru/remoteproc/remoteproc6
remoteproc7  -> ../../devices/platform/bus@100000/b100000.icssg/b104000.rtu/remoteproc/remoteproc7
remoteproc8  -> ../../devices/platform/bus@100000/b100000.icssg/b10a000.txpru/remoteproc/remoteproc8
remoteproc9  -> ../../devices/platform/bus@100000/b100000.icssg/b138000.pru/remoteproc/remoteproc9
remoteproc10 -> ../../devices/platform/bus@100000/b100000.icssg/b106000.rtu/remoteproc/remoteproc10
remoteproc11 -> ../../devices/platform/bus@100000/b100000.icssg/b10c000.txpru/remoteproc/remoteproc11
remoteproc12 -> ../../devices/platform/bus@100000/4d80800000.dsp/remoteproc/remoteproc12
remoteproc13 -> ../../devices/platform/bus@100000/4d81800000.dsp/remoteproc/remoteproc13
remoteproc14 -> ../../devices/platform/bus@100000/64800000.dsp/remoteproc/remoteproc14
remoteproc15 -> ../../devices/platform/bus@100000/bus@100000:bus@28380000/bus@100000:bus@28380000:r5fss@41000000/41000000.r5f/remoteproc/remoteproc15
remoteproc16 -> ../../devices/platform/bus@100000/bus@100000:r5fss@5c00000/5c00000.r5f/remoteproc/remoteproc16
remoteproc17 -> ../../devices/platform/bus@100000/bus@100000:r5fss@5c00000/5d00000.r5f/remoteproc/remoteproc17
remoteproc18 -> ../../devices/platform/bus@100000/bus@100000:r5fss@5e00000/5e00000.r5f/remoteproc/remoteproc18
remoteproc19 -> ../../devices/platform/bus@100000/bus@100000:r5fss@5e00000/5f00000.r5f/remoteproc/remoteproc19
```

DSP core are easily identified:

* c66x => remoteproc 12 and 13
* c77x => remoteproc 14

We also have the 4 SoC PRUs: 0, 3, 6, 9.

`cat /sys/class/remoteproc/remoteproc{0,3,6,9}/firmware` tell us the default firmware they are loading:

 ```
j7-pru0_0-fw
j7-pru0_1-fw
j7-pru1_0-fw
j7-pru1_1-fw
```

`PRU0_0` seems to be used for power management so let's use `remoteproc9`, aka `PRU1_1`, aka `b138000.pru`.

Let's build the simplest program we can come with:

```c
#include <stdio.h>

void main(void) {
    __halt();
}
```

To compile it, it is the usual dance for c program except that we need to use the compiler for PRU called `clpru` and the dedicated linker `lnkpru`.

You may then get the following error:

```
error: no input section is linked in
warning: no suitable entry-point found; setting to 0
```

A specifity is that you need to also provide a [command script file for the linker](./J721E_PRU9.cmd) so that it knows how to map things. For now, you can take inspiration from [/usr/lib/ti/pru-software-support-package/examples/j721e/PRU_Halt/J721E_PRU1.cmd](file://usr/lib/ti/pru-software-support-package/examples/j721e/PRU_Halt/J721E_PRU1.cmd).

Have a look at the [Makefile](./Makefile) to have a look at the detailled commands.

Then you need to copy (or soft link) the resulting binary `pru9-fw` into `/lib/firmware/` so as to make it available to the `remoteproc` system.

It is now time to start this firmware with following commands:

```sh
sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc9/state"
sudo sh -c "echo 'pru9-fw' > /sys/class/remoteproc/remoteproc9/firmware"
sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc9/state"
```

If everything goes well, you should be able to witness that with the `dmesg` commands:

```log
[22537.648623] remoteproc remoteproc9: powering up b138000.pru
[22537.654337] remoteproc remoteproc9: Booting fw image pru9-fw, size 22652
[22537.661362] remoteproc remoteproc9: remote processor b138000.pru is now up
```

:partying_face: Congratulation! Time to move to [next step](../example-01-pru-hello/).

If one of the `echo` failed, it probably means you got the linker script wrong.

For instance:

```
$echo start > /sys/class/remoteproc/remoteproc9/state
echo: write error: Invalid argument
```

```log
[ 9678.461729] remoteproc remoteproc9: powering up b138000.pru
[ 9678.467647] remoteproc remoteproc9: Booting fw image pru9-fw, size 275868
[ 9678.474502] remoteproc remoteproc9: bad phdr da 0x0 mem 0x5800
[ 9678.480371] remoteproc remoteproc9: Failed to load program segments: -22
[ 9678.487104] remoteproc remoteproc9: Boot failed: -22
```