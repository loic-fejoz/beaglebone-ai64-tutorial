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
[48131.653976] remoteproc remoteproc12: stopped remote processor 4d80800000.dsp
[48131.694744] remoteproc remoteproc12: powering up 4d80800000.dsp
[48131.701136] remoteproc remoteproc12: Booting fw image dsp12-hello, size 62332
[48131.709054] k3-dsp-rproc 4d80800000.dsp: booting DSP core using boot addr = 0xa6201000
[48131.717264] remoteproc remoteproc12: remote processor 4d80800000.dsp is now up
sudo tail /sys/kernel/debug/remoteproc/remoteproc12/trace0
Hello world, I am c66_x!
```

All the trick is to get the proper [linker map file](./J721E_DSP12.cmd). But how to find this information for my actual configuration?

## Appendix

Maybe usefull? How Code Composer Studio (CCS): create a simple firmware:

```
 Invoking: C6000 Compiler
 "C:/ti/ccs1240/ccs/tools/compiler/ti-cgt-c6000_8.3.12/bin/cl6x"
	--include_path="C:/Users/loic/workspace_v12/test-dsp-from-ccs"
	--include_path="C:/ti/ccs1240/ccs/tools/compiler/ti-cgt-c6000_8.3.12/include"
	-g
	--diag_warning=225
	--diag_wrap=off
	--display_error_number
	--preproc_with_compile
	--preproc_dependency="main.d_raw"
	"../main.c"
 Finished building: "../main.c"

 Building target: "test-dsp-from-ccs.out"
 Invoking: C6000 Linker
 "C:/ti/ccs1240/ccs/tools/compiler/ti-cgt-c6000_8.3.12/bin/cl6x"
	-g
	--diag_warning=225
	--diag_wrap=off
	--display_error_number
	-z
	-m"test-dsp-from-ccs.map"
	-i"C:/ti/ccs1240/ccs/tools/compiler/ti-cgt-c6000_8.3.12/lib"
	-i"C:/ti/ccs1240/ccs/tools/compiler/ti-cgt-c6000_8.3.12/include"
	--reread_libs
	--diag_wrap=off
	--display_error_number
	--warn_sections
	--xml_link_info="test-dsp-from-ccs_linkInfo.xml"
	--rom_model
	-o "test-dsp-from-ccs.out"
	"./main.obj"
	-llibc.a 
```