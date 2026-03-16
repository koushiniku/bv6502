# SPDX-License-Identifier: MIT
#
# Makefile

.SUFFIXES:

SHELL	= /bin/sh
srcdir	= .

AR 	= ar65
AS 	= ca65
CC 	= cc65
LD 	= ld65
ASFLAGS = --cpu w65c02
CFLAGS	= -t none -O --cpu w65c02

PROG	= minipro
FLASH	= SST39SF010A
#FLASH	= AT28C256

BASE	= bv6502
LIB	:= $(BASE).lib
BIN	:= $(BASE).bin
MAP	:= $(BASE).map
EXTLIB 	= /usr/share/cc65/lib/supervision.lib

INCS_S	:= $(wildcard *.inc)
SRCS_S	:= $(filter-out crt0.s,$(wildcard *.s))
OBJS_S	:= $(SRCS_S:.o=.s)
SRCS_C	:= $(wildcard *.c)
OBJS_C	:= $(SRCS_C:.o=.c)
HDRS_C	:= $(wildcard *.h)

OBJS	:= $(SRCS_S:.o=.s) $(SRCS_C:.o=.c)

%.o : %.s $(INCS_S)
	$(AS) $(ASFLAGS) $<

%.o : %.c $(HDRS_C)
	$(CC) $(CFLAGS) $<

$(LIB) : crt0.o $(EXTLIB)
	if [ ! -f $@ ]; then cp $(EXTLIB) $@; fi
	$(AR) r $@ $<

$(BIN) : $(OBJS) $(LIB)
	$(LD) -C $(CFG) -m $(MAP) -o $@ $^

.PHONY: all
all : $(BIN)

.PHONY: flash
flash : $(BIN)
	$(PROG) -p $(FLASH) -w $<

.PHONY: clean
clean :
	rm -f $(LIB) $(OBJS) $(MAP) $(BIN)
