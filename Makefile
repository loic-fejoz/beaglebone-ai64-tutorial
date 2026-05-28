EXAMPLES = example-00-pru example-01-pru-hello example-02-c6x-dsp

.PHONY: all clean $(EXAMPLES)

all: $(EXAMPLES)

$(EXAMPLES):
	$(MAKE) -C $@

clean:
	for dir in $(EXAMPLES); do \
		$(MAKE) -C $$dir clean; \
	done
