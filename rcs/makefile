
#-----------------------------------------------------------------------------
#  /\  |\     Silicon Department      Telefax     06404-64760
#  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
#    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
# \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
#-----------------------------------------------------------------------------
# $Id: Makefile 1.1 1996/02/19 23:20:34 schlote Exp schlote $
#-----------------------------------------------------------------------------
#---- Default Regeln
#-----------------------------------------------------------------------------

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
#--- Integer Kernal Emu
#-----------------------------------------------------------------------------

ISP_OBJ = isp_skeleton.o   isp.o
ISP_SCR = isp_skeleton.asm isp.asm
ISP_HDR =
ISP_EXT = isp.doc isp_test.asm

isp_init.o : isp_init.asm isp.asm

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
#---- Compiler RuleZ
#-----------------------------------------------------------------------------

bump:
#	sc:/debugtools/bumprevision BUMP


store:
	ci -q $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)
	ci -q -u $(DOKU_FILES)
	delete *.o

restore:
	co -q -l $(ISP_SCR) $(ISP_HDR) $(ISP_EXT)
	co -q -l $(DOKU_FILES)


