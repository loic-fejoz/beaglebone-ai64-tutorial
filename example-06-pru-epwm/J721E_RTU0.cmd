/*
 * J721E_RTU0.cmd
 * Linker command file for J721E RTU0 (ICSSG0 RT_PRU0) core.
 */

-cr		/* Link using C conventions */

MEMORY
{
      PAGE 0:
	PRU_IMEM	: org = 0x00000000 len = 0x00004000

      PAGE 1:
	RTU0_DMEM_0	: org = 0x00001000 len = 0x00000800	CREGISTER=24
	RTU0_DMEM_1	: org = 0x00003000 len = 0x00000800	CREGISTER=25
	PRU0_DMEM_0	: org = 0x00000000 len = 0x00001000
	PRU0_DMEM_1	: org = 0x00002000 len = 0x00001000

      PAGE 2:
	PRU_SHAREDMEM	: org = 0x00010000 len = 0x00010000	CREGISTER=28
	PRU_INTC	: org = 0x00020000 len = 0x00001504	CREGISTER=0
	PRU_CFG		: org = 0x00026000 len = 0x00000100	CREGISTER=4
	PRU_RTU_RAT0	: org = 0x00008000 len = 0x00000854	CREGISTER=22
}

SECTIONS {
	.text:_c_int00*	>  0x0, PAGE 0
	.text		>  PRU_IMEM, PAGE 0
	.stack		>  RTU0_DMEM_1, PAGE 1
	.bss		>  RTU0_DMEM_0, PAGE 1
	.cio		>  RTU0_DMEM_0, PAGE 1
	.data		>  RTU0_DMEM_0, PAGE 1
	.switch		>  RTU0_DMEM_0, PAGE 1
	.sysmem		>  RTU0_DMEM_0, PAGE 1
	.cinit		>  RTU0_DMEM_0, PAGE 1
	.rodata		>  RTU0_DMEM_0, PAGE 1
	.rofardata	>  RTU0_DMEM_0, PAGE 1
	.farbss		>  RTU0_DMEM_0, PAGE 1
	.fardata	>  RTU0_DMEM_0, PAGE 1

	/* Ensure resource_table section is aligned on 8-byte address for ARMv8 kernel */
	.resource_table : ALIGN (8) >  RTU0_DMEM_0, PAGE 1

	.pru_irq_map (COPY) :
	{
		*(.pru_irq_map)
	}
}
