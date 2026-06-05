/*
 * main-rtu0.c
 * Firmware for J721E RTU0 (ICSSG0 RT_PRU0) core.
 * Receives RPMsg messages from host and writes the target frequency in Hz to Shared RAM.
 */

#include <stdint.h>
#include <string.h>
#include <pru_intc.h>
#include <rsc_types.h>
#include <pru_rpmsg.h>
#include "resource_table_rtu0.h"

volatile register uint32_t __R31;

/* Host-10 Interrupt sets bit 30 in register R31 for RTU cores */
#define HOST_INT                        ((uint32_t) 1 << 30)

/* Event numbers for RTU0 */
#define TO_ARM_HOST                     20
#define FROM_ARM_HOST                   21

#define CHAN_NAME                       "rpmsg-pru"
#define CHAN_PORT                       30
#define CHAN_DESC                       "Channel 30"

#define VIRTIO_CONFIG_S_DRIVER_OK       4

/* Local address of Shared RAM for ICSSG0 (64 KB) */
#define SHARED_RAM_ADDRESS              0x10000
volatile uint32_t *shared_frequency = (volatile uint32_t *)SHARED_RAM_ADDRESS;

uint8_t payload[RPMSG_MESSAGE_SIZE];

/* Lightweight parser for positive integer values */
uint32_t parse_uint32(const char *str, uint16_t max_len) {
    uint32_t val = 0;
    uint8_t digit_found = 0;
    uint16_t i;
    for (i = 0; i < max_len && str[i] != '\0'; i++) {
        char c = str[i];
        if (c >= '0' && c <= '9') {
            val = val * 10 + (c - '0');
            digit_found = 1;
        } else if (c == '\n' || c == '\r' || c == ' ' || c == '\t') {
            if (digit_found) {
                break; // stop on whitespace after the digits
            }
            continue; // skip leading whitespace
        } else {
            break; // Stop on any other character
        }
    }
    return digit_found ? val : 0;
}

/* Lightweight function to format a uint32 into a string */
uint16_t write_uint32_str(char *buf, uint32_t val) {
    char temp[16];
    uint16_t i = 0;
    uint16_t j;
    if (val == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return 1;
    }
    while (val > 0) {
        temp[i++] = '0' + (val % 10);
        val /= 10;
    }
    // Reverse elements to write output
    for (j = 0; j < i; j++) {
        buf[j] = temp[i - 1 - j];
    }
    buf[i] = '\0';
    return i;
}

void main(void)
{
    struct pru_rpmsg_transport transport;
    uint16_t src, dst, len;
    volatile uint8_t *status;

    // Initialize the Shared RAM value to 1000 Hz
    *shared_frequency = 1000;

    /* Clear the status of system event 21 */
    CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;

    /* Make sure the Linux drivers are ready for RPMsg communication */
    status = &resourceTable.rpmsg_vdev.status;
    while (!(*status & VIRTIO_CONFIG_S_DRIVER_OK));

    /* Initialize the RPMsg transport structure */
    pru_rpmsg_init(&transport, &resourceTable.rpmsg_vring0, &resourceTable.rpmsg_vring1, TO_ARM_HOST, FROM_ARM_HOST);

    /* Create the RPMsg channel */
    while (pru_rpmsg_channel(RPMSG_NS_CREATE, &transport, CHAN_NAME, CHAN_DESC, CHAN_PORT) != PRU_RPMSG_SUCCESS);

    while (1) {
        /* Check bit 30 of register R31 to see if ARM has kicked us */
        if (__R31 & HOST_INT) {
            /* Clear the event status */
            CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;
            
            /* Receive all available messages */
            while (pru_rpmsg_receive(&transport, &src, &dst, payload, &len) == PRU_RPMSG_SUCCESS) {
                // Null-terminate payload
                if (len < RPMSG_MESSAGE_SIZE) {
                    payload[len] = '\0';
                } else {
                    payload[RPMSG_MESSAGE_SIZE - 1] = '\0';
                }

                // Parse target frequency
                uint32_t val = parse_uint32((char *)payload, len);
                *shared_frequency = val;

                // Format response string without sprintf
                char response[64] = "Frequency set to: ";
                uint16_t num_len = write_uint32_str(response + 18, val);
                strcpy(response + 18 + num_len, " Hz\n");

                // Send back response
                pru_rpmsg_send(&transport, dst, src, response, strlen(response) + 1);
            }
        }
    }
}
