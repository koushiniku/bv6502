# SPDX-License-Identifier: MIT
# Makefile

.SUFFIXES:

SHELL	= /bin/sh
srcdir	= .

AR 	= ar65
AS 	= ca65
CC 	= cc65
LD 	= ld65
ASFLAGS := --cpu W65C02 --feature string_escapes -I $(HOME)/.local/share/cc65/asminc -g
CFLAGS	:= -t none -O --cpu W65C02 -I $(HOME)/.local/share/cc65/include -g
BYTES	= 131072

PROG	= minipro
FLASH	= SST39SF010A
#FLASH	= AT28C256

BASE	= bv6502
LIB	:= $(BASE).lib
BIN	:= $(BASE).bin
MAP	:= $(BASE).map
CFG	:= $(BASE).cfg
EXTLIB 	:= $(HOME)/.local/share/cc65/lib/supervision.lib

INCS_S	:= $(wildcard *.inc)
SRCS_S	:= $(wildcard *.s)
#SRCS_S	:= $(filter-out crt0.s,$(wildcard *.s))
SRCS_C	:= $(wildcard *.c)
HDRS_C	:= $(wildcard *.h)

OBJS	:= $(SRCS_S:.s=.o) $(SRCS_C:.c=.o)
LSTS	:= $(SRCS_S:.s=.lst)
DBG	:= $(BASE).dbg

.PHONY: all
all : $(BIN)

%.o : %.s $(INCS_S)
	$(AS) $(ASFLAGS) -l $(@:.o=.lst) -o $@ $<

%.o : %.c $(HDRS_C)
	$(CC) $(CFLAGS) $<

$(LIB) : crt0.o $(EXTLIB)
	if [ ! -f $@ ]; then cp $(EXTLIB) $@; fi
	$(AR) r $@ $<

$(BIN) : $(filter-out crt0.o,$(OBJS)) $(LIB) $(CFG)
	$(LD) -C $(CFG) -m $(MAP) --dbgfile $(DBG) -o $@ $(filter-out $(CFG),$^)
	truncate -s $(BYTES) $@

.PHONY: flash
flash : $(BIN)
	$(PROG) -p $(FLASH) -w $<

.PHONY: clean
clean :
	rm -f $(LIB) $(OBJS) $(LSTS) $(MAP) $(BIN) $(DBG)
