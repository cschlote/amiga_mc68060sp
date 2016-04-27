head	1.11;
access;
symbols;
locks; strict;
comment	@;; @;


1.11
date	97.04.21.23.01.00;	author schlote;	state Exp;
branches;
next	1.10;

1.10
date	97.04.17.14.51.49;	author schlote;	state Exp;
branches;
next	1.9;

1.9
date	97.04.15.03.08.43;	author schlote;	state Stable;
branches;
next	1.8;

1.8
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.7;

1.7
date	97.04.14.23.06.00;	author schlote;	state Exp;
branches;
next	1.6;

1.6
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.5;

1.5
date	97.04.14.22.47.28;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.12.13.39.03;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	96.11.27.00.10.35;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	96.11.26.23.53.06;	author schlote;	state Exp;
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


1.11
log
@Repaired Info String
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
** $Id: mc60_startup.asm 1.10 1997/04/17 14:51:49 schlote Exp schlote $
**
**
**	Code Taken from RKM Companium
**
	machine 68060    * compile for 060
	opt ds dl        * create debug info
	near

	include     	mc60_system.i
	include	mc60_libbase.i

**-------------------------------------------------------------------------------

	XREF	_LibInit

**-------------------------------------------------------------------------------

	SECTION	startup,CODE
	XDEF	LibStart

LibStart:	MOVEQ	#0,D0	; Return to caller : no exec
	RTS


**-------------------------------------------------------------------------------

	XREF	RomTagEnd              ; End of Small Data Module

RomTag:	ILLEGAL
	dc.l	RomTag	; MAGIC !!
	dc.l	RomTagEnd
	dc.b	RTF_AUTOINIT	; Mode
	dc.b	VERSION                ; Version
	dc.b	NT_LIBRARY             ; Typ
	dc.b             130	; Pri
	dc.l	LibName	; Name of Library
	dc.l	IDString	; Version Tag
	dc.l	InitTable

**-------------------------------------------------------------------------------

LibName:	dc.b	'68060.library',0
IDString:	VERS
	dc.b	" ("
	DATE
	dc.b	")
	dc.b	"©1997 by Carsten Schlote, Coenobium Developments",0
                        even
**-------------------------------------------------------------------------------

InitTable:	dc.l	mc60_SIZEOF	; Size of LibBase
	dc.l	funcTable                      ; auto init stuff
	dc.l	dataTable
	dc.l	_LibInit	; external InitCode in C .. asm sux.

**-------------------------------------------------------------------------------


funcTable:	dc.l	_LibOpen	; Standard Funktions
	dc.l	_LibClose                      ; Standard Close
	dc.l	_LibExpunge                    ; Standard Expunge
	dc.l	_LibNop                        ; reserved * ARexx ??? ;-)
	dc.l	-1
	cnop	0,4

**-------------------------------------------------------------------------------

dataTable:	INITBYTE	LN_TYPE,NT_LIBRARY             ; Init some values...
	INITLONG	LN_NAME,LibName
                        INITBYTE	LIB_FLAGS,(LIBF_CHANGED|LIBF_SUMUSED),
	INITWORD	LIB_VERSION,VERSION
	INITWORD	LIB_REVISION,REVISION
	INITLONG	LIB_IDSTRING,IDString
                        dc.w	0
                        cnop	0,4

**-------------------------------------------------------------------------------

_LibOpen:	ADDQ.W	#1,(LIB_OPENCNT,A6)	; Lib Opened - inc count
	MOVE.L	A6,D0                        	; return
	RTS

**-------------------------------------------------------------------------------

_LibClose:	MOVEQ	#0,D0
	SUBQ.W	#1,(LIB_OPENCNT,A6)        	; != 0 - still in use
	BNE.B            .quit
                        BTST.B	#LIBB_DELEXP,(LIB_FLAGS,A6)    ; only for delayed expunge
                        BEQ	.quit
	BSR.W	_LibExpunge	; dispose lib.
.quit:	RTS

**-------------------------------------------------------------------------------

_LibExpunge:	* Code removed and RCSed ......

**-------------------------------------------------------------------------------

_LibNop:
	MOVEQ	#0,D0
	RTS

@


1.10
log
@Corrected version tag
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.9 1997/04/15 03:08:43 schlote Stable schlote $
d57 1
a57 1
	dc.b	"©1997 by Carsten Schlote, Coenobium Developments,0
@


1.9
log
@Release 40.11 Lib Resident Tag and Std Code for Lib.
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.8 1997/04/14 23:06:35 schlote Exp schlote $
d56 2
a57 1
	dc.b	") by Carsten Schlote, Software Developments\r\n",0
@


1.8
log
@Working Version 40.2, 40.10ß2
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.7 1997/04/14 23:06:00 schlote Exp schlote $
d104 1
a104 28
_LibExpunge:
	MOVEM.L	D2/A5/A6,-(SP)
	MOVEA.L	A6,A5                          ; remember libbase
	MOVEA.L	(mc60_SysBase,A5),A6	; get Sysbase

	TST.W	(LIB_OPENCNT,A5)	; not in use - close now !
	BEQ.W            .expunge

	BSET	#LIBB_DELEXP,(LIB_FLAGS,A5)	; still in use - delay expunge
	MOVEQ	#0,D0
	BRA.B	.Expunge_End                   ; do nothing

.expunge:	MOVE.L	(mc60_SegList,A5),D2	; get seglist

	MOVEA.L	A5,A1
	JSR	(_LVORemove,A6)	; Remove from lib from base

	MOVEQ	#0,D0	; Free lib vector table
	MOVEA.L	A5,A1
	MOVE.W	(LIB_NEGSIZE,A5),D0
	SUBA.L	D0,A1
	ADD.W	(LIB_POSSIZE,A5),D0
	JSR	(_LVOFreeMem,A6)

	MOVE.L	D2,D0	; return seglist for libcode

.Expunge_End:	MOVEM.L	(SP)+,D2/A5/A6
	RTS
@


1.7
log
@*** empty log message ***
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.6 1997/04/14 23:00:04 schlote Exp schlote $
@


1.6
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.5 1997/04/14 22:47:28 schlote Exp schlote $
@


1.5
log
@Working version
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.4 1997/04/12 13:39:03 schlote Exp schlote $
@


1.4
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.3 1996/11/27 00:10:35 schlote Exp schlote $
d53 1
a53 3

	dc.b	'\0$VER: '
IDString:		VERS
d55 1
a55 1
		DATE
@


1.3
log
@Reviewed & commented lib startup.
@
text
@d10 1
a10 1
** $Id: mc60_startup.asm 1.1 1996/11/26 21:15:01 schlote Exp schlote $
a25 14
	XREF	__SetIllegalPageValue
	XREF	__SetIllegalPageMode
	XREF	__GetIllegalPage

	XREF	__SetZeroPageMode
	XREF	__SetPageProtectMode
	XREF	__SetRomAddress

	XREF	__CheckMMU
	XREF	__BuildMMUTables
	XREF	__Set060MMUTables

	XREF	_FlushMMU

a29 13
LibStart:

*	lea	(data,pc),a0	; For first time checks for CPR
*	move.l	a0,d0                          ; should be changed to a
*	move.l	4.w,a6	; MakeLibrary() Call
*
*	DBUG	1,"%lc%lc",#$1b,#$63
*
*	DBUG	1,"ShellStart\n"
*	bsr              _LibInit
*
*data:	dcb.b	mc60_SIZEOF
*	cnop	0,4
d31 1
a31 2

	MOVEQ	#0,D0	; Return to caller : no exec
d37 1
a37 1
	XREF	RomTagEnd                      ; End of Small Data Module
d43 2
a44 2
	dc.b	37                             ; Version
	dc.b	NT_LIBRARY                     ; Typ
a73 12

	dc.l	__SetIllegalPageValue          ; Illegal Page Funktions
	dc.l	__SetIllegalPageMode
	dc.l	__GetIllegalPage

	dc.l	__SetZeroPageMode	; Set Protection of first 4k Mem

	dc.l	__SetPageProtectMode	; Set a range of funktion to a cache mode

	dc.l	__SetRomAddress	; Map KickAddr to new address

	dc.l	_FlushMMU	; Hmm, CPUSH flush ATCs for a0-(a0+16)
@


1.2
log
@Reviewed & commented lib startup. Fixed minor bugs
@
text
@d13 2
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
a42 3
	lea	(data,pc),a0
	move.l	a0,d0
	move.l	4.w,a6
d44 4
d49 6
a55 2
	DBUG	1,"ShellStart\n"
	bsr              _LibInit
d57 1
a57 1
	MOVEQ	#0,D0
a59 2
data:                   dcb.b	mc60_SIZEOF
	cnop	0,4
d63 1
a63 1
	XREF	RomTagEnd
d66 1
a66 1
	dc.l	RomTag
d72 2
a73 2
	dc.l	LibName
	dc.l	IDString
d86 1
d96 4
a99 4
funcTable:	dc.l	_LibOpen
	dc.l	_LibClose
	dc.l	_LibExpunge
	dc.l	_LibNop
d101 1
a101 1
	dc.l	__SetIllegalPageValue
d105 3
a107 3
	dc.l	__SetZeroPageMode
	dc.l	__SetPageProtectMode
	dc.l	__SetRomAddress
d109 3
a111 1
	dc.l	_FlushMMU
d117 1
a117 1
dataTable:	INITBYTE	LN_TYPE,NT_LIBRARY
d128 2
a129 3
_LibOpen:	ADDQ.W	#1,(LIB_OPENCNT,A6)
	BCLR	#3,(mc60_Flags,A6)
	MOVE.L	A6,D0
d135 1
a135 1
	SUBQ.W	#1,(LIB_OPENCNT,A6)
d137 3
a139 3
	BTST	#3,(mc60_Flags,A6)
	BEQ.B            .quit
	BSR.W	_LibExpunge
d146 5
a150 5
	MOVEA.L	A6,A5
	MOVEA.L	(mc60_LibBase,A5),A6
	TST.W	(LIB_OPENCNT,A5)
	BEQ.W            .exp
	BSET	#3,(mc60_Flags,A5)
d152 1
d154 3
a156 1
	BRA.B	.Expunge_End
a157 1
.exp:	MOVE.L	(mc60_SysBase,A5),D2
d159 3
a161 2
	JSR	(_LVORemove,A6)
	MOVEQ	#0,D0
d167 2
a168 1
	MOVE.L	D2,D0
a178 145
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**
**	XREF	_Install_Exec_Patches
**	XREF	_Install_Dispatcher
**	XREF	_Install_Caches
**
**	XREF	_Install_Mem_Library
**	XREF	_Install_Int_Emulation
**	XREF	_Install_FPU_Emulation
**
**	XREF	_Install_Link_Libraries
**
**	*-------------------------------------------------------------------------------
**	XDEF	initRoutine
**
***>	d0 = LibBase
***>	a6 = ExecBase
***<	d0 = NULL || Libbase
**
**initRoutine:
**	MOVEM.L	D1-D7/A0-A6,-(SP)
**	MOVE.L	(4).w,a6	; just to be sure
**	MOVEA.L	D0,A5
**
**	DBUG	1,"MC68060 Support Library LibInit (Version%ld.%ld)\n",#VERSION,#REVISION
**
**	CMPI.W	#37,(LIB_VERSION,A6)	; is kick >= 2.x
**	BCS.B	.wrongkick
**
**	BTST.B	#AFB_68040,(AttnFlags+1,A6)	; is there a 68040
**	BNE.B	.Init_060
**
**.wrongkick:
**	DBUG	10, "Found wrong Kickstartversion\n"
**	MOVE.L	a5,a1	; FreeLib Memory - immediatly.
**	MOVEQ	#0,D0
**	MOVE.W	(LIB_NEGSIZE,A5),D0
**	SUBA.L	D0,A1
**	ADD.W	(LIB_POSSIZE,A5),D0
**	JSR	(_LVOFreeMem,A6)
**                        BRA	_LibNop	; return d0=NULL
**
**.Init_060:
**	DBUG	10,"Found right Kickstartversion\nInit Library Code at $%08lx\n",A5
**
**	MOVEA.L	D0,A5	; a5 = LibBase
**
**	MOVE.L	A5,(mc60_LibBase,A5)	; Store Code In LibBase for Access in LibCalls
**	MOVE.L	A6,(mc60_SysBase,A5)
**
**	MOVE.L	#__BuildMMUTables,(mc60_BuildMMU,A5)	; Store Values for Check
**	MOVE.L	#$00F03400,(mc60_TagAddr,A5)
**
**	DBUG	10,"... Install phase5 PatchPort\n"
**
**	LEA	(mc60_Patchport,A5),A1	; Install Patchport
**	MOVE.B	#NT_MSGPORT,(LN_TYPE,A1)
**	MOVE.B	#-128,(LN_PRI,A1)
**	LEA	(FPUPatchPortName,PC),A0
**	MOVE.L	A0,(LN_NAME,A1)
**	MOVE.B	#PA_IGNORE,(MP_FLAGS,A1)
**	LEA	(MP_MSGLIST,A1),A0
**	NEWLIST	a0
**	JSR	(_LVOAddPort,A6)
**
**	DBUG	10,"... Install link libs at PatchPort"
**
**	JSR	(_Install_Link_Libraries).L	; Link MMU Libraries
**
**	*-------------------------------------------------------------------------------
**
**	JSR	(_LVOForbid,A6)	; Diable Scheduling
**
**	MOVEQ	#0,D0                          ; FLush & Disable all caches
**	MOVEQ	#-1,D1
**	JSR	(_LVOCacheControl,A6)
**	MOVE.L	D0,-(SP)	; Save state to stack
**
**	*-------------------------------------------------------------------------------
**
**                        DBUG	10,"Install ExecPatches -\n"
**
**	JSR	(_Install_Exec_Patches).L	; Install 68040.lib execpatches
**	OR.W	#(AFF_68040|AFF_68030|AFF_68020|AFF_68010),(AttnFlags,A6)	; Set AttnFlags
**
**	*-------------------------------------------------------------------------------
**
**                        DBUG	10,"Install Emu MemCode to Base\n"
**	JSR	(_Install_Mem_Library).L	; Setup Emulation Vectors
**                        DBUG	10,"Install Emu ISP Code to Base & VBR\n"
**	JSR	(_Install_Int_Emulation).L
**                        DBUG	10,"Install Emu FPSP Code to Base& VBR\n"
**	JSR	(_Install_FPU_Emulation).L
**
**	ORI.W	#(AFF_FPU40|AFF_68882|AFF_68881),(AttnFlags,A6)
**                        DBUG	10,"... set AttnFlags FPU Flags\n"
**
**	DBUG	10,"Install Dispatcher\n"
**	JSR	(_Install_Dispatcher).L        ; Install a new dispatcher for FPU
**
**	*-------------------------------------------------------------------------------
**
***	MOVE.L	a5,-(sp)
***	LEA	(__CheckMMU,PC),A5	;Check For MMU
***	JSR	(_LVOSupervisor,A6)
***	move.l	(sp)+,a5
***	TST.L	D0
***	BEQ.B	.no_MMU
**
***	JSR	(__BuildMMUTables).L	;Build the tables now
***	TST.L	D0
***	BEQ.B	.no_MMU
**
***                        MOVE.L	D0,(mc60_MMUFrame,a5)	;Save MMU Frame
**
***	MOVE.L	a5,-(sp)
***	LEA	(__Set060MMUTables,PC),A5	;setup MMU
***	JSR	(_LVOSupervisor,A6)
***	MOVE.L	(sp)+,a5
**.no_MMU
**	*-------------------------------------------------------------------------------
**
***	JSR	(_Install_Caches).L         	; Install 060 Caches
**
**.testexit
**	MOVE.L	(SP)+,D0	; Restore Cache State
**	MOVEQ	#-1,D1
**	JSR	(_LVOCacheControl,A6)
**
**	JSR	(_LVOPermit,A6)
**	MOVE.L	A5,D0
**	MOVEM.L	(SP)+,D1-D7/A0-A6
**	RTS
**
**; --------------------------------------------------------------------------
**
**
**FPUPatchPortName:	dc.b	'68060_PatchPort',0
**
**
**
@
