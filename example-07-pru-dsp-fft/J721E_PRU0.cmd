/*
 * J721E_PRU0.cmd
 * Linker command file for J721E PRU0 (ICSSG0 PRU0) core.
 */

-cr		/* Link using C conventions */

MEMORY
{
      PAGE 0:
	PRU_IMEM	: org = 0x00000000 len = 0x00004000

      PAGE 1:
	PRU0_DMEM_0	: org = 0x00000000 len = 0x00001000	CREGISTER=24
	PRU0_DMEM_1	: org = 0x00002000 len = 0x00001000	CREGISTER=25
	RTU0_DMEM_0	: org = 0x00001000 len = 0x00000800
	RTU0_DMEM_1	: org = 0x00003000 len = 0x00000800

      PAGE 2:
	PRU_SHAREDMEM	: org = 0x00010000 len = 0x00010000	CREGISTER=28
	PRU_INTC	: org = 0x00020000 len = 0x00001504	CREGISTER=0
	PRU_CFG		: org = 0x00026000 len = 0x00000100	CREGISTER=4
	PRU_RTU_RAT0	: org = 0x00008000 len = 0x00000854	CREGISTER=22
}

SECTIONS {
	.text:_c_int00*	>  0x0, PAGE 0
	.text		>  PRU_IMEM, PAGE 0
	.stack		>  PRU0_DMEM_0, PAGE 1
	.bss		>  PRU0_DMEM_0, PAGE 1
	.cio		>  PRU0_DMEM_0, PAGE 1
	.data		>  PRU0_DMEM_0, PAGE 1
	.switch		>  PRU0_DMEM_0, PAGE 1
	.sysmem		>  PRU0_DMEM_0, PAGE 1
	.cinit		>  PRU0_DMEM_0, PAGE 1
	.rodata		>  PRU0_DMEM_0, PAGE 1
	.rofardata	>  PRU0_DMEM_0, PAGE 1
	.farbss		>  PRU0_DMEM_0, PAGE 1
	.fardata	>  PRU0_DMEM_0, PAGE 1

	/* Ensure resource_table section is aligned on 8-byte address for ARMv8 kernel */
	.resource_table : ALIGN (8) >  PRU0_DMEM_0, PAGE 1
}
