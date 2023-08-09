PRU_FW=pru9-hellobis
PRU_SWPKG = /usr/lib/ti/pru-software-support-package

CC = clpru
LD = lnkpru
CFLAGS = --include_path=$(PRU_SWPKG)/include \
         --include_path=$(PRU_SWPKG)/include/j721e
LDFLAGS = J721E_PRU9.cmd

all: main-pru

main-pru.o: main-pru.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(PRU_FW): main-pru.o J721E_PRU9.cmd
	$(LD) -o $@ $< $(LDFLAGS)

/lib/firmware/$(PRU_FW): $(PRU_FW)
	sudo cp $< $@

run-pru9: /lib/firmware/$(PRU_FW)
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc9/state" ; \
	sudo sh -c "echo '$(PRU_FW)' > /sys/class/remoteproc/remoteproc9/firmware" && \
	sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc9/state"

debug-pru9: run-pru9
	dmesg | tail -n 15
	sudo tail /sys/kernel/debug/remoteproc/remoteproc9/trace0

.PHONY: run-pru9 debug-pru9 clean

clean:
	rm -f $(PRU_FW) *.o *.obj