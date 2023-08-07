/* 
 * This file is derived from:
 * https://git.ti.com/cgit/processor-sdk/vision_apps/tree/platform/j721e/rtos/c66x_1/linker_mem_map.cmd?h=main
 * and
 * https://git.ti.com/cgit/processor-sdk/vision_apps/tree/platform/j721e/rtos/c66x_1/j721e_linker_freertos.cmd?h=main
 */ 
/* 
 * 
 * Copyright (c) 2018 Texas Instruments Incorporated 
 * 
 * All rights reserved not granted herein. 
 * 
 * Limited License. 
 * 
 * Texas Instruments Incorporated grants a world-wide, royalty-free, non-exclusive 
 * license under copyrights and patents it now or hereafter owns or controls to make, 
 * have made, use, import, offer to sell and sell ("Utilize") this software subject to the 
 * terms herein.  With respect to the foregoing patent license, such license is granted 
 * solely to the extent that any such patent is necessary to Utilize the software alone. 
 * The patent license shall not apply to any combinations which include this software, 
 * other than combinations with devices manufactured by or for TI ("TI Devices"). 
 * No hardware patent is licensed hereunder. 
 * 
 * Redistributions must preserve existing copyright notices and reproduce this license 
 * (including the above copyright notice and the disclaimer and (if applicable) source 
 * code license limitations below) in the documentation and/or other materials provided 
 * with the distribution 
 * 
 * Redistribution and use in binary form, without modification, are permitted provided 
 * that the following conditions are met: 
 * 
 *        No reverse engineering, decompilation, or disassembly of this software is 
 * permitted with respect to any software provided in binary form. 
 * 
 *        any redistribution and use are licensed by TI for use only with TI Devices. 
 * 
 *        Nothing shall obligate TI to provide you with source code for the software 
 * licensed and provided to you in object code. 
 * 
 * If software source code is provided to you, modification and redistribution of the 
 * source code are permitted provided that the following conditions are met: 
 * 
 *        any redistribution and use of the source code, including any resulting derivative 
 * works, are licensed by TI for use only with TI Devices. 
 * 
 *        any redistribution and use of any object code compiled from the source code 
 * and any resulting derivative works, are licensed by TI for use only with TI Devices. 
 * 
 * Neither the name of Texas Instruments Incorporated nor the names of its suppliers 
 * 
 * may be used to endorse or promote products derived from this software without 
 * specific prior written permission. 
 * 
 * DISCLAIMER. 
 * 
 * THIS SOFTWARE IS PROVIDED BY TI AND TI'S LICENSORS "AS IS" AND ANY EXPRESS 
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
 * IN NO EVENT SHALL TI AND TI'S LICENSORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
 * OF THE POSSIBILITY OF SUCH DAMAGE. 
 * 
 */ 
-c
/*-heap  0x100
-stack 0x200
--symbol_map _Hwi_intcVectorTable=Hwi_intcVectorTable*/

MEMORY
{
    /* L2 for C66x_1 [ size 224.00 KB ] */
    L2RAM_C66x_1             ( RWIX ) : ORIGIN = 0x00800000 , LENGTH = 0x00038000
    /* DDR for C66x_1 for Linux resource table [ size 1024 B ] */
    DDR_C66x_1_RESOURCE_TABLE ( RWIX ) : ORIGIN = 0xA8100000 , LENGTH = 0x00000400
    /* DDR for C66x_1 for boot section [ size 1024 B ] */
    DDR_C66x_1_BOOT          ( RWIX ) : ORIGIN = 0xA8200000 , LENGTH = 0x00000400
    /* DDR for C66x_1 for code/data [ size 14.00 MB ] */
    DDR_C66x_1               ( RWIX ) : ORIGIN = 0xA8200400 , LENGTH = 0x00DFFC00
    /* DDR for C66x_1 for Linux IPC [ size 1024.00 KB ] */
    DDR_C66x_1_IPC           ( RWIX ) : ORIGIN = 0xA9000000 , LENGTH = 0x00100000
    /* Memory for IPC Vring's. MUST be non-cached or cache-coherent [ size 32.00 MB ] */
    IPC_VRING_MEM                     : ORIGIN = 0xAA000000 , LENGTH = 0x02000000
    /* Memory for remote core logging [ size 256.00 KB ] */
    APP_LOG_MEM                       : ORIGIN = 0xAC000000 , LENGTH = 0x00040000
    /* Memory for TI OpenVX shared memory. MUST be non-cached or cache-coherent [ size 63.75 MB ] */
    TIOVX_OBJ_DESC_MEM                : ORIGIN = 0xAC040000 , LENGTH = 0x03FC0000
    /* Memory for remote core file operations [ size  4.00 MB ] */
    APP_FILEIO_MEM                    : ORIGIN = 0xB0000000 , LENGTH = 0x00400000
    /* Memory for shared memory buffers in DDR [ size 512.00 MB ] */
    DDR_SHARED_MEM                    : ORIGIN = 0xB8000000 , LENGTH = 0x20000000
    /* DDR for c66x_1 for local heap [ size 16.00 MB ] */
    DDR_C66X_1_LOCAL_HEAP    ( RWIX ) : ORIGIN = 0xDC000000 , LENGTH = 0x01000000
    /* DDR for c66x_1 for Scratch Memory [ size 48.00 MB ] */
    DDR_C66X_1_SCRATCH       ( RWIX ) : ORIGIN = 0xDD000000 , LENGTH = 0x03000000
}

SECTIONS
{
    .hwi_vect: {. = align(32); } > DDR_C66x_1 ALIGN(0x400)
    .text:csl_entry:{}           > DDR_C66x_1
    .text:_c_int00          load > DDR_C66x_1 ALIGN(0x400)
    .text:                       > DDR_C66x_1
    .stack:                      > DDR_C66x_1
    GROUP:                       > DDR_C66x_1
    {
        .bss:
        .neardata:
        .rodata:
    }
    .cio:                        > DDR_C66x_1
    .const:                      > DDR_C66x_1
    .data:                       > DDR_C66x_1
    .switch:                     > DDR_C66x_1
    .sysmem:                     > DDR_C66x_1
    .far:                        > DDR_C66x_1
    .args:                       > DDR_C66x_1
    .ppinfo:                     > DDR_C66x_1
    .ppdata:                     > DDR_C66x_1
    .ti.decompress:              > DDR_C66x_1
    .ti.handler_table:           > DDR_C66x_1

    /* COFF sections */
    .pinit:                      > DDR_C66x_1
    .cinit:                      > DDR_C66x_1

    /* EABI sections */
    .binit:                      > DDR_C66x_1
    .init_array:                 > DDR_C66x_1
    .fardata:                    > DDR_C66x_1
    .c6xabi.exidx:               > DDR_C66x_1
    .c6xabi.extab:               > DDR_C66x_1

    .csl_vect:                   > DDR_C66x_1
  
    ipc_data_buffer:             > DDR_C66x_1 type=NOLOAD
    .resource_table :
    {
        *(.resource_table)
    }  >  DDR_C66x_1_RESOURCE_TABLE

    .log_shared_mem :
	{
		*(.log_shared_mem*)
	} > APP_LOG_MEM

    .tracebuf : {} align(1024)   > DDR_C66x_1

    .bss:taskStackSection                 > DDR_C66x_1
    .bss:ddr_local_mem      (NOLOAD) : {} > DDR_C66X_1_LOCAL_HEAP
    .bss:ddr_scratch_mem    (NOLOAD) : {} > DDR_C66X_1_SCRATCH
    .bss:app_log_mem        (NOLOAD) : {} > APP_LOG_MEM
    .bss:app_fileio_mem     (NOLOAD) : {} > APP_FILEIO_MEM
    .bss:tiovx_obj_desc_mem (NOLOAD) : {} > TIOVX_OBJ_DESC_MEM
    .bss:ipc_vring_mem      (NOLOAD) : {} > IPC_VRING_MEM

    .bss:l2mem              (NOLOAD)(NOINIT) : {} > L2RAM_C66x_1
}
