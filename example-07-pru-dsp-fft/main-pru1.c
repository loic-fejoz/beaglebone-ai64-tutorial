/*
 * main-pru1.c
 * Sampler firmware for J721E PRU1 (ICSSG0 PRU1) core.
 * Samples input pin P8_41 (GPI Bit 4) at 25 MHz and writes to Shared RAM.
 */

#include <stdint.h>
#include <stddef.h>
#include <am65x/pru_cfg.h>
#include <rsc_types.h>

volatile register uint32_t __R31;

#define NUM_SAMPLES 1024

/* Local addresses in ICSSG0 Shared RAM */
#define SHARED_RAM_BASE       0x10000
volatile uint32_t *sample_ready = (volatile uint32_t *)(SHARED_RAM_BASE + 4);
volatile uint8_t *sample_buffer = (volatile uint8_t *)(SHARED_RAM_BASE + 8);

/* Minimal resource table to satisfy remoteproc loader */
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
    /* Clear CFG gpcfg to allow direct input mapping */
    CT_CFG.gpcfg1_reg = 0;

    /* Initialize flag */
    *sample_ready = 0;

    while (1) {
        /* Wait for DSP to process previous frame and clear the flag */
        while (*sample_ready == 1) {
            __delay_cycles(2);
        }

        /* Inline assembly sampling loop to ensure exactly 10 cycles per iteration (20 MSPS)
         * Instruction analysis:
         * 1. AND r4, r31, 0x10         -> 1 cycle (Read P8_41 / GPI bit 4)
         * 2. SBBO &r4, r2, 0, 1        -> 1 cycle (Store byte to Shared RAM)
         * 3. ADD r2, r2, 1             -> 1 cycle (Increment address pointer)
         * 4-7. NOP                     -> 4 cycles (Delay to meet 10-cycle budget)
         * 8. SUB r3, r3, 1             -> 1 cycle (Decrement loop counter)
         * 9. QBNE sample_loop, r3, 0   -> 2 cycles (taken branch) / 1 cycle (non-taken branch)
         * Total: 10 cycles per iteration (50 ns @ 200 MHz).
         */
        __asm("    LDI32   r2, 0x10008\n"       /* r2 = sample_buffer address */
              "    LDI     r3, 1024\n"          /* r3 = loop counter (NUM_SAMPLES) */
              "sample_loop:\n"
              "    AND     r4, r31, 0x10\n"     /* Read P8_41 and mask */
              "    SBBO    &r4, r2, 0, 1\n"     /* Store 1 byte to Shared RAM */
              "    ADD     r2, r2, 1\n"         /* Increment address pointer */
              "    NOP\n"
              "    NOP\n"
              "    NOP\n"
              "    NOP\n"
              "    SUB     r3, r3, 1\n"         /* Decrement loop counter */
              "    QBNE    sample_loop, r3, 0\n");

        /* Signal DSP that a new frame is ready */
        *sample_ready = 1;
    }
}
