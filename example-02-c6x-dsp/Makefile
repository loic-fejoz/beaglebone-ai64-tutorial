C6X_C_DIR="/usr/share/ti/cgt-c6x/include;/usr/share/ti/cgt-c6x/lib"
DSP_FW=dsp12-hello

CGT_C6X_DIR ?= /usr/share/ti/cgt-c6x
CGT_C7X_DIR ?= /usr/share/ti/cgt-c7x
KERNEL_VERSION ?= $(shell uname -r)

PRU_SWPKG = /usr/share/ti/cgt-pru
DSP_SWPKG = $(CGT_C6X_DIR)
DSP7_SWPKG = $(CGT_C7X_DIR)

CC = $(CGT_C6X_DIR)/bin/cl6x
LD = $(CGT_C6X_DIR)/bin/lnk6x
# LD = cl6x -z
CFLAGS = --include_path=$(DSP_SWPKG)/include --include_path=$(DSP_SWPKG)/lib --include_path=/usr/lib/ti/pru-software-support-package/include
LDFLAGS = -c --search_path=$(DSP_SWPKG)/lib 

CC7 = $(CGT_C7X_DIR)/bin/cl7x
LD7 = $(CGT_C7X_DIR)/bin/lnk7x
C7FLAGS = --include_path=$(DSP7_SWPKG)/include --include_path=$(DSP7_SWPKG)/lib --include_path=/usr/lib/ti/pru-software-support-package/include
LD7FLAGS = -c --search_path=$(DSP7_SWPKG)/lib 

all: $(DSP_FW) dsp14-hello J721E_DSP12.svg C66SS.svg k3-j721e-beagleboneai64.dts

main-dsp.o: main-dsp.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(DSP_FW): main-dsp.o J721E_DSP12.cmd
	$(LD) $(LDFLAGS) $< /usr/share/ti/cgt-c6x/lib/rts6600_elf.lib -o $@ -m debug-mem.txt J721E_DSP12.cmd

/lib/firmware/$(DSP_FW): $(DSP_FW)
	sudo cp $< $@

run-dsp12: /lib/firmware/$(DSP_FW)
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc12/state" ; \
	sudo sh -c "echo '$(DSP_FW)' > /sys/class/remoteproc/remoteproc12/firmware" && \
	sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc12/state"; /bin/true

debug-dsp12: run-dsp12
	dmesg | tail -n 5
	sudo tail /sys/kernel/debug/remoteproc/remoteproc12/trace0

stop-dsp12:
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc12/state"

main-dsp-c7.o: main-dsp-c7.c
	$(CC7) $(C7FLAGS) $^ --output_file $@

dsp14-hello: main-dsp-c7.o J721E_DSP14.cmd
	$(LD7) $(LD7FLAGS) $< /usr/share/ti/cgt-c7x/lib/rts7100_le.lib -o $@ -m debug-mem-c7.txt J721E_DSP14.cmd

/lib/firmware/dsp14-hello: dsp14-hello
	sudo cp $< $@

run-dsp14: /lib/firmware/dsp14-hello
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc14/state" ; \
	sudo sh -c "echo 'dsp14-hello' > /sys/class/remoteproc/remoteproc14/firmware" && \
	sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc14/state"; /bin/true

debug-dsp14: run-dsp14
	dmesg | tail -n 5
	sudo tail /sys/kernel/debug/remoteproc/remoteproc14/trace0

stop-dsp14:
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc14/state"

%.svg: %.mld
	mld $<

k3-j721e-beagleboneai64.dts:
	@if [ -f /boot/firmware/k3-j721e-beagleboneai64.dtb ]; then \
		dtc -I dtb -O dts /boot/firmware/k3-j721e-beagleboneai64.dtb > $@; \
	elif [ -f /boot/dtbs/$(KERNEL_VERSION)/ti/k3-j721e-beagleboneai64.dtb ]; then \
		dtc -I dtb -O dts /boot/dtbs/$(KERNEL_VERSION)/ti/k3-j721e-beagleboneai64.dtb > $@; \
	else \
		echo "Error: BeagleBone AI-64 Device Tree Blob (.dtb) not found" && exit 1; \
	fi

.PHONY: run-dsp12 debug-dsp12 clean

clean:
	rm -f $(DSP_FW) dsp14-hello *.o *.obj debug-mem-c7.txt debug-mem.txt k3-j721e-beagleboneai64.dts