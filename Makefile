EXAMPLES = example-00-pru example-01-pru-hello example-02-c6x-dsp example-03-pru-led example-04-pru-dual-led example-05-pru-dds-rtu example-06-pru-epwm example-07-pru-dsp-fft


.PHONY: all clean $(EXAMPLES)

all: $(EXAMPLES)

$(EXAMPLES):
	$(MAKE) -C $@

clean:
	for dir in $(EXAMPLES); do \
		$(MAKE) -C $$dir clean; \
	done
