PRU0_FW = pru0-dual-core-fw
PRU1_FW = pru1-dual-core-fw
DTBO = bbai64-pru-dual-led.dtbo
PRU_SWPKG = /usr/lib/ti/pru-software-support-package
CGT_PRU_DIR ?= /usr/share/ti/cgt-pru

CC = $(CGT_PRU_DIR)/bin/clpru
LD = $(CGT_PRU_DIR)/bin/lnkpru
CFLAGS = --include_path=$(CGT_PRU_DIR)/include \
         --include_path=$(PRU_SWPKG)/include \
         --include_path=$(PRU_SWPKG)/include/j721e

all: $(PRU0_FW) $(PRU1_FW) $(DTBO)

main-pru0.o: main-pru0.c
	$(CC) $(CFLAGS) $^ --output_file $@

main-pru1.o: main-pru1.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(PRU0_FW): main-pru0.o J721E_PRU8.cmd
	$(LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU8.cmd

$(PRU1_FW): main-pru1.o J721E_PRU9.cmd
	$(LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU9.cmd

$(DTBO): bbai64-pru-dual-led.dts
	dtc -@ -I dts -O dtb -o $@ $^

clean:
	rm -f $(PRU0_FW) $(PRU1_FW) $(DTBO) *.o *.obj

.PHONY: clean all
