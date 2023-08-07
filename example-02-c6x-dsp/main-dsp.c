#include <stdint.h>
#include <string.h>

#include <stddef.h>

#include <rsc_types.h>

#define DebugP_MEM_LOG_SIZE 1024
__attribute__((section (".log_shared_mem"))) char gDebugMemLog[DebugP_MEM_LOG_SIZE];

struct my_resource_table {
	struct resource_table base;

	uint32_t offset[1]; /* Should match 'num' in actual definition */

    struct fw_rsc_trace trace;
};

#pragma DATA_SECTION(dsp_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(dsp_remoteproc_ResourceTable)
static const struct my_resource_table dsp_remoteproc_ResourceTable = {
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
        (TYPE_TRACE),
        (uint32_t)gDebugMemLog, DebugP_MEM_LOG_SIZE,
        0, "trace:c66x_1",
    },
};

int main(void) {
    strcpy(gDebugMemLog, "Hello world, I am c66_x!\n");
    while (1) {
        
    }
    return 0;
}
