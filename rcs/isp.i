head	1.3;
access;
symbols;
locks; strict;
comment	@* @;


1.3
date	97.04.02.15.34.20;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.03.26.15.28.33;	author schlote;	state stable;
branches;
next	1.1;

1.1
date	97.03.25.20.40.41;	author schlote;	state Exp;
branches;
next	;


desc
@Headerfile for ISP.asm rev 1.1
@


1.3
log
@Current Amiga Release 43.2 ß 1
@
text
@
**------------------------------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**------------------------------------------------------------------------------------------------------
*

* $Id: isp.i 1.2 1997/03/26 15:28:33 schlote stable schlote $

**------------------------------------------------------------------------------------------------------
*
* define statements for constants
* in order to promote readability within the core code itself.
*
**------------------------------------------------------------------------------------------------------

** CAUTION: Frame is accessed via EXC_LV+EXC_* !!!!

SFF0_ISR	equ	4	* W: stack status register
SFF0_IPC	equ	6	* L: stack pc
SFF0_IVOFF	equ	10	* stacked vector offset

	STRUCTURE 	isp_Stack,0	*
	UWORD	EXC_OPWORD	* offset of current opword
	UWORD	EXC_EXTWORD	* offset of current ext opword
	ULONG	EXC_EXTWPTR	* offset of current PC
	UWORD	EXC_CC	* offset of cc register

	UBYTE	SPCOND_FLG	* offset of spc condition flg
	UBYTE	EXC_SAVREG	* offset of old areg index
	UBYTE	EXC_SAVVAL	* offset of old areg value
	UBYTE	EXC_PAD2	* allign stack
	UWORD	EXC_PAD3	* allign to 16 Byte

	STRUCT	EXC_TEMP,16	* offset of temp stack space


	LABEL	EXC_REGS	* offset of all regs         MOVEM <>,(-EXC_REGS,A6)

	LABEL	EXC_DREGS	* offset of all data regs
	ULONG	EXC_D0	* offset of d0
	ULONG	EXC_D1	* offset of d1
	ULONG	EXC_D2	* offset of d2
	ULONG	EXC_D3	* offset of d3
	ULONG	EXC_D4	* offset of d4
	ULONG	EXC_D5	* offset of d5
	ULONG	EXC_D6	* offset of d6
	ULONG	EXC_D7	* offset of d7

	LABEL	EXC_AREGS	* offset of all address regs
	ULONG	EXC_A0	* offset of a0
	ULONG	EXC_A1	* offset of a1
	ULONG	EXC_A2	* offset of a2
	ULONG	EXC_A3	* offset of a3
	ULONG	EXC_A4	* offset of a4
	ULONG	EXC_A5	* offset of a5
	ULONG	EXC_A6	* offset of a6
	ULONG	EXC_A7	* offset of a7

	LABEL            EXC_SIZEOF	* stack frame size(bytes)
	ULONG	EXC_A6OLD	* stack link register <a6> store  LINK MNE

EXC_LV	EQU	-EXC_SIZEOF	* ACESSS Data (EXC_LV+EXC_*,a6)


**------------------------------------------------------------------------------------------------------
** SPecial CONDition FLaGs
**------------------------------------------------------------------------------------------------------

mia7_flg	equ	$04	* (a7)+ flag
mda7_flg	equ	$08	* -(a7) flag
ichk_flg	equ	$10	* chk exception flag
idbyz_flg	equ	$20	* divbyzero flag
restore_flg	equ	$40	* restore -(an)+ flag
immed_flg	equ	$80	* immediate data flag

mia7_bit	equ	$2	* (a7)+ bit
mda7_bit	equ	$3	* -(a7) bit
ichk_bit	equ	$4	* chk exception bit
idbyz_bit	equ	$5	* divbyzero bit
restore_bit	equ	$6	* restore -(a7)+ bit
immed_bit	equ	$7	* immediate data bit

**------------------------------------------------------------------------------------------------------
** Misc.
**------------------------------------------------------------------------------------------------------

size_BYTE	equ	1	* len(byte) == 1 byte
size_WORD	equ 	2	* len(word) == 2 bytes
size_LONG	equ 	4	* len(longword) == 4 bytes


**------------------------------------------------------------------------------------------------------

@


1.2
log
@This first version running
@
text
@d10 1
a10 1
* $Id: isp.i 1.1 1997/03/25 20:40:41 schlote Exp schlote $
@


1.1
log
@Initial revision
@
text
@d10 1
a10 28
* $Id$

**------------------------------------------------------------------------------------------------------
** Offsets of Call-In Table
**------------------------------------------------------------------------------------------------------

_off_chk	equ	$00             ; Table offsets
_off_divbyzero	equ	$04
_off_trace	equ	$08
_off_access	equ	$0c
_off_done	equ	$10

_off_cas	equ	$14
_off_cas2	equ	$18
_off_lock	equ	$1c
_off_unlock	equ	$20

_off_imr	equ	$40
_off_dmr	equ	$44
_off_dmw	equ	$48
_off_irw	equ	$4c
_off_irl	equ	$50
_off_drb	equ	$54
_off_drw	equ	$58
_off_drl	equ	$5c
_off_dwb	equ	$60
_off_dww	equ	$64
_off_dwl	equ	$68
a93 13

**------------------------------------------------------------------------------------------------------

CALLOUT	MACRO
	opt 0
	xdef            \1
\1:	move.l	d0,-(sp)	* d0 retten
	move.l	(TOPOFF+\2,pc),d0	* Hole ZielOffset
	pea.l	((TOPOFF).w,pc,d0.l)      	* Speiche Ziel auf Stack
	move.l	$4(sp),d0                      * d0 restaurieren
	rtd	#$4	* Jump Ziel & pop d0
	opt !
	ENDM
@
