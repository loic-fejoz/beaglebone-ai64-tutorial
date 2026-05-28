#include <stdint.h>
#include <rsc_types.h>
#include <am65x/pru_cfg.h>

/* PRU direct output register */
volatile register uint32_t __R30;

/* Resource table required for remoteproc to load firmware */
struct my_resource_table {
    struct resource_table base;
    uint32_t offset[1];
};

#pragma DATA_SECTION(pru_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(pru_remoteproc_ResourceTable)
struct my_resource_table pru_remoteproc_ResourceTable = {
    {
        1,      /* Resource table version */
        0,      /* Number of entries (empty, no trace/RPMsg in this basic step) */
        { 0, 0 }
    },
    { 0 }
};

#define SHARED_RAM_BASE 0x10000

typedef struct {
    volatile uint32_t start_flag;
    volatile uint32_t pattern_len;
    volatile uint32_t patterns[16];
} SharedConfig;

volatile SharedConfig *config = (volatile SharedConfig *)SHARED_RAM_BASE;

void main(void) {
    /* Clear gpcfg0_reg to route ICSSG0 outputs directly to external pins */
    CT_CFG.gpcfg0_reg = 0;

    /* Initialize shared memory pattern */
    config->pattern_len = 8;
    config->patterns[0] = 1;
    config->patterns[1] = 0;
    config->patterns[2] = 1;
    config->patterns[3] = 1;
    config->patterns[4] = 0;
    config->patterns[5] = 1;
    config->patterns[6] = 0;
    config->patterns[7] = 0;

    /* Signal PRU1 to start.
     * PRU1 was started first by remoteproc and is already spinning waiting for this flag. */
    config->start_flag = 1;

    /* Compensation Delay:
     * We wait exactly 7 cycles here. This offsets the time it takes PRU1
     * to read the start flag, break out of its spin loop, and initialize
     * its loop variables, aligning both GPO writes to the exact same cycle. */
    __delay_cycles(7);

    uint32_t idx = 0;
    while (1) {
        // Read pattern from shared local memory space
        uint32_t val = config->patterns[idx];
        
        // Branchless assignment to Bit 17 (P8_11) to eliminate branch jitter
        __R30 = (__R30 & ~(1 << 17)) | (val << 17);
        
        idx = (idx + 1) % config->pattern_len;
        
        /* Delay 100 ms (20M cycles at 200 MHz) */
        __delay_cycles(20000000);
    }
}
