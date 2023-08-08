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
$ readelf -x .resource_table /lib/firmware/j7-c66_1-fw.tisdk 

Hex dump of section '.resource_table':
  0xa7100000 01000000 02000000 00000000 00000000 ................
  0xa7100010 18000000 5c000000 03000000 07000000 ....\...........
  0xa7100020 00000000 01000000 00000000 00000000 ................
  0xa7100030 00020000 ffffffff 00100000 00010000 ................
  0xa7100040 01000000 00000000 ffffffff 00100000 ................
  0xa7100050 00010000 02000000 00000000 02000000 ................
  0xa7100060 002058a7 00000800 00000000 74726163 . X.........trac
  0xa7100070 653a7235 66300000 00000000 00000000 e:r5f0..........
  0xa7100080 00000000 00000000 00000000          ............
```

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