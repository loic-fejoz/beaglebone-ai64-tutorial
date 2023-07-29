PRU_SWPKG = /usr/lib/ti/pru-software-support-package

CC = clpru
LD = lnkpru
CFLAGS = --include_path=$(PRU_SWPKG)/include \
         --include_path=$(PRU_SWPKG)/include/j721e
LDFLAGS=J721E_PRU9.cmd

all: main-pru

main-pru.o: main-pru.c
	$(CC) $(CFLAGS) $^ --output_file $@

main-pru: main-pru.o J721E_PRU9.cmd
	$(LD) $(LDFLAGS) $< -o $@

/lib/firmware/pru9-fw: main-pru
	sudo cp $< $@

run-pru9: /lib/firmware/pru9-fw
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc9/state" && \
	sudo sh -c "echo 'pru9-fw' > /sys/class/remoteproc/remoteproc9/firmware" && \
	sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc9/state"

debug-pru9: run-pru9
	dmesg | tail -n 10
	sudo tail /sys/kernel/debug/remoteproc/remoteproc9/trace0

.PHONY: run-pru9 debug-pru9