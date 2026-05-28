PRU_FW = pru8-led-fw
DTBO = bbai64-pru-led.dtbo
PRU_SWPKG = /usr/lib/ti/pru-software-support-package
CGT_PRU_DIR ?= /usr/share/ti/cgt-pru

CC = $(CGT_PRU_DIR)/bin/clpru
LD = $(CGT_PRU_DIR)/bin/lnkpru
CFLAGS = --include_path=$(CGT_PRU_DIR)/include \
         --include_path=$(PRU_SWPKG)/include \
         --include_path=$(PRU_SWPKG)/include/j721e
LDFLAGS = --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU8.cmd

all: $(PRU_FW) $(DTBO)

main-pru.o: main-pru.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(PRU_FW): main-pru.o J721E_PRU8.cmd
	$(LD) -o $@ $< $(LDFLAGS)

$(DTBO): bbai64-pru-led.dts
	dtc -@ -I dts -O dtb -o $@ $^

clean:
	rm -f $(PRU_FW) $(DTBO) *.o *.obj

.PHONY: clean all
