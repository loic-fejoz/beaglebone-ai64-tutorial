-cr
//-heap  0x3000
//-stack 0x6000

MEMORY
{
        PAGE 0:
        PMEM:   org = 0x0   len = 0x00004000
//        EXT0:   o = 00400000h   l = 01000000h
//        EXT1:   o = 01400000h   l = 00400000h
//        EXT2:   o = 02000000h   l = 01000000h
//        EXT3:   o = 03000000h   l = 01000000h
        PAGE 1:
        BMEM:   o = 80000000h   l = 0x4000
}

SECTIONS
    {
    /* Forces _c_int00 to the start of PRU IRAM. Not necessary when loading
            an ELF file, but useful when loading a binary */
    .text:_c_int00*	>  PMEM, PAGE 0
    
    .text       >       PMEM, PAGE 0

    .stack      >       BMEM, PAGE 1
    .args       >       BMEM, PAGE 1

    GROUP
    {
            .neardata   /* Move .bss after .neardata and .rodata.  ELF allows */
            .rodata     /* uninitialized data to follow initialized data in a */
            .bss        /* single segment. This order facilitates a single    */
                        /* segment for the near DP sections.                  */
    }>BMEM, PAGE 1

    .cinit      >       BMEM, PAGE 1
    .cio        >       BMEM, PAGE 1
    .const      >       BMEM, PAGE 1
    .data       >       BMEM, PAGE 1
    .switch     >       BMEM, PAGE 1
    .sysmem     >       BMEM, PAGE 1
    .far        >       BMEM, PAGE 1
    .fardata    >       BMEM, PAGE 1
    .ppinfo     >       BMEM, PAGE 1
    .ppdata     >       BMEM, palign(32), PAGE 1 /* Work-around kelvin bug */

    .TI.ramfunc: {} load=BMEM, run=PMEM, table(BINIT)
}
