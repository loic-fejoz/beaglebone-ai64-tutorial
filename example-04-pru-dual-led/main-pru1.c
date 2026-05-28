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
    config->start_flag = 0;
    /* Wait for PRU0 to set start flag */
    while (config->start_flag == 0) {
        // Spin
    }

    uint32_t idx = 0;
    while (1) {
        // Read pattern from shared local memory space
        uint32_t val = config->patterns[idx];
        
        // Branchless assignment to Bit 4 (P8_41) to eliminate branch jitter
        __R30 = (__R30 & ~(1 << 4)) | (val << 4);
        
        idx = (idx + 1) % config->pattern_len;
        
        /* Delay 100 ms (20M cycles at 200 MHz) */
        __delay_cycles(20000000);
    }
}
