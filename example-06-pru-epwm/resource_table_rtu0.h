/*
 * resource_table_rtu0.h
 * Resource table for J721E RTU0 (ICSSG0 RT_PRU0) core.
 */

#ifndef _RESOURCE_TABLE_RTU0_H_
#define _RESOURCE_TABLE_RTU0_H_

#include <stddef.h>
#include <rsc_types.h>
#include <pru_virtio_ids.h>

#define PRU_RPMSG_VQ0_SIZE      16
#define PRU_RPMSG_VQ1_SIZE      16

#define VIRTIO_RPMSG_F_NS       0
#define RPMSG_PRU_C0_FEATURES   (1 << VIRTIO_RPMSG_F_NS)

struct my_resource_table {
    struct resource_table base;
    uint32_t offset[1]; /* 1 entry: rpmsg_vdev */

    struct fw_rsc_vdev rpmsg_vdev;
    struct fw_rsc_vdev_vring rpmsg_vring0;
    struct fw_rsc_vdev_vring rpmsg_vring1;
};

#pragma DATA_SECTION(resourceTable, ".resource_table")
#pragma RETAIN(resourceTable)
struct my_resource_table resourceTable = {
    1,      /* Resource table version */
    1,      /* Number of entries */
    0, 0,   /* Reserved */
    {
        offsetof(struct my_resource_table, rpmsg_vdev),
    },

    /* RPMsg Virtual Device entry */
    {
        (uint32_t)TYPE_VDEV,
        (uint32_t)VIRTIO_ID_RPMSG,
        (uint32_t)0,
        (uint32_t)RPMSG_PRU_C0_FEATURES,
        (uint32_t)0,
        (uint32_t)0,
        (uint8_t)0,
        (uint8_t)2, /* 2 vrings */
        { (uint8_t)0, (uint8_t)0 }
    },
    /* VRING 0 (RX from host perspective) */
    {
        FW_RSC_ADDR_ANY,
        16,
        PRU_RPMSG_VQ0_SIZE,
        0,
        0
    },
    /* VRING 1 (TX to host perspective) */
    {
        FW_RSC_ADDR_ANY,
        16,
        PRU_RPMSG_VQ1_SIZE,
        0,
        0
    }
};

/*
 * RemoteProc interrupt mappings.
 * Declared in a separate section parsed by the remoteproc kernel driver.
 */
#pragma DATA_SECTION(my_irq_rsc, ".pru_irq_map")
#pragma RETAIN(my_irq_rsc)
struct pru_irq_rsc my_irq_rsc = {
    0, /* type = 0 */
    1, /* Number of system events being mapped */
    {
        {21, 10, 10} /* {system event, channel, host interrupt} */
    }
};

#endif /* _RESOURCE_TABLE_RTU0_H_ */
