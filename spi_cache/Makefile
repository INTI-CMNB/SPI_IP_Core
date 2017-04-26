#!/usr/bin/make
##############################################################################
#
#  Makefile  SPI CACHE
#
#  This file is part FPGA Libre project http://fpgalibre.sf.net/
#
#  Description:
#  Makefile for SPI Cache
#
#  To Do:
#  -
#
#  Authors:
#    - Francisco Salomón, fsalomon@inti.gob.ar
#
##############################################################################
#
#  Copyright (c) 2011 Francisco Salomón
#  Copyright (c) 2011 Instituto Nacional de Tecnología Industrial
#
#  Distributed under the GPL v2 or newer license
#
##############################################################################

OBJDIR=../Work
POBJDIR=Work
TESTBENCH=testbench

LIBNAME=SPI

UTILSPATH=../../utils
OBJUTILSPATH=$(UTILSPATH)/$(POBJDIR)
MEMSPATH=../../mems
OBJMEMSPATH=$(MEMSPATH)/$(POBJDIR)

vpath %.o $(OBJDIR)

GHDL=ghdl
GHDL_FLAGS=--workdir=$(OBJDIR) --work=$(LIBNAME) -P$(OBJUTILSPATH) \
	-P$(OBJMEMSPATH)
GTKWAVE=gtkwave
all: help

pre:
	make -C $(UTILSPATH) all
	make -C $(MEMSPATH)  Work Work/mems_pkg.vhdl Work/mems.o Work/fifo.o
	make -C ..  Work Work/spi_pkg.vhdl Work/spi_tb_pkg.vhdl  Work/spi_pkg.o Work/spi_tb_pkg.o \
	Work/spi_controller.o Work/s25fl_simulator.o

# Rules for vhdl
$(OBJDIR)/%.vhdl : %.vhdl.in
	vhdlspp.pl $< $@ >/dev/null

# Rules for objects
$(OBJDIR)/%.o : %.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/%.o : %.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/%.o : $(OBJDIR)/%.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/%.o : $(TESTBENCH)/%.vhdl
	$(GHDL) -a $(GHDL_FLAGS) $<

$(OBJDIR)/spi_cache_pkg.vhdl : spi_cache_pkg.vhdl.in spi_cache.vhdl

$(OBJDIR)/spi_cache_pkg.o : $(OBJDIR)/spi_cache_pkg.vhdl

$(OBJDIR)/spi_cache.o : spi_cache.vhdl $(OBJDIR)/spi_cache_pkg.o

$(OBJDIR)/spi_cache_tb.o : $(TESTBENCH)/spi_cache_tb.vhdl \
	../Work/spi_tb_pkg.o ../Work/spi_pkg.o $(OBJDIR)/spi_cache_pkg.o \
	$(OBJDIR)/spi_cache.o ../Work/spi_controller.o \
	../Work/s25fl_simulator.o

# Executable
$(OBJDIR)/spi_cache_tb: $(OBJDIR)/spi_cache_tb.o
	$(GHDL) -e $(GHDL_FLAGS) -o $@ $(@F)

# Targets for cache test
test: pre $(OBJDIR)  $(OBJDIR)/spi_cache_tb
	$(OBJDIR)/spi_cache_tb  --wave=$(OBJDIR)/spi_cache_tb.ghw
#	$(OBJDIR)/spi_cache_tb --ieee-asserts=disable --wave=$(OBJDIR)/spi_cache_tb.ghw

wave: test
	$(GTKWAVE) $(OBJDIR)/spi_cache_tb.ghw

help:
	@echo "SPI Cache"
	@echo "Avalilable options:"
	@echo
	@echo "test     Compile and create testbench for spi cache"
	@echo "wave     View waveforms for spi cache"
	@echo "clean    Remove all generated files"

clean:
	rm -rf $(OBJDIR) .*~
