head	1.5;
access;
symbols;
locks
	schlote:1.5; strict;
comment	@;; @;


1.5
date	97.04.17.14.51.49;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.14.23.06.35;	author schlote;	state Stable;
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
date	97.03.28.21.34.37;	author schlote;	state Exp;
branches;
next	;


desc
@Load Resident Hack.
@


1.5
log
@Corrected version tag
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
** $Id: mc40_loader.asm 1.4 1997/04/14 23:06:35 schlote Stable schlote $
**
**
	machine 	mc68060
	near	code
	opt !
	incdir	include:
	include	"all_lvo.i"
	include	exec/exec.i
	include	exec/memory.i
	include	exec/types.i
	include	exec/libraries.i
	include	exec/execbase.i

	include	ispemu/isp_debug.i
MYDEBUG	set	0

	include	mc40_rev.i

**-------------------------------------------------------------------------------

	STRUCTURE	MC40_LIBBASE,LIB_SIZE
	ULONG	MC40_SYSBASE
	ULONG	MC40_SEGLIST
	ULONG	MC40_CPU040
	ULONG	MC40_CPU060
	LABEL	MC40_SIZE

tv_Illegal:	EQU	$00000010	* Vector Vier

**-------------------------------------------------------------------------------

	SECTION	loader,CODE

ProgStart:	DBUG	10,"Shell start"
	MOVEQ	#0,D0
	RTS

**-------------------------------------------------------------------------------

LibStart:	ILLEGAL
	dc.l	LibStart
	dc.l             LibEnd
	dc.b	RTF_AUTOINIT
	dc.b             40
	dc.b	NT_LIBRARY
	dc.b             120
	dc.l	_LibName
	dc.l	_LibId
	dc.l	InitVector

**-------------------------------------------------------------------------------

_LibName:	dc.b	'68040.library',0
_LibName040:	dc.b	'CPU40.library',0
_LibName060:	dc.b	'68060.library',0
_LibId:                 VERS
	dc.b	' ('
	DATE
	dc.b	') '
	dc.b	'©1997 by Carsten Schlote, Coenobium Developments',0
	even
**-------------------------------------------------------------------------------

InitVector:	dc.l             MC40_SIZE
	dc.l	funcTable
	dc.l	dataTable
	dc.l	_LibCode
**-------------------------------------------------------------------------------

funcTable:	dc.l	_LibOpen
	dc.l	_LibClose
	dc.l	_LibExpunge
	dc.l	_LibNull
	dc.l	-1

**-------------------------------------------------------------------------------

dataTable:	INITBYTE	LN_TYPE,NT_LIBRARY
	INITLONG	LN_NAME,_LibName
	INITBYTE	LIB_FLAGS,(LIBF_CHANGED+LIBF_SUMUSED)
	INITWORD	LIB_VERSION,VERSION
	INITWORD	LIB_REVISION,REVISION
	INITLONG	LIB_IDSTRING,_LibId
	dc.l	0

**--------------------------------------------------------------------------------
_LibOpen:	ADDQ.W	#1,(LIB_OPENCNT,A6)
	MOVE.L	A6,D0
	RTS
**--------------------------------------------------------------------------------
_LibClose:	MOVEQ	#0,D0
	SUBQ.W	#1,(LIB_OPENCNT,A6)
	BNE.B	.quit
	BSR.W	_LibExpunge
.quit:	RTS
**--------------------------------------------------------------------------------
_LibExpunge:
_LibNull:
	MOVEQ	#0,D0
	RTS
**--------------------------------------------------------------------------------
*	MOVEM.L	D2/A5/A6,-(SP)
*	MOVEA.L	A6,A5                  ; remember libbase
*	MOVEA.L	(MC40_SYSBASE,A5),A6	; get Sysbase
*
*	TST.W	(LIB_OPENCNT,A5)	; not in use - close now !
*	BEQ.W            .expunge
*
*	BSET	#LIBB_DELEXP,(LIB_FLAGS,A5)	; still in use - delay expunge
*	MOVEQ	#0,D0
*	BRA.B	.Expunge_End                   ; do nothing
*
*.expunge:	MOVE.L	(MC40_SEGLIST,A5),D2	; get seglist
*
*	MOVEA.L	A5,A1
*	JSR	(_LVORemove,A6)	; Remove from lib from base
*
*	MOVEQ	#0,D0	; Free lib vector table
*	MOVEA.L	A5,A1
*	MOVE.W	(LIB_NEGSIZE,A5),D0
*	SUBA.L	D0,A1
*	ADD.W	(LIB_POSSIZE,A5),D0
*	JSR	(_LVOFreeMem,A6)
*
*	MOVE.L	D2,D0	; return seglist for libcode
*
*.Expunge_End:	MOVEM.L	(SP)+,D2/A5/A6
*	RTS

**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------

	XDEF	_LibCode
_LibCode:	DBUG	10,"SP:=%08lx\n",SP
	MOVEM.L	d1-d7/a2-A6,-(SP)
	DBUG	10,"Enter Lib...($%08lx) \n",d0

	MOVEA.L	D0,A5		; A4:= LibBase

	MOVE.L	A6,(MC40_SYSBASE,A5)		;
	MOVE.L	A0,(MC40_SEGLIST,A5)

	bsr	_Check060		; Check for 060
	tst.l	d0
	bne	.load060lib

.load040lib:	DBUG	10," load 040 code, "
	LEA	(_LibName040,PC),A1		; Load 040
	MOVEQ	#0,D0
	JSR	(_LVOOpenLibrary,A6)
	MOVE.L	D0,(MC40_CPU040,A5)
	BEQ.B	.quit		; failure.... hmmm
	BRA.B	.returnbase		; ok

.load060lib:	DBUG	10," load 060 code, "
	LEA	(_LibName060,PC),A1		; Load 060
	MOVEQ	#0,D0
	JSR	(_LVOOpenLibrary,A6)
	MOVE.L	D0,(MC40_CPU060,A5)
	BEQ.B	.quit		; failure

.returnbase:	MOVE.L	A5,D0		; return Base
.quit:
	DBUG	10,", end ($%08lx) \n",d0
	MOVEM.L	(SP)+,d1-d7/a2-A6
	DBUG	10,"SP:=%08lx\n",SP
	RTS

**---------------------------------------------------------------------------------
** Check for 060
**---------------------------------------------------------------------------------

	XDEF	_Check060
_Check060:
	movem.l	d2-d7/a2-a6,-(sp)
                        LEA	(.checkcode,pc),a5
	jsr	_LVOSupervisor(a6)	; Do magic
	move.l	d2,d0
	movem.l          (sp)+,d2-d7/a2-a6
	rts


.checkcode:
	MOVE.L	#1,d2	; Remember Stack
	LEA	(.illegal,PC),A2	; Set Illegal Vector
	movec.l          VBR,a3
	MOVE.L	(tv_Illegal,a3),D3	; Remember Illegal Vector
	nop
                	CPUSHA	DC	; Dump

	MOVE.L	A2,(tv_Illegal,a3)
	NOP

.xx	MOVEC	PCR,D0	; Get PCR
.zz
	MOVE.L	D3,(tv_Illegal,a3)	; Restore Illegal Vector
	NOP
                	CPUSHA	DC	; Dump
	rte

	**----------------------------------------


.illegal:	ADD.L	#(.zz-.xx),(2,SP)	; Remember Flag
	MOVE.L	#0,D2                  ; Remember 040 flag
           	rte
**-----------------------------------------------------------------------------------

LibEnd:	NOP
	end
@


1.4
log
@Working Version 40.2, 40.10ß2
@
text
@d10 1
a10 1
** $Id: mc40_loader.asm 1.3 1997/04/14 23:00:04 schlote Exp schlote $
d70 1
a70 1
	dc.b	'©1997 by Carsten Schlote,Coenobium Software',0
@


1.3
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc40_loader.asm 1.2 1997/04/12 13:39:03 schlote Exp schlote $
@


1.2
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc40_loader.asm 1.1 1997/03/28 21:34:37 schlote Exp schlote $
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d14 1
d19 2
d24 5
d34 2
d38 2
d44 2
a45 1
ProgStart:	MOVEQ	#0,D0
d54 1
a54 1
	dc.b             43
d56 1
a56 1
	dc.b	0
d64 6
a69 2
_LibName2:	dc.b	'680x0.library',0
_LibId:	dc.b	'LibLoader 43.1 (27.2.96)'
d75 3
a77 3
	dc.l	LibVectors
	dc.l	InitTab
	dc.l	InitCode
d80 1
a80 1
LibVectors:	dc.l	_LibOpen
d84 1
a84 1
	dc.l	$FFFFFFFF
d88 1
a88 1
InitTab:	INITBYTE	LN_TYPE,NT_LIBRARY
d90 3
a92 3
	INITBYTE	LIB_FLAGS,LIBF_CHANGED|LIBSUMUSED
	INITWORD	LIB_VERSION,43
	INITWORD	LIB_REVISION,1
a96 1

d100 1
a100 1

d106 2
a107 1

d109 1
a109 1
_LibExpunge:	MOVEQ	#0,D0
d111 28
d143 8
a150 3
InitCode:	MOVEM.L	A5/A6,-(SP)
	MOVEA.L	D0,A5		; A5:= LibBase
	MOVE.L	A6,(MC40_SYSBASE,A5)
d153 3
a155 7
	MOVEQ	#0,D0
	BTST	#AFB_FPU40+1,(AttnFlags+1,A6)
	BNE.B	.quit
	BTST	#AFB_68040,(AttnFlags+1,A6)
	BEQ.B	.quit
	BTST	#AFB_FPU40,(AttnFlags+1,A6)
	BEQ.B	.load060
d157 2
a158 1
	LEA	(core040,PC),A1
d161 3
a163 3
	MOVE.L	D0,($002C,A5)
	BEQ.B	.quit
	BRA.B	.returnbase
d165 2
a166 2
	NOP
.load060:	LEA	(core060,PC),A1
d169 2
a170 2
	MOVE.L	D0,($0028,A5)
	BEQ.B	.quit
d172 5
a176 2
.returnbase:	MOVE.L	A5,D0
.quit:	MOVEM.L	(SP)+,A5/A6
d179 21
a199 2
	**------------------------------------------------------------------------
	PRINT	'CHECKING_FOR_060'
d201 2
d204 6
a209 4
	MOVEA.L	#$00FFFFFC,A6	; Set STACK to no mans land
	MOVEA.L	A6,SP

	MOVE.L	(tv_Illegal).L,D3	; Remember Illegal Vector
d211 1
a211 2
	LEA	(.illegal,PC),A6	; Set Illegal Vector
	MOVE.L	A6,(tv_Illegal).L
a212 7
	MOVEC	PCR,D0	; Get PCR
	ANDI.L	#2,D0
	CMP.L	#2,D0
	BEQ.W	.fpuoff
	FNOP                     	; Disable FPU for ExecStartup
	MOVE.L	#2,D0
	MOVEC	D0,PCR
d214 4
a217 16
.fpuoff:	MOVE.L	D3,(tv_Illegal).L	; Restore Illegal Vector
	BRA.B	.dc1

.illegal:	MOVE.L	D3,(tv_Illegal).L	; Illegal no 060 :-)
	MOVE.L	#$DEADBEEF,D3                  ; Remember 040 flag

.dc1:	MOVEA.L	D4,SP	; restore Stack to last state

                        PRINT	'060_CHECK_PASSED/FPU_CONDITIONALY_DISABLED'

	**------------------------------------------------------------------------

core060:	dc.b	'68060.library',0
core040:	dc.b	'68040old.library',0,0
	even
LibEnd:	CNOP	0,16
d219 1
@
