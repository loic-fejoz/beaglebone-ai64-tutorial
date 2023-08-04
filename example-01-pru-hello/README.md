# Example 01 -- Hello from PRU

We would like a first communication from PRU to host. 
The program will simply write a message in a buffer, and we would like `remoteproc` to use this buffer as the trace. 

```c
void main(void) {
    strcpy(gDebugMemLog, "Hello world, I am PRU!\n");
    __halt();
}
```

One should expect to see this trace:

```sh
$sudo tail /sys/kernel/debug/remoteproc/remoteproc9/trace0
Hello world, I am PRU!
```

This trace0 file does not exist until the firmware declare it. For that we will need to declare a resource table and include a trace entry in it. It is actually defined in the resource table as explained in [/usr/lib/ti/pru-software-support-package/include/rsc_types.h](file:///usr/lib/ti/pru-software-support-package/include/rsc_types.h).

```c
#include <rsc_types.h>
struct my_resource_table {
	struct resource_table base;

	uint32_t offset[1]; /* Should match 'num' in actual definition */

    struct fw_rsc_trace trace; // The trace information declaration
};
```

We also need to initialize this resource table with proper information and pointer address:

```c
#pragma DATA_SECTION(pru_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(pru_remoteproc_ResourceTable)
struct my_resource_table pru_remoteproc_ResourceTable = {
    {
        1,	/* we're the first version that implements this */
        1,	/* number of entries in the table */
        { 0U, 0U, } /* reserved, must be zero */
    },
    /* offsets to the entries */
    {
        offsetof(struct my_resource_table, trace),
    },
    {
        (TYPE_TRACE), // type of resource
        (uint32_t)gDebugMemLog, // device address, ie address of the so called shared buffer for trace
        DebugP_MEM_LOG_SIZE, // length (in bytes)
        0, // reserved (must be zero)
        "trace:r5fss1_1", // human-readable name of the trace buffer
    },
};
```

Finally, one need also to declare the buffer:

```c
#define DebugP_MEM_LOG_SIZE 1024
__attribute__((section (".log_shared_mem"))) char gDebugMemLog[DebugP_MEM_LOG_SIZE];
```

Again, we need to define the memory mapping for the table and the shared buffer. The linker script need to be updated with:

```
	.resource_table :
	{
		*(.resource_table*)
	} > PRU1_DMEM_0, PAGE 1

	.log_shared_mem :
	{
		*(.log_shared_mem*)
	} > PRU1_DMEM_1, PAGE 1
```

Time to launch this firmware.

NB: The following command line easy this testing:

```sh
make debug-pru9
```

:partying_face: Congratulation! Time to move to [next step](../example-02-c6x-dsp/).

## References

* https://wiki.st.com/stm32mpu/wiki/Coprocessor_management_troubleshooting_grid
* https://wiki.st.com/stm32mpu/wiki/Coprocessor_resource_table#How_to_add_trace_for_the_log_buffer
* https://github.com/kaofishy/bbai64_cortex-r5_example/blob/main/test.c
* https://github.com/PierrickRauby/PRU-RPMsg-Setup-BeagleBoneBlack/blob/master/Codes/Hello_PRU/resource_table_empty.h