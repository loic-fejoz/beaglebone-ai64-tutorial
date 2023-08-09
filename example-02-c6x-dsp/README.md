# Example 02 -- First firmware for DSP C6x

Goal is to prepare an empty firmware for C66x_1, aka remoteproc12.

```sh
make debug-dsp12
```

Same as for PRU, we need to map the resource table into its own memory section for remoteproc to be able to retrieve it.
Also, and contrary to PRU compiler, it is important for it to be declared `static const`.

```c
#pragma DATA_SECTION(dsp_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(dsp_remoteproc_ResourceTable)
static const struct my_resource_table dsp_remoteproc_ResourceTable
```

```sh
$ readelf -x .resource_table /lib/firmware/dsp12-hello 

Hex dump of section '.resource_table':
  0xa6100000 01000000 01000000 00000000 00000000 ................
  0xa6100010 14000000 02000000 00008000 00040000 ................
  0xa6100020 00000000 74726163 653a6336 36785f31 ....trace:c66x_1
  0xa6100030 00000000 00000000 00000000 00000000 ................
  0xa6100040 00000000
```

And here we go!

```sh
$ make clean all debug-dsp12 
rm -f dsp12-hello *.o *.obj
cl6x --include_path=/usr/share/ti/cgt-c6x/include --include_path=/usr/share/ti/cgt-c6x/lib --include_path=/usr/lib/ti/pru-software-support-package/include main-dsp.c --output_file main-dsp.o
"main-dsp.c", line 43: warning: statement is unreachable
lnk6x -c --search_path=/usr/share/ti/cgt-c6x/lib  main-dsp.o /usr/share/ti/cgt-c6x/lib/rts6600_elf.lib -o dsp12-hello -m debug-mem.txt J721E_DSP12.cmd
sudo cp dsp12-hello /lib/firmware/dsp12-hello
sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc12/state" ; \
sudo sh -c "echo 'dsp12-hello' > /sys/class/remoteproc/remoteproc12/firmware" && \
sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc12/state"; /bin/true
dmesg | tail -n 5
```
```log
[48131.653976] remoteproc remoteproc12: stopped remote processor 4d80800000.dsp
[48131.694744] remoteproc remoteproc12: powering up 4d80800000.dsp
[48131.701136] remoteproc remoteproc12: Booting fw image dsp12-hello, size 62332
[48131.709054] k3-dsp-rproc 4d80800000.dsp: booting DSP core using boot addr = 0xa6201000
[48131.717264] remoteproc remoteproc12: remote processor 4d80800000.dsp is now up
```
```sh
sudo tail /sys/kernel/debug/remoteproc/remoteproc12/trace0
Hello world, I am c66_x!
```

From the processors view memory map section of the [J721E DRA829/TDA4VM Processors Technical Reference Manual](https://www.ti.com/lit/zip/spruil1), the C66SS0/1 memory map looks like:

![](C66SS.svg)

RAT means Region-based Address translation. It translates 32-bit input address into a 48-bit address.

All the trick is to get the proper [linker map file](./J721E_DSP12.cmd) as displayed after. So basically, we put everything into the `C66_COREPAC_RAT_REGION` (except for the `L2_RAM` that is not used in this example). Probably not optimal for stack and heap but at least it works!

![](./J721E_DSP12.svg)

May you try choosing another region for the resource table result and you will received a `bad phdr da`.

```log
[ 4213.145043] remoteproc remoteproc12: bad phdr da 0xa7100000 mem 0x44
[ 4213.151450] remoteproc remoteproc12: Failed to load program segments: -22
```

You need to adapt the memory mapping to your actual board configuration. The memory configuration you are looking for is simply in the device tree:

```sh
$ ls -1 -d /proc/device-tree/reserved-memory/c66*
/proc/device-tree/reserved-memory/c66-dma-memory@a6000000
/proc/device-tree/reserved-memory/c66-dma-memory@a7000000
/proc/device-tree/reserved-memory/c66-memory@a6100000
/proc/device-tree/reserved-memory/c66-memory@a7100000

$ ls -1 -d /proc/device-tree/__symbols__/*c66*
/proc/device-tree/__symbols__/c66_0
/proc/device-tree/__symbols__/c66_0_dma_memory_region
/proc/device-tree/__symbols__/c66_0_memory_region
/proc/device-tree/__symbols__/c66_1
/proc/device-tree/__symbols__/c66_1_dma_memory_region
/proc/device-tree/__symbols__/c66_1_memory_region
/proc/device-tree/__symbols__/mbox_c66_0
/proc/device-tree/__symbols__/mbox_c66_1

$ cat /proc/device-tree/__symbols__/c66_0_memory_region
/reserved-memory/c66-memory@a6100000
```

or you can retrieve it also from your uboot configuration:

```sh
dtc -I dtb -O dts /boot/dtbs/`uname -r`/ti/k3-j721e-beagleboneai64.dtb > k3-j721e-beagleboneai64.dts
```

```
		dsp@4d80800000 {
			compatible = "ti,j721e-c66-dsp";
			reg = <0x4d 0x80800000 0x00 0x48000 0x4d 0x80e00000 0x00 0x8000 0x4d 0x80f00000 0x00 0x8000>;
			reg-names = "l2sram\0l1pram\0l1dram";
			ti,sci = <0x09>;
			ti,sci-dev-id = <0x8e>;
			ti,sci-proc-ids = <0x03 0xff>;
			resets = <0x1a 0x8e 0x01>;
			firmware-name = "j7-c66_0-fw";
			mboxes = <0x76 0x77>;
			memory-region = <0x78 0x79>;
			phandle = <0x2f1>;
		};

		dsp@4d81800000 {
			compatible = "ti,j721e-c66-dsp";
			reg = <0x4d 0x81800000 0x00 0x48000 0x4d 0x81e00000 0x00 0x8000 0x4d 0x81f00000 0x00 0x8000>;
			reg-names = "l2sram\0l1pram\0l1dram";
			ti,sci = <0x09>;
			ti,sci-dev-id = <0x8f>;
			ti,sci-proc-ids = <0x04 0xff>;
			resets = <0x1a 0x8f 0x01>;
			firmware-name = "j7-c66_1-fw";
			mboxes = <0x76 0x7a>;
			memory-region = <0x7b 0x7c>;
			phandle = <0x2f2>;
		};

		dsp@64800000 {
			compatible = "ti,j721e-c71-dsp";
			reg = <0x00 0x64800000 0x00 0x80000 0x00 0x64e00000 0x00 0xc000>;
			reg-names = "l2sram\0l1dram";
			ti,sci = <0x09>;
			ti,sci-dev-id = <0x0f>;
			ti,sci-proc-ids = <0x30 0xff>;
			resets = <0x1a 0x0f 0x01>;
			firmware-name = "j7-c71_0-fw";
			mboxes = <0x7d 0x7e>;
			memory-region = <0x7f 0x80>;
			phandle = <0x2f3>;
		};
...
		c66-dma-memory@a6000000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa6000000 0x00 0x100000>;
			no-map;
			phandle = <0x7b>;
		};

		c66-memory@a6100000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa6100000 0x00 0xf00000>;
			no-map;
			phandle = <0x79>;
		};

		c66-dma-memory@a7000000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa7000000 0x00 0x100000>;
			no-map;
			phandle = <0x78>;
		};

		c66-memory@a7100000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa7100000 0x00 0xf00000>;
			no-map;
			phandle = <0x7c>;
		};

		c71-dma-memory@a8000000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa8000000 0x00 0x100000>;
			no-map;
			phandle = <0x7f>;
		};

		c71-memory@a8100000 {
			compatible = "shared-dma-pool";
			reg = <0x00 0xa8100000 0x00 0xf00000>;
			no-map;
			phandle = <0x80>;
		};
...
		c66_0 = "/bus@100000/dsp@4d80800000";
		c66_1 = "/bus@100000/dsp@4d81800000";
...
		c66_1_dma_memory_region = "/reserved-memory/c66-dma-memory@a6000000";
		c66_0_memory_region = "/reserved-memory/c66-memory@a6100000";
		c66_0_dma_memory_region = "/reserved-memory/c66-dma-memory@a7000000";
		c66_1_memory_region = "/reserved-memory/c66-memory@a7100000";
		c71_0_dma_memory_region = "/reserved-memory/c71-dma-memory@a8000000";
		c71_0_memory_region = "/reserved-memory/c71-memory@a8100000";
```

So in my case, the following table is a summary of information from device tree. Thus we are able to do the same for the c7x as easily (`make debug-dsp14`) by building the [linker map for the c7x](./J721E_DSP14.cmd).

|          | c66_0      |    c66_1   | c77_0 
|----------|------------|------------|--------
| Local    | 0xa6100000 | 0xa7100000 | 0xa8100000
| DMA      | 0xa6000000 | 0xa7000000 | 0xa8000000
| l2sram   | 0x80800000 | 0x81800000 | 0x64800000
| l1pram   | 0x80e00000 | 0x81e00000 | 
| l1dram   | 0x80f00000 | 0x81f00000 | 0x64e00000