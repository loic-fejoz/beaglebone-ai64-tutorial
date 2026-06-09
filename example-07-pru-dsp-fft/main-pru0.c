/*
 * main-pru0.c
 * Firmware for J721E PRU0 (ICSSG0 PRU0) core.
 * Configures and updates the hardware EPWM0_B module (physical pin P8.13)
 * based on the target frequency read dynamically from Shared RAM.
 */

#include <stdint.h>
#include <stddef.h>
#include <am65x/pru_cfg.h>
#include <rsc_types.h>

/* Local address of Shared RAM for ICSSG0 (64 KB) */
#define SHARED_RAM_ADDRESS              0x10000
volatile uint32_t *shared_frequency = (volatile uint32_t *)SHARED_RAM_ADDRESS;

/* Base address where we map the EHRPWM0 registers via RAT */
#define EPWM0_BASE                      0x60000000

/* Register map for TI eHRPWM module */
typedef struct {
    volatile uint16_t TBCTL;   /* Time-Base Control (0x00) */
    volatile uint16_t TBSTS;   /* Time-Base Status (0x02) */
    volatile uint16_t TBPHSHR; /* Time-Base Phase High Resolution (0x04) */
    volatile uint16_t TBPHS;   /* Time-Base Phase (0x06) */
    volatile uint16_t TBCNT;   /* Time-Base Counter (0x08) */
    volatile uint16_t TBPRD;   /* Time-Base Period (0x0A) */
    uint16_t rsvd0C;           /* Reserved (0x0C) */
    volatile uint16_t CMPCTL;  /* Counter-Compare Control (0x0E) */
    volatile uint16_t CMPAHR;  /* Counter-Compare A High Resolution (0x10) */
    volatile uint16_t CMPA;    /* Counter-Compare A (0x12) */
    volatile uint16_t CMPB;    /* Counter-Compare B (0x14) */
    volatile uint16_t AQCTLA;  /* Action-Qualifier Control A (0x16) */
    volatile uint16_t AQCTLB;  /* Action-Qualifier Control B (0x18) */
    volatile uint16_t AQSFRC;  /* Action-Qualifier Software Force (0x1A) */
    volatile uint16_t AQCSFRC; /* Action-Qualifier Continuous S/W Force (0x1C) */
    volatile uint16_t DBCTL;   /* Dead-Band Control (0x1E) */
    volatile uint16_t DBRED;   /* Dead-Band Rising Edge Delay (0x20) */
    volatile uint16_t DBFED;   /* Dead-Band Falling Edge Delay (0x22) */
    volatile uint16_t TZSEL;   /* Trip-Zone Select (0x24) */
    uint16_t rsvd26;           /* Reserved (0x26) */
    volatile uint16_t TZCTL;   /* Trip-Zone Control (0x28) */
    volatile uint16_t TZEINT;  /* Trip-Zone Enable Interrupt (0x2A) */
    volatile uint16_t TZFLG;   /* Trip-Zone Flag (0x2C) */
    volatile uint16_t TZCLR;   /* Trip-Zone Clear (0x2E) */
    volatile uint16_t TZFRC;   /* Trip-Zone Force (0x30) */
    volatile uint16_t ETSEL;   /* Event-Trigger Select (0x32) */
    volatile uint16_t ETPS;    /* Event-Trigger Prescale (0x34) */
    volatile uint16_t ETFLG;   /* Event-Trigger Flag (0x36) */
    volatile uint16_t ETCLR;   /* Event-Trigger Clear (0x38) */
    volatile uint16_t ETFRC;   /* Event-Trigger Force (0x3A) */
    volatile uint16_t PCCTL;   /* PWM-Chopper Control (0x3C) */
} sys_pwmss_regs;

#define EPWM0 (*((volatile sys_pwmss_regs*)EPWM0_BASE))

/* RAT structure for manual address translation configuration */
typedef struct {
    volatile uint32_t CTRL;
    volatile uint32_t BASE;
    volatile uint32_t TRANS_L;
    volatile uint32_t TRANS_H;
} rat_region;

typedef struct {
    volatile uint32_t PID;
    volatile uint32_t CONFIG;
    uint32_t rsvd8[6]; /* Offset 0x08 to 0x1f */
    volatile rat_region REGION[16];
} my_rat;

volatile __far my_rat CT_RAT __attribute__ ((cregister("PRU_RTU_RAT0", far), peripheral));

/* Minimal empty resource table to be loadable by remoteproc */
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
    /* Configure RAT Region 1: Map local 0x60000000 -> physical 0x03000000 (1 MB) */
    CT_RAT.REGION[1].BASE = 0x60000000;
    CT_RAT.REGION[1].TRANS_L = 0x03000000;
    CT_RAT.REGION[1].TRANS_H = 0;
    CT_RAT.REGION[1].CTRL = (1U << 31) | 19; /* Enable, 1 MB size */

    /* Clear gpcfg to route GPO pins directly */
    CT_CFG.gpcfg0_reg = 0;

    volatile sys_pwmss_regs *epwm = &EPWM0;

    /* Initialize EHRPWM0 */
    epwm->CMPCTL = 0x0000;    /* Shadow mode active, loaded on TBCNT=0 */
    epwm->AQCTLB = 0x0102;    /* ZRO = Set HIGH, CBU = Clear LOW (for EPWM0_B) */
    epwm->TBCNT = 0;          /* Initialize counter */
    epwm->TBPRD = 12499;      /* Default 10 kHz (with 125 MHz clock) */
    epwm->CMPB = 6250;        /* 50% duty cycle */
    epwm->AQCSFRC = 0x0004;   /* Start with software force LOW (disabled) */
    epwm->TBCTL = (0x3 << 14) | (0x3 << 4) | 0x0; /* Free run, SYNCOSEL=disabled, Up-count */

    uint32_t last_freq = 0xFFFFFFFF;

    while (1) {
        /* Read frequency dynamically from Shared RAM */
        uint32_t freq = *shared_frequency;

        if (freq != last_freq) {
            last_freq = freq;

            if (freq == 0) {
                /* Force output B low */
                epwm->AQCSFRC = 0x0004;
            } else {
                /* Disable software force (normal PWM enabled) */
                epwm->AQCSFRC = 0x0000;

                /* Cap frequency at 62.5 MHz (since input clock is 125 MHz) */
                if (freq > 62500000) {
                    freq = 62500000;
                }

                /* Find the optimal clock division factor (CLKDIV * HSPCLKDIV)
                 * that makes TBPRD fit in a 16-bit register.
                 */
                uint32_t best_clkdiv = 0;
                uint32_t best_hspclkdiv = 0;
                uint32_t best_tbprd = 0;
                uint32_t best_div = 1792; /* Max possible divider (128 * 14) */

                uint32_t c_div_idx, h_div_idx;
                for (c_div_idx = 0; c_div_idx < 8; c_div_idx++) {
                    uint32_t c_div = 1 << c_div_idx;
                    for (h_div_idx = 0; h_div_idx < 8; h_div_idx++) {
                        uint32_t h_div = (h_div_idx == 0) ? 1 : 2 * h_div_idx;
                        uint32_t total_div = c_div * h_div;

                        /* Avoid division by zero and overflow */
                        if (freq > 4294967295 / total_div) continue;

                        uint32_t divisor = freq * total_div;
                        uint32_t prd = 125000000 / divisor;

                        if (prd <= 65536) {
                            if (total_div < best_div) {
                                best_div = total_div;
                                best_clkdiv = c_div_idx;
                                best_hspclkdiv = h_div_idx;
                                best_tbprd = prd;
                            }
                        }
                    }
                }

                if (best_tbprd > 0) {
                    uint32_t tbprd_val = best_tbprd - 1;
                    if (tbprd_val > 65535) {
                        tbprd_val = 65535;
                    }
                    uint32_t cmpb_val = (best_tbprd) / 2;

                    /* Set period and duty cycle */
                    epwm->TBPRD = (uint16_t)tbprd_val;
                    epwm->CMPB = (uint16_t)cmpb_val;

                    /* Write dividers to TBCTL:
                     * CLKDIV is in bits 12:10, HSPCLKDIV is in bits 9:7
                     */
                    uint16_t tbctl_val = epwm->TBCTL;
                    tbctl_val &= ~((0x7 << 10) | (0x7 << 7));
                    tbctl_val |= (best_clkdiv << 10) | (best_hspclkdiv << 7);
                    epwm->TBCTL = tbctl_val;

                    /* Force counter reset to apply changes instantly */
                    epwm->TBCNT = 0;
                }
            }
        }
        __delay_cycles(20000); /* Check every 100 microseconds */
    }
}
