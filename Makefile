#!/usr/bin/make
##############################################################################
#
#  Makefile  SPI controller
#
#  This file is part FPGA Libre project http://fpgalibre.sf.net/
#
#  Description:
#  Makefile for SPI
#
#  To Do:
#  -
#
#  Authors:
#    - Salvador E. Tropea, salvador en inti.gob.ar
#    - Francisco Salomón, fsalomon@inti.gob.ar
#
##############################################################################
#
#  Copyright (c) 2017 Salvador E. Tropea
#  Copyright (c) 2010 Francisco Salomón
#  Copyright (c) 2010-2017 Instituto Nacional de Tecnología Industrial
#
#  Distributed under the GPL v2 or newer license
#
##############################################################################

OBJDIR=Work
TESTBENCH=testbench
LIBNAME=SPI
UTILSPATH=../utils
OBJUTILSPATH=$(UTILSPATH)/$(OBJDIR)
WHANDPATH=../wb_handler
OBJWHANDPATH=$(WHANDPATH)/$(OBJDIR)
MEMSPATH=../mems
OBJMEMSPATH=$(MEMSPATH)/$(OBJDIR)

vpath %.o $(OBJDIR)
vpath %.vhdl testbench MCP300x
GHDL=ghdl
GHDL_FLAGS=--workdir=$(OBJDIR) --work=$(LIBNAME) -P$(OBJUTILSPATH) \
	-P$(OBJWHANDPATH) -P$(OBJMEMSPATH)
GTKWAVE=gtkwave
CTRLTESTPRJ=controller_test
CTRLTESTPATH=FPGA/$(CTRLTESTPRJ)

all: help

$(OBJDIR):
	mkdir $@

pre: $(OBJDIR)
	make -C $(WHANDPATH) lib
	make -C $(MEMSPATH)

$(OBJDIR)/%.vhdl : %.vhdl.in
	vhdlspp.pl $< $@ >/dev/null

$(OBJDIR)/%.vhdl : $(TESTBENCH)/%.vhdl.in
	vhdlspp.pl $< $@ >/dev/null

$(OBJDIR)/%.o : %.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/%.o : $(OBJDIR)/%.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/%.o : $(TESTBENCH)/%.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/spi_pkg.o : $(OBJDIR)/spi_pkg.vhdl

$(OBJDIR)/spi_pkg.vhdl : spi_controller.vhdl spi_master.vhdl spi_wb.vhdl MCP300x/mcp300x.vhdl

$(OBJDIR)/spi_tb_pkg.o : $(OBJDIR)/spi_tb_pkg.vhdl

$(OBJDIR)/s25fl_simulator.o : $(TESTBENCH)/s25fl_simulator.vhdl \
	$(OBJDIR)/spi_pkg.o

# Targets for controller test
test_c: $(OBJDIR)  $(OBJDIR)/spi_controller_tb
	$(OBJDIR)/spi_controller_tb  --wave=$(OBJDIR)/spi_controller_tb.ghw

wave_c: test_c
	$(GTKWAVE) $(OBJDIR)/spi_controller_tb.ghw

# Targets for controller test
test_m: $(OBJDIR)  $(OBJDIR)/spi_master_tb
	$(OBJDIR)/spi_master_tb  --wave=$(OBJDIR)/spi_master_tb.ghw

wave_m: test_m
	$(GTKWAVE) $(OBJDIR)/spi_master_tb.ghw

synsTest:
	cd  $(CTRLTESTPATH); xil_project.pl --make $(CTRLTESTPRJ).xilprj

$(OBJDIR)/spi_controller_tb.o : $(TESTBENCH)/spi_controller_tb.vhdl \
	$(OBJDIR)/spi_tb_pkg.o $(OBJDIR)/spi_controller.o \
	$(OBJDIR)/s25fl_simulator.o

$(OBJDIR)/spi_controller_tb: $(OBJDIR)/spi_controller_tb.o
	$(GHDL) -e $(GHDL_FLAGS) -o $@ $(@F)

$(OBJDIR)/spi_master_tb.o : $(TESTBENCH)/spi_master_tb.vhdl \
	$(OBJDIR)/spi_tb_pkg.o $(OBJDIR)/spi_master.o \
	$(OBJDIR)/s25fl_simulator.o

$(OBJDIR)/spi_master_tb: $(OBJDIR)/spi_master_tb.o
	$(GHDL) -e $(GHDL_FLAGS) -o $@ $(@F)

# Targets for SPI_WB
$(OBJDIR)/spi_tb.o: $(TESTBENCH)/spi_tb.vhdl \
	$(OBJDIR)/spi_controller.o $(OBJDIR)/spi_tb_pkg.o $(OBJDIR)/spi_wb.o \
	$(OBJDIR)/s25fl_simulator.o

$(OBJDIR)/spi_tb: $(OBJDIR)/spi_tb.o
	$(GHDL) -e $(GHDL_FLAGS) -o $@ $(@F)

test_wb: $(OBJDIR) pre $(OBJDIR)/spi_tb
	$(OBJDIR)/spi_tb --wave=$(OBJDIR)/spi_tb.ghw

# Target for complete testbench
test: test_m test_c test_wb

# Target for waveforms
wave: test_wb
	$(GTKWAVE) $(OBJDIR)/spi_tb.ghw

###############################################################################
# MCP300x
###############################################################################
$(OBJDIR)/mcp300x_test.o : $(OBJDIR)/mcp3008_sim.o $(OBJDIR)/mcp300x.o

test_mcp: pre $(OBJDIR)/mcp300x_test
	$(OBJDIR)/mcp300x_test --wave=$(OBJDIR)/mcp300x_test.ghw

$(OBJDIR)/mcp300x_test : $(OBJDIR)/mcp300x_test.o
	$(GHDL) -e $(GHDL_FLAGS) -o $@ $(@F)

$(OBJDIR)/spi_cache.o: spi_cache/spi_cache.vhdl spi_cache/spi_cache_pkg.vhdl.in
	make -C spi_cache ../Work/spi_cache.o

lib: pre $(OBJDIR)/spi_pkg.o $(OBJDIR)/spi_controller.o $(OBJDIR)/spi_wb.o \
	$(OBJDIR)/spi_cache.o $(OBJDIR)/mcp300x.o $(OBJDIR)/spi_master.o

help:
	@echo "SPI Makefile"
	@echo "Avalilable options:"
	@echo
	@echo "lib      Compile all cores"
	@echo "test     Compile and create testbench for spi wishbone"
	@echo "wave     View waveforms for spi wishbone"
	@echo "test_c   Compile and create testbench for spi controller"
	@echo "wave_c   View waveforms for spi controller"
	@echo "test_m   Compile and create testbench for spi master"
	@echo "wave_m   View waveforms for spi master"
	@echo "synsTest Synthesis test for spi controller project for avnet board"
	@echo "test_mcp Test the MCP300x core"
	@echo "clean    Remove all generated files"

clean:
	rm -rf $(OBJDIR) .*~
