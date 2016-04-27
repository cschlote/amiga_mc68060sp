
##-------------------------------------------------------------------------------
##  /\  |\     Silicon Department         Telefax             06404-64760
##  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
##    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
## \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
##-------------------------------------------------------------------------------
## ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
##
## $Id: makefile,v 1.3 1997/04/02 15:34:35 schlote Exp schlote $
##
##
##-------------------------------------------------------------------------------

.asm.o:
	phxass $*.asm noexe $(AOPTS)

##-------------------------------------------------------------------------------

SRC	= fpsp.asm
HDR	= fpsp.i fpsp_debug.i AmigaFPSP_rev.i
OBJ	= fpsp.o
LIB	= lib:debug.lib lib:amiga.lib
EXE	= AmigaFPSP
AOPTS	= ds dl SET "TESTCODE=1"


##-------------------------------------------------------------------------------

all: $(EXE).ld $(EXE).ro

$(EXE).ld : $(OBJ)
	slink from $(OBJ) to $(EXE).ld noicons addsym sc sd lib $(LIB)
	slink from $(EXE).ld to $(EXE) nd sc sd LIB $(LIB)

##-------------------------------------------------------------------------------


$(EXE).ro : $(EXE)
	phxass $(SRC) to $(EXE).ro noexe

##-------------------------------------------------------------------------------

$(SRC): $(HDR) makefile

bump:
	bumprevision bump file AmigaFPSP_rev.i noc

