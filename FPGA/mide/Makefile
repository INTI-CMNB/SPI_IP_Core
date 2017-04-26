#!/usr/bin/make
##############################################################################
#
#  Test SPI area occupation
#
#  Internal file, can't be downloaded.
#
#  Description:
#  Makefile for SPI Wishbone area occupation test synthesis
#
#  To Do:
#  -
#
#  Authors:
#    - Francisco Salomón, fsalomon@inti.gob.ar
#
##############################################################################
#
#  Copyright (c) 2010 Francisco Salomón
#  Copyright (c) 2010 Instituto Nacional de Tecnología Industrial
#
#  For internal use, all rights reserved.
#
##############################################################################
PRJ=mide
OBJDIR=Work
LIBNAME=SPI
MEMSPATH=../../../mems/
SPIPATH=../../../SPI/
GEN_LIST=genericlist

all: help

pre:
	make -C $(SPIPATH)   $(OBJDIR)  $(OBJDIR)/spi_pkg.vhdl
	make -C $(MEMSPATH)  $(OBJDIR)  $(OBJDIR)/mems_pkg.vhdl

sys: pre
	rm -f *.in.xst
	@echo "Synthesis for default generics." >> $(PRJ).txt
	@echo "----------------------------------------------------------------------"  >> $(PRJ).txt
	xil_project.pl --no-standalone --make $(PRJ).xilprj

testsev: pre
	./mide.pl --project=$(PRJ) --input=$(GEN_LIST)

testsev-nb: pre
	./mide.pl --project=$(PRJ) --input=$(GEN_LIST) --no-bram

testsev-all: pre
	./mide.pl --project=$(PRJ) --input=$(GEN_LIST)
	./mide.pl --project=$(PRJ) --input=$(GEN_LIST) --no-bram --force


.PHONY: testsev testsev-nb

help:
	@echo "Synthesis Makefile for SPI area messurement"
	@echo "Avalilable options:"
	@echo
	@echo "sys          Synthesis test for defaut generics"
	@echo "testsev      Synthesis test for several generics values"
	@echo "testsev-nb   Synthesis test for several generics values without brams"
	@echo "testsev-all  Synthesis test for several generics values with and without brams"
	@echo "clean        Remove all generated files"

clean:
	rm -rf .*~ $(PRJ).in.xst $(PRJ).sub.mak
	make -f $(PRJ).mak clean



