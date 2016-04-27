head	1.4;
access;
symbols;
locks; strict;
comment	@* @;


1.4
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.04.12.13.39.03;	author schlote;	state Exp;
branches;
next	1.1;

1.1
date	96.11.26.21.15.01;	author schlote;	state Exp;
branches;
next	;


desc
@MC68060 Software Package for Amiga Computers
Copyright 1996 by Carsten Schlote.
@


1.4
log
@Working Version 40.2, 40.10ß2
@
text
@
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_macros.i 1.3 1997/04/14 23:00:04 schlote Exp schlote $
**
**

**-------------------------------------------------------------------------------

** Call into emu module : <modul>,<vector>,<Debug text>

CALL_IN:	MACRO

	IFGE	MYDEBUG-20				; Get Debug Output on Call In
	MOVEM.L	A0-a1,-(SP)
	MOVEA.L	(8,SP),A0				; Get Stackframe
	MOVEA.L	(8+4,SP),A1
	DBUG        20,\3,a0,a1
	MOVEM.L	(SP)+,A0-a1
	ENDC

	BRA.L	\1+(\2*8)
	ENDM

**-------------------------------------------------------------------------------

**  <call in stub for module>,<cpu exception vector in VBR A2>

SETVECTOR:	MACRO       ; vector
	LEA	(Vector_\2,PC),A1			; get old vector
	MOVE.L	(\2*4,A2),(A1)                      ; and store for further use.

	LEA	(\1,PC),A1                          ; Get Addr of call in
	MOVE.L	A1,(\2*4,A2)			; set vbr vector
	MOVE.L	A1,(\2*4).W                         ; set to 'base' vbr
	ENDM

@


1.3
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_macros.i 1.2 1997/04/12 13:39:03 schlote Exp schlote $
@


1.2
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_macros.i 1.1 1996/11/26 21:15:01 schlote Exp schlote $
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d20 1
a20 1
	IFD	MYDEBUG				; Get Debug Output on Call In
d24 1
a24 1
	DBUG        10,\3,a0,a1
@
