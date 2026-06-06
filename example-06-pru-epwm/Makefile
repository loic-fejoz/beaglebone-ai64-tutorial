PRU0_FW = pru0-epwm-fw
RTU0_FW = rtu0-rpmsg-fw
DTBO = bbai64-pru-epwm.dtbo
PRU_SWPKG = /usr/lib/ti/pru-software-support-package
CGT_PRU_DIR ?= /usr/share/ti/cgt-pru

CC = $(CGT_PRU_DIR)/bin/clpru
LD = $(CGT_PRU_DIR)/bin/lnkpru
CFLAGS = --include_path=$(CGT_PRU_DIR)/include \
         --include_path=$(PRU_SWPKG)/include \
         --include_path=$(PRU_SWPKG)/include/j721e

all: $(PRU0_FW) $(RTU0_FW) $(DTBO)

main-pru0.o: main-pru0.c
	$(CC) $(CFLAGS) $^ --output_file $@

main-rtu0.o: main-rtu0.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(PRU0_FW): main-pru0.o J721E_PRU0.cmd
	$(LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU0.cmd

$(RTU0_FW): main-rtu0.o J721E_RTU0.cmd
	$(LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --search_path=$(PRU_SWPKG)/lib --library=rpmsg_lib.lib --library=rtspruv3_le.lib J721E_RTU0.cmd

$(DTBO): bbai64-pru-epwm.dts
	dtc -@ -I dts -O dtb -o $@ $^

clean:
	rm -f $(PRU0_FW) $(RTU0_FW) $(DTBO) *.o *.obj

.PHONY: clean all
