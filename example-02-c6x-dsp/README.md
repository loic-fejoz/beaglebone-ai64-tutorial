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

How to find this information for my actual configuration?
For instance, choosing another region for the resource table result in having a `bad phdr da`.

```log
[ 4213.145043] remoteproc remoteproc12: bad phdr da 0xa7100000 mem 0x44
[ 4213.151450] remoteproc remoteproc12: Failed to load program segments: -22
```