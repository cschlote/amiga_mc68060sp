
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
	phxass noexe $(AOPTS) $*.asm

##-------------------------------------------------------------------------------

SRC	= isp.asm
HDR	= isp.i isp_debug.i AmigaISP_rev.i
OBJ	= isp.o
LIB	= lib:debug.lib lib:amiga.lib
EXE	= AmigaIsp
AOPTS	= ds dl SET "TESTCODE=1"


##-------------------------------------------------------------------------------

all: $(EXE).ld $(EXE).ro $(EXE)_test

$(EXE).ld : $(OBJ)
	slink from $(OBJ) to $(EXE).ld noicons addsym sc sd lib $(LIB)
	slink from $(EXE).ld to $(EXE) nd sc sd LIB $(LIB)

##-------------------------------------------------------------------------------


$(EXE).ro : $(OBJ)
	phxass $(SRC) to $(EXE).ro noexe

##-------------------------------------------------------------------------------

$(EXE)_test: isp_test.sa
	phxass ds noexe isp_test.sa
	slink with <<
	from lib:startup.o isp_test.o
	to $(EXE)_test addsym
	lib $(LIB) lib:sc.lib lib:startup_stubs.o
<

##-------------------------------------------------------------------------------

$(SRC): $(HDR) makefile

bump:
	bumprevision bump file AmigaIsp_rev.i noc

