/*
 * main-pru0.c
 * Firmware for J721E PRU0 (ICSSG0 PRU0) core.
 * Outputs a 4-bit sawtooth wave on physical pins P8.12, P8.11, P8.15, P8.16.
 * Delay frequency is read dynamically from Shared RAM.
 */

#include <stdint.h>
#include <am65x/pru_cfg.h>
#include <rsc_types.h>


volatile register uint32_t __R30;

/* Local address of Shared RAM for ICSSG0 (64 KB) */
#define SHARED_RAM_ADDRESS              0x10000
volatile uint32_t *shared_frequency = (volatile uint32_t *)SHARED_RAM_ADDRESS;

// Minimal resource table for PRU0 to be loadable by remoteproc
struct my_resource_table {
    struct resource_table base;
    uint32_t offset[1];
};

#pragma DATA_SECTION(pru_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(pru_remoteproc_ResourceTable)
struct my_resource_table pru_remoteproc_ResourceTable = {
    { 1, 0, { 0, 0 } },
    { 0 }
};

void main(void) {
    /* Clear gpcfg to route __R30 directly to external GPO pins */
    CT_CFG.gpcfg0_reg = 0;

    uint8_t count = 0;
    uint32_t delay_cycles = 1000;

    /* Ensure starting state for pins (bits 16, 17, 18, 19 cleared) */
    __R30 &= ~(0xF << 16);

    while (1) {
        /* Read delay cycles dynamically from Shared RAM */
        delay_cycles = *shared_frequency;
        
        /*
         * Write 4-bit count to bits 16-19 of __R30 branchlessly.
         * Bit mappings:
         *   - Bit 16 (P8.12) -> DAC Bit 0 (LSB)
         *   - Bit 17 (P8.11) -> DAC Bit 1
         *   - Bit 18 (P8.15) -> DAC Bit 2
         *   - Bit 19 (P8.16) -> DAC Bit 3 (MSB)
         */
        __R30 = (__R30 & ~(0xF << 16)) | ((count & 0xF) << 16);

        /* Increment counter (4-bit overflow, modulo 16) */
        count = (count + 1) & 0xF;

        /*
         * Dynamic software delay loop:
         * We cannot use the `__delay_cycles()` compiler intrinsic here because
         * it requires a compile-time constant argument. Since the target delay
         * cycles parameter is loaded dynamically from Shared RAM at runtime,
         * we must use a runtime C loop.
         *
         * The NOP inline assembly statement inside the loop prevents the `clpru`
         * compiler's optimizer from deleting the entire block as dead code.
         */
        uint32_t temp = delay_cycles;
        while (temp > 0) {
            temp--;
            __asm("	NOP");
        }

    }
}
