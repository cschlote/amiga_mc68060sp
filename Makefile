
#-----------------------------------------------------------------------------
#  /\  |\     Silicon Department      Telefax     06404-64760
#  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
#    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
# \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
#-----------------------------------------------------------------------------
# $Id: Makefile 1.2 1996/02/19 23:22:11 schlote Exp schlote $
#-----------------------------------------------------------------------------
#---- Default Regeln
#-----------------------------------------------------------------------------
# changes fpsp_lib.asm isp.oa os.asm errata fpsp_lib.doc isp.sa isp_test.asm
# ReadMe fpsp_lib.sa fpsp_test.sa isp_lib.asm isp_test.sa test.doc
# fpsp_lite.asm isp_lib.doc Makefile fpsp.sa fpsp_lite.sa isp_lib.sa misc
#





.h.g:
        sc mgst $*.g noobjname $*.h

.c.o:
        sc $*.c

.asm.o:
        phxass Q I sc:Include DS noexe from $*.asm to $*.o

#-----------------------------------------------------------------------------
#--- Default Target
#-----------------------------------------------------------------------------

all : doku isp


#-----------------------------------------------------------------------------

DOKU_FILES = Makefile ReadMe changes errata misc test.doc

doku:
	ci -q -l -m"Changes" $(DOKU_FILES)

#-----------------------------------------------------------------------------
#-			-- Integer Kernal Emu
#-----------------------------------------------------------------------------

ISP_OBJ = isp_skeleton.o   isp.o
ISP_SCR = isp_skeleton.asm isp.asm
ISP_HDR =
ISP_EXT = isp.doc isp_test.asm

isp.resource : $(ISP_OBJ)
#	phxlnk from $(ISP_OBJ) to isp.resource sc sd
        slink with <<
                TO              isp.resource
                FROM            $(ISP_OBJ)
                MAP             isp.map hxsflo
                SC SD NOICONS ADDSYM
<
#                LIBRARY         $(LIB)
        @echo "*n******* Linked 'isp.resource' Executable *n"

ci_isp:
	ci -q -l $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)

co_isp:
	co -q -l $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)

isp:  isp.resource

#-----------------------------------------------------------------------------
#--- FPU Kernal Emu
#-----------------------------------------------------------------------------

FPSP_OBJ = fpsp_skeleton.o  fpsp.o
FPSP_SCR = fpsp_skeleton.asm fpsp.asm
FPSP_HDR =
FPSP_EXT = fpsp.doc fpsp_test.asm

fpsp.resource : $(FPSP_OBJ)
#	phxlnk from $(FPSP_OBJ) to fpsp.resource sc sd
        slink with <<
                TO              fpsp.resource
                FROM            $(FPSP_OBJ)
                MAP             fpsp.map hxsflo
                SC SD NOICONS ADDSYM
<
#                LIBRARY         $(LIB)
        @echo "*n******* Linked 'isp.resource' Executable *n"

ci_fpsp:
	ci -q -l $(FPSP_SCR) $(FPSP_HDR) $(FPSP_EXT)

co_fpsp:
	co -q -l $(FPSP_SCR) $(FPSP_HDR) $(FPSP_EXT)

fpsp:  fpsp.resource

#-----------------------------------------------------------------------------
#---- Compiler RuleZ
#-----------------------------------------------------------------------------

bump:
#	sc:/debugtools/bumprevision BUMP


store:
	ci -q $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)
	ci -q $(FPSP_SCR) $(FPSP_HDR) $(FPSP_EXT)
	ci -q -u $(DOKU_FILES)
	delete *.o

restore:
	co -q -l $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)
	co -q -l $(FPSP_SCR) $(FPSP_HDR) $(FPSP_EXT)
	co -q -l $(DOKU_FILES)


clean:
	@delete #?.map #?.log #?.o

