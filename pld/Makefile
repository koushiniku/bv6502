# SPDX-License-Identifier: MIT
# Makefile

.SUFFIXES:

SHELL	= /bin/sh
srcdir	= .

PLDS	:= $(wildcard *.pld)
JEDS	:= $(PLDS:.pld=.jed)

.PHONY: all
all : $(JEDS)

%.jed : %.pld
	5vcomp $<

.PHONY: clean
clean :
	rm -f $(JEDS)
