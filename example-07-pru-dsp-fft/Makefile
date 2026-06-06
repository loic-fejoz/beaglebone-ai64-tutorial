PRU0_FW = pru0-epwm-fw
RTU0_FW = rtu0-rpmsg-fw
PRU1_FW = pru1-sampler-fw
DSP_FW = dsp12-fft
DTBO = bbai64-pru-dsp-fft.dtbo

PRU_SWPKG = /usr/lib/ti/pru-software-support-package
CGT_PRU_DIR ?= /usr/share/ti/cgt-pru
CGT_C66_DIR ?= /usr/share/ti/cgt-c6x

# PRU Tools
PRU_CC = $(CGT_PRU_DIR)/bin/clpru
PRU_LD = $(CGT_PRU_DIR)/bin/lnkpru
PRU_CFLAGS = -O3 -k --include_path=$(CGT_PRU_DIR)/include \
             --include_path=$(PRU_SWPKG)/include \
             --include_path=$(PRU_SWPKG)/include/j721e

# DSP Tools
DSP_CC = $(firstword $(wildcard $(CGT_C66_DIR)/bin/cl6x) /usr/bin/cl6x)
DSP_LD = $(firstword $(wildcard $(CGT_C66_DIR)/bin/lnk6x) /usr/bin/lnk6x)
DSP_CFLAGS = --include_path=$(CGT_C66_DIR)/include \
             --include_path=$(CGT_C66_DIR)/lib \
             --include_path=$(PRU_SWPKG)/include
DSP_LDFLAGS = -c --search_path=$(CGT_C66_DIR)/lib

all: $(PRU0_FW) $(RTU0_FW) $(PRU1_FW) $(DSP_FW) $(DTBO)

# PRU0 Signal Generator
main-pru0.o: main-pru0.c
	$(PRU_CC) $(PRU_CFLAGS) $^ --output_file $@

$(PRU0_FW): main-pru0.o J721E_PRU0.cmd
	$(PRU_LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU0.cmd

# RTU0 RPMsg Control
main-rtu0.o: main-rtu0.c
	$(PRU_CC) $(PRU_CFLAGS) $^ --output_file $@

$(RTU0_FW): main-rtu0.o J721E_RTU0.cmd
	$(PRU_LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --search_path=$(PRU_SWPKG)/lib --library=rpmsg_lib.lib --library=rtspruv3_le.lib J721E_RTU0.cmd

# PRU1 Sampler
main-pru1.o: main-pru1.c
	$(PRU_CC) $(PRU_CFLAGS) $^ --output_file $@

$(PRU1_FW): main-pru1.o J721E_PRU0.cmd
	$(PRU_LD) -o $@ $< --search_path=$(CGT_PRU_DIR)/lib --library=rtspruv3_le.lib J721E_PRU0.cmd

# DSP FFT
main-dsp.o: main-dsp.c
	$(DSP_CC) $(DSP_CFLAGS) $^ --output_file $@

$(DSP_FW): main-dsp.o J721E_DSP12.cmd
	$(DSP_LD) $(DSP_LDFLAGS) $< $(CGT_C66_DIR)/lib/rts6600_elf.lib -o $@ J721E_DSP12.cmd

# Device Tree Overlay
$(DTBO): bbai64-pru-dsp-fft.dts
	dtc -@ -I dts -O dtb -o $@ $^

clean:
	rm -f $(PRU0_FW) $(RTU0_FW) $(PRU1_FW) $(DSP_FW) $(DTBO) *.o *.obj

.PHONY: clean all
