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
**  /\  |\     Silicon Department         Telefax             06404-64760
**  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
**    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
** \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_debug.i 1.3 1997/04/14 23:00:04 schlote Exp schlote $
**
**
** Assemble, then link lib:amiga.lib,lib:debug.lib
***-------------------------------------------------------------------------------
** Set MYDEBUG to != 0 for Debug output. Output if \1 <= MYDEBUG

	NOLIST
	INCLUDE	"exec/types.i"
	INCLUDE	"hardware/custom.i"
	LIST

MYDEBUG	SET	0
DEBUG_DETAIL 	set 	10


**-------------------------------------------------------------------------------
*
* Sample program calling DBUG macro
*
*	DBUG	x,template,...

**-------------------------------------------------------------------------------
* note - current 2.0 debug.lib has this entry

	XREF	KPrintF




**-------------------------------------------------------------------------------
* DBUG macro for format string and two variables
*	 preserves all registers
*        outputs to serial port   link with amiga.lib,debug.lib
* Usage: pass name of format string,value,value
*        values may be register name, variablename(PC), or #value
*
**-------------------------------------------------------------------------------
* The debugging macro DBUG
* Only generates code if MYDEBUG is > 0
*


DBUG	MACRO	* passed name of format string, with args on stack
	NOLIST

	IFGT	MYDEBUG
DBUG_LEVEL	SET         DEBUG_DETAIL-\1

	IFGE	DBUG_LEVEL
DBUG_STKCNT	SET	0		* Remember to pop stack

	movem.l 	d0-d1/a0-a1,-(sp)

	IFNC	'\9',''
	move.l	\9,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\8',''
	move.l	\8,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\7',''
	move.l	\7,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\6',''
	move.l	\6,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\5',''
	move.l	\5,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\4',''
	move.l	\4,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	IFNC	'\3',''
	move.l	\3,-(sp)
DBUG_STKCNT	SET	DBUG_STKCNT+4
	ENDC

	lea.l	.PSS\@@(pc),A0
	lea.l	(SP),A1

	XREF	KPrintF
	jsr	KPrintF
	lea.l	(DBUG_STKCNT,sp),sp
	movem.l 	(sp)+,d0-d1/a0-a1
	bra.w	.PSE\@@
.PSS\@@:
	dc.b	\2
	dc.b	0
                        even
.PSE\@@:
	ENDC
	ENDC
	LIST
	ENDM


**-------------------------------------------------------------

@


1.3
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_debug.i 1.2 1997/04/12 13:39:03 schlote Exp schlote $
@


1.2
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: isp_debug.i 1.1 1997/04/02 15:30:56 schlote Exp $
@


1.1
log
@Initial revision
@
text
@a1 1

d10 1
a10 1
** $Id$
d13 3
d17 1
a17 3
*
* Assemble, then link lib:amiga.lib,lib:debug.lib
*
d19 2
d22 2
a23 1
MYDEBUG	SET	1
d26 3
a28 2
* The debugging macro DBUG
* Only generates code if MYDEBUG is > 0
d30 1
a30 1
	IFGT	MYDEBUG
d32 1
d34 1
d38 3
d47 5
d56 1
d58 1
d60 1
d62 1
a62 3
PUSHCOUNT	SET	0

	movem.l 	d0-d7/a0-a6,-(sp)
d66 1
a66 1
PUSHCOUNT	SET	PUSHCOUNT+4
d71 1
a71 1
PUSHCOUNT	SET	PUSHCOUNT+4
d76 1
a76 1
PUSHCOUNT	SET	PUSHCOUNT+4
d81 1
a81 1
PUSHCOUNT	SET	PUSHCOUNT+4
d86 1
a86 1
PUSHCOUNT	SET	PUSHCOUNT+4
d91 1
a91 1
PUSHCOUNT	SET	PUSHCOUNT+4
d96 1
a96 1
PUSHCOUNT	SET	PUSHCOUNT+4
d104 2
a105 2
	lea.l	(PUSHCOUNT,sp),sp
	movem.l 	(sp)+,d0-d7/a0-a6
d110 1
a110 1
	cnop	0,2
d113 1
a116 16
	ENDC

	IFEQ	MYDEBUG
DBUG	MACRO
* disabled debug macro
	ENDM
	ENDC

*
* Sample program calling DBUG macro
*
*	DBUG	strTest,#0,#0


DEBUG_DETAIL 	set 10

d118 1
@
