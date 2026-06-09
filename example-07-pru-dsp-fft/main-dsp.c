/*
 * main-dsp.c
 * C66x DSP Firmware for J721E DSP1 (ICSSG0 DSP coordinator / helper).
 * Reads 1-bit samples from PRU Shared RAM, computes a 1024-point FFT,
 * and formats an ASCII bar spectrum into the remoteproc trace buffer.
 */

#include <stdint.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <stdio.h>
#include <rsc_types.h>

#define NUM_SAMPLES     1024
#define LOG2_N          10
#define PI              3.14159265358979323846f

/* RemoteProc Trace Log Configuration (16 KB) */
#define DebugP_MEM_LOG_SIZE 16384
__attribute__((section (".log_shared_mem"))) char gDebugMemLog[DebugP_MEM_LOG_SIZE];
uint32_t gLogOffset = 0;

/* Resource table definition for remoteproc loader */
struct my_resource_table {
    struct resource_table base;
    uint32_t offset[1];
    struct fw_rsc_trace trace;
};

#pragma DATA_SECTION(dsp_remoteproc_ResourceTable, ".resource_table")
#pragma RETAIN(dsp_remoteproc_ResourceTable)
static const struct my_resource_table dsp_remoteproc_ResourceTable = {
    {
        1,  /* Version */
        1,  /* Number of entries */
        { 0U, 0U }
    },
    {
        offsetof(struct my_resource_table, trace),
    },
    {
        (TYPE_TRACE),
        (uint32_t)gDebugMemLog, DebugP_MEM_LOG_SIZE,
        0, "trace:c66x_0",
    },
};

/* Physical address of ICSSG0 Shared RAM mapped via C66x RAT */
#define PHYSICAL_SHARED_RAM_BASE   0x30010000
volatile uint32_t *sample_ready = (volatile uint32_t *)(PHYSICAL_SHARED_RAM_BASE + 4);
volatile uint32_t *sample_buffer = (volatile uint32_t *)(PHYSICAL_SHARED_RAM_BASE + 8);

/* Local buffers for FFT */
float re[NUM_SAMPLES];
float im[NUM_SAMPLES];
float mag[NUM_SAMPLES / 2];

/* Helper to log to remoteproc trace buffer */
void trace_print(const char *msg) {
    uint32_t len = strlen(msg);
    if (gLogOffset + len >= DebugP_MEM_LOG_SIZE - 64) {
        gLogOffset = 0; /* Wrap around */
    }
    memcpy(&gDebugMemLog[gLogOffset], msg, len);
    gLogOffset += len;
    gDebugMemLog[gLogOffset] = '\0';
}

/* Helper to reverse bits */
unsigned int bitReverse(unsigned int x, int log2n) {
    unsigned int n = 0;
    int i;
    for (i = 0; i < log2n; i++) {
        n <<= 1;
        n |= (x & 1);
        x >>= 1;
    }
    return n;
}

/* Cooley-Tukey Radix-2 Decimation-in-Time FFT */
void fft(float *re, float *im, int n, int log2n) {
    int i, j, len, half_len;
    float temp_r, temp_i, angle, wlen_r, wlen_i, w_r, w_i, t_r, t_i, next_w_r, next_w_i;

    /* Bit-reversal permutation */
    for (i = 0; i < n; i++) {
        unsigned int rev = bitReverse(i, log2n);
        if (i < rev) {
            temp_r = re[i];
            temp_i = im[i];
            re[i] = re[rev];
            im[i] = im[rev];
            re[rev] = temp_r;
            im[rev] = temp_i;
        }
    }

    /* Butterfly computation */
    for (len = 2; len <= n; len <<= 1) {
        angle = -2.0f * PI / len;
        wlen_r = cosf(angle);
        wlen_i = sinf(angle);

        for (i = 0; i < n; i += len) {
            w_r = 1.0f;
            w_i = 0.0f;
            half_len = len >> 1;

            for (j = 0; j < half_len; j++) {
                int u = i + j;
                int v = i + j + half_len;

                /* Complex multiply: t = w * v */
                t_r = w_r * re[v] - w_i * im[v];
                t_i = w_r * im[v] + w_i * re[v];

                /* Butterfly update */
                re[v] = re[u] - t_r;
                im[v] = im[u] - t_i;
                re[u] += t_r;
                im[u] += t_i;

                /* Update twiddle factor */
                next_w_r = w_r * wlen_r - w_i * wlen_i;
                next_w_i = w_r * wlen_i + w_i * wlen_r;
                w_r = next_w_r;
                w_i = next_w_i;
            }
        }
    }
}

/* Helper to globally invalidate L1D and L2 caches */
void global_cache_invalidate_all(void) {
    /* Global L2 Cache Invalidate */
    *(volatile uint32_t *)0x01845008 = 1;
    while (*(volatile uint32_t *)0x01845008 & 1) {
        __asm(" NOP");
    }

    /* Global L1D Cache Invalidate */
    *(volatile uint32_t *)0x01845048 = 1;
    while (*(volatile uint32_t *)0x01845048 & 1) {
        __asm(" NOP");
    }
}

/* Delay function (runs on C66x DSP core) */
void delay_ms(uint32_t ms) {
    volatile uint32_t i;
    for (i = 0; i < ms * 1000; i++) {
        __asm(" NOP");
    }
}

int main(void) {
    /* RAT registers pointers (must be declared at the beginning of the block in C89) */
    volatile uint32_t *rat_ctrl    = (volatile uint32_t *)(0x07FF0000 + 0x20 + 15 * 0x10 + 0);
    volatile uint32_t *rat_base    = (volatile uint32_t *)(0x07FF0000 + 0x20 + 15 * 0x10 + 4);
    volatile uint32_t *rat_trans_l = (volatile uint32_t *)(0x07FF0000 + 0x20 + 15 * 0x10 + 8);
    volatile uint32_t *rat_trans_h = (volatile uint32_t *)(0x07FF0000 + 0x20 + 15 * 0x10 + 12);
    volatile uint32_t *dsp_mar48   = (volatile uint32_t *)0x018480C4;
    volatile uint32_t loop_count   = 0;

    /* Program RAT region 15: Map 0x30000000 virtual to 0x0B000000 physical (1 MB) */
    *rat_base    = 0x30000000;
    *rat_trans_l = 0x0B000000;
    *rat_trans_h = 0x00000000;
    *rat_ctrl    = (1U << 31) | 19; /* Enable, 1 MB size */

    /* Disable cache for 0x30000000 - 0x30FFFFFF memory range (MAR48) to ensure cache coherency */
    *dsp_mar48   = 0;

    /* Perform global cache invalidation once at startup to clear any preloaded lines in L1D/L2 */
    global_cache_invalidate_all();

    /* Initialize trace */
    memset(gDebugMemLog, 0, DebugP_MEM_LOG_SIZE);
    trace_print("=== C66x DSP FFT Spectrum Analyzer Started ===\n");
    {
        char debug_buf[128];
        sprintf(debug_buf, "MAR48 address: 0x%08X, value: 0x%08X\n", (uint32_t)dsp_mar48, *dsp_mar48);
        trace_print(debug_buf);
    }
    trace_print("Listening for samples in Shared RAM...\n\n");

    while (1) {
        /* Wait for PRU1 to signal that a frame of samples is ready */
        if (*sample_ready == 1) {
            loop_count++;
            int i;
            uint32_t word;
            float max_val = 0.0f;
            int peak_bin = 0;
            float peak_freq = 0.0f;
            char buf[256];
            int band;

            /* Copy samples from Shared RAM to local float arrays using 32-bit reads to avoid bus error */
            for (i = 0; i < NUM_SAMPLES / 4; i++) {
                word = sample_buffer[i];
                re[4 * i + 0] = (word & 0xFF) ? 1.0f : -1.0f;
                im[4 * i + 0] = 0.0f;
                
                re[4 * i + 1] = ((word >> 8) & 0xFF) ? 1.0f : -1.0f;
                im[4 * i + 1] = 0.0f;
                
                re[4 * i + 2] = ((word >> 16) & 0xFF) ? 1.0f : -1.0f;
                im[4 * i + 2] = 0.0f;
                
                re[4 * i + 3] = ((word >> 24) & 0xFF) ? 1.0f : -1.0f;
                im[4 * i + 3] = 0.0f;
            }

            /* Clear flag to release PRU1 to gather the next batch */
            *sample_ready = 0;

            /* Compute the 1024-point FFT */
            fft(re, im, NUM_SAMPLES, LOG2_N);

            /* Calculate magnitudes for the first 512 frequency bins */
            for (i = 0; i < NUM_SAMPLES / 2; i++) {
                mag[i] = sqrtf(re[i] * re[i] + im[i] * im[i]);
                /* Find peak, skipping DC bin (i = 0) */
                if (i > 0 && mag[i] > max_val) {
                    max_val = mag[i];
                    peak_bin = i;
                }
            }

            /* Convert peak bin to physical frequency:
             * fs = 25 MHz. Peak frequency = bin * (fs / N)
             */
            peak_freq = (float)peak_bin * 25.0f / (float)NUM_SAMPLES; /* in MHz */

            /* Format the spectrum display */
            sprintf(buf, "--- Live Spectrum (Loop %u, Sampling rate: 25 MSPS) ---\n", loop_count);
            trace_print(buf);
            
            /* Group the 512 bins into 16 frequency bands of 781.25 kHz each */
            for (band = 0; band < 16; band++) {
                int start_bin = band * 32;
                float band_max = 0.0f;
                int k;
                int num_stars;
                char stars[32];
                float band_freq_start;

                for (k = 0; k < 32; k++) {
                    if (mag[start_bin + k] > band_max) {
                        band_max = mag[start_bin + k];
                    }
                }

                /* Format bar: scale to 25 asterisks maximum */
                num_stars = (int)(band_max * 25.0f / 1024.0f);
                if (num_stars > 25) num_stars = 25;
                if (num_stars < 0) num_stars = 0;

                for (k = 0; k < num_stars; k++) {
                    stars[k] = '*';
                }
                stars[num_stars] = '\0';

                band_freq_start = (float)band * 25.0f / 32.0f; /* 25 MHz / 32 bands */
                sprintf(buf, " %5.2f - %5.2f MHz : %s\n", band_freq_start, band_freq_start + (25.0f / 32.0f), stars);
                trace_print(buf);
            }

            sprintf(buf, ">> Peak Frequency detected at: %5.3f MHz (Bin %d, Amplitude: %4.1f)\n\n", 
                     peak_freq, peak_bin, max_val);
            trace_print(buf);

            /* Sleep for 1 second to avoid overflowing trace output */
            delay_ms(1000);
        } else {
            /* Small spin lock sleep */
            delay_ms(5);
        }
    }
}
