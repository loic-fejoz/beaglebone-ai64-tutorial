C6X_C_DIR="/usr/share/ti/cgt-c6x/include;/usr/share/ti/cgt-c6x/lib"
DSP_FW=dsp12-hello
PRU_SWPKG = /usr/share/ti/cgt-c6x
DSP_SWPKG = /usr/share/ti/cgt-c6x

CC = cl6x
LD = lnk6x
CFLAGS = --include_path=$(DSP_SWPKG)/include
LDFLAGS = J721E_DSP12.cmd

all: $(DSP_FW)

main-dsp.o: main-dsp.c
	$(CC) $(CFLAGS) $^ --output_file $@

$(DSP_FW): main-dsp.o J721E_DSP12.cmd
	$(LD) $(LDFLAGS) $< /usr/share/ti/cgt-c6x/lib/rts64plus_elf.lib -o $@ -m debug-mem.txt

/lib/firmware/$(DSP_FW): $(DSP_FW)
	sudo cp $< $@

run-dsp12: /lib/firmware/$(DSP_FW)
	sudo sh -c "echo 'stop' > /sys/class/remoteproc/remoteproc12/state" ; \
	sudo sh -c "echo '$(DSP_FW)' > /sys/class/remoteproc/remoteproc12/firmware" && \
	sudo sh -c "echo 'start' > /sys/class/remoteproc/remoteproc12/state"; /bin/true

debug-dsp12: run-dsp12
	dmesg | tail -n 3
	sudo tail /sys/kernel/debug/remoteproc/remoteproc12/trace0

.PHONY: run-dsp12 debug-dsp12 clean

clean:
	rm -f $(DSP_FW) *.o *.obj