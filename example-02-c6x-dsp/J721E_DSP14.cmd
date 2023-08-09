/* 
 * This file is derived from:
 * https://git.ti.com/cgit/processor-sdk/vision_apps/tree/platform/j721e/rtos/C7X_1/linker_mem_map.cmd?h=main
 * and
 * https://git.ti.com/cgit/processor-sdk/vision_apps/tree/platform/j721e/rtos/C7X_1/j721e_linker_freertos.cmd?h=main
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

MEMORY
{
    L2RAM_C7X_1              ( RWIX ) : ORIGIN = 0x00800000 , LENGTH = 0x00038000
    DDR_C7X_1_RESOURCE_TABLE ( RWIX ) : ORIGIN = 0xA8100000 , LENGTH = 0x00000400
    DDR_C7X_1_BOOT           ( RWIX ) : ORIGIN = 0xA8200000 , LENGTH = 0x00000400
    DDR_C7X_1                ( RWIX ) : ORIGIN = 0xA8200400 , LENGTH = 0x00DFFC00
    /*DDR_C7X_1_LOCAL_HEAP     ( RWIX ) : ORIGIN = 0xDC000000 , LENGTH = 0x01000000*/
    DDR_C7X_1_LOCAL_HEAP     ( RWIX ) : ORIGIN = 0x64E00000 , LENGTH = 0xc000
    DDR_C7X_1_SCRATCH        ( RWIX ) : ORIGIN = 0xDD000000 , LENGTH = 0x03000000
}

SECTIONS
{
    .hwi_vect: {. = align(32); } > DDR_C7X_1 ALIGN(0x200000)
    .text:csl_entry:{}           > DDR_C7X_1
    .text:_c_int00          load > DDR_C7X_1 ALIGN(0x200000)
    .text:                       > DDR_C7X_1
    .stack:                      > DDR_C7X_1
    GROUP:                       > DDR_C7X_1
    {
        .bss:
        .neardata:
        .rodata:
    }
    .cio:                        > DDR_C7X_1
    .const:                      > DDR_C7X_1
    .data:                       > DDR_C7X_1
    .switch:                     > DDR_C7X_1
    .sysmem:                     > DDR_C7X_1
    .far:                        > DDR_C7X_1
    .args:                       > DDR_C7X_1
    .ppinfo:                     > DDR_C7X_1
    .ppdata:                     > DDR_C7X_1
    .ti.decompress:              > DDR_C7X_1
    .ti.handler_table:           > DDR_C7X_1

    /* COFF sections */
    .pinit:                      > DDR_C7X_1
    .cinit:                      > DDR_C7X_1

    /* EABI sections */
    .binit:                      > DDR_C7X_1
    .init_array:                 > DDR_C7X_1
    .fardata:                    > DDR_C7X_1
    .c6xabi.exidx:               > DDR_C7X_1
    .c6xabi.extab:               > DDR_C7X_1

    .csl_vect:                   > DDR_C7X_1
  
    ipc_data_buffer:             > DDR_C7X_1 type=NOLOAD
    .resource_table :
    {
        *(.resource_table)
    }  >  DDR_C7X_1_RESOURCE_TABLE

    .log_shared_mem :
	{
		*(.log_shared_mem*)
	} > DDR_C7X_1

    .tracebuf : {} align(1024)   > DDR_C7X_1

    .bss:taskStackSection                 > DDR_C7X_1
    .bss:ddr_local_mem      (NOLOAD) : {} > DDR_C7X_1_LOCAL_HEAP
    .bss:ddr_scratch_mem    (NOLOAD) : {} > DDR_C7X_1_SCRATCH
    .bss:app_log_mem        (NOLOAD) : {} > DDR_C7X_1
    .bss:app_fileio_mem     (NOLOAD) : {} > DDR_C7X_1
    .bss:tiovx_obj_desc_mem (NOLOAD) : {} > DDR_C7X_1
    .bss:ipc_vring_mem      (NOLOAD) : {} > DDR_C7X_1

    .bss:l2mem              (NOLOAD)(NOINIT) : {} > L2RAM_C7X_1
}
