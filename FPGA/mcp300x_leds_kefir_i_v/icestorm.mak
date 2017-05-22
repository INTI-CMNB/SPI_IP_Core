PRJ=mcp300x_leds_kefir_i
TOP=MCP300x_LEDs_Kefir_I
PNR_OPS=-d 8k -P tq144:4k
GEN=gen_icestorm

all: $(GEN) $(GEN)/$(PRJ).bin

$(GEN):
	mkdir $@

$(GEN)/synth.blif: mcp300x_leds_kefir_i.v ../../../SPI/MCP300x/mcp300x.v
	yosys -v3 -l $(GEN)/synth.log -p 'synth_ice40 -top $(TOP) -blif $@; write_verilog -attr2comment $(GEN)/synth.v' $(filter %.v, $^)

$(GEN)/$(PRJ).asc: $(GEN)/synth.blif
	arachne-pnr $(PNR_OPS) -o $(GEN)/$(PRJ).asc -p $(PRJ).in.pcf $(GEN)/synth.blif

$(GEN)/$(PRJ).bin: $(GEN)/$(PRJ).asc
	icepack $(GEN)/$(PRJ).asc $(GEN)/$(PRJ).bin

transfer-rom:
	iceprog -I B $(GEN)/$(PRJ).bin

transfer:
	iceprog -S -I B $(GEN)/$(PRJ).bin

clean:
	rm -rf $(GEN)

.PHONY: all transfer clean transfer-rom

