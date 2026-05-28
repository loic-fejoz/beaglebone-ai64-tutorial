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

void main(void) {
    /* Clear gpcfg0_reg to route ICSSG0 PRU0 outputs directly to external pins */
    CT_CFG.gpcfg0_reg = 0;

    while (1) {
        /* Toggle GPO 17 (which maps to pin P8_11 in Mode 0) */
        __R30 ^= (1 << 17);
        
        /* Delay for 500 ms (PRU runs at 200 MHz, 100M cycles = 500 ms) */
        __delay_cycles(100000000);
    }
}
