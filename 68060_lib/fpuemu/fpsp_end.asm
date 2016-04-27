
**----------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**----------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: fpsp.asm,v 1.0.1.4 1997/04/21 20:35:14 schlote Exp schlote $
**
* This file is derived from the isp.asm,v 1.0.1.4 1996/02/19 23:02:26
*
* Use PhxAss (AmiNet) to compile.
*
* ALL RIGHTS RESERVED BY CARSTEN SCHLOTE, COENOBIUM DEVELOPMENTS
*
**------------------------------------------------------------------------------------------------------
	NOLIST

	incdir	include:
	include	all_lvo.i
	include	exec/exec.i
	include	exec/types.i
	include	exec/nodes.i
	include	exec/resident.i

**------------------------------------------------------------------------------------------------------

	include          fpsp_debug.i
MYDEBUG	SET         	0	; Current Debug Level
DEBUG_DETAIL 	set 	10	; Detail Level

**------------------------------------------------------------------------------------------------------

	SECTION	FPSP060,CODE
	NEAR	CODE
	XDEF	FPSP060_End
	XDEF	___stub
___stub:
FPSP060_End:
	NOP
                RTS
	end
