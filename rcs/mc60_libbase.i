head	1.7;
access;
symbols;
locks; strict;
comment	@* @;


1.7
date	97.04.28.20.12.57;	author schlote;	state Exp;
branches;
next	1.6;

1.6
date	97.04.15.03.06.13;	author schlote;	state Exp;
branches;
next	1.5;

1.5
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	97.04.12.13.39.03;	author schlote;	state Exp;
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


1.7
log
@Added Info for Resource Tracking
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
** $Id: mc60_libbase.i 1.6 1997/04/15 03:06:13 schlote Exp schlote $
**
**
**-------------------------------------------------------------------------------
** This is the lib vector table for mc60.lib. The jump table is just in front of
** this structure. Keep care


	STRUCTURE 	mc60_Lib,LIB_SIZE
                        BPTR	mc60_SegList
	APTR	mc60_SysBase
	APTR	mc60_MMUFrame
	LABEL	mc60_SIZEOF


**-------------------------------------------------------------------------------
**
** This is the MMU Frame Structure

	STRUCTURE	mmu,0
	ULONG	mmu_URP		; $00	mc68k URP
	ULONG	mmu_SRP		; $04  mc68k SRP
	ULONG	mmu_TCR		; $08

	APTR	mmu_RootTable		; $0C
	APTR	mmu_PointerTable		; $10
	APTR	mmu_PageTable		; $14

	ULONG	mmu_IllPageDesc		; $18
	APTR	mmu_IllegalPage		; $1C

	ULONG	mmu_RootTableDesc		; $20
	ULONG	mmu_PointerTableDesc	; $24
	ULONG	mmu_IndIllPageDesc	; $28

	STRUCT	mmu_NestCounts,MLH_SIZE 	; $2c

	STRUCT 	mmu_PageList,MLH_SIZE
	APTR	mmu_MemPage
	WORD	mmu_MemPageOffset

	LABEL	mmu_SIZEOF		;

**-------------------------------------------------------------------------------
** Allocated in Chip Mem to save memory - it's only resource tracking !
**-------------------------------------------------------------------------------

	STRUCTURE 	pl_MinNode,MLN_SIZE
	APTR	pl_PageAddr
	LABEL	pl_SIZEOF

**-------------------------------------------------------------------------------
** Must be fast memory !!!! Allocate them last to save memory
**-------------------------------------------------------------------------------

	STRUCTURE	nc_MinNode,MLN_SIZE      ; 0
                        ULONG	nc_Low                   ; 8
                        ULONG            nc_High                  ; 12
                        LABEL	nc_Count	       ; 16


@


1.6
log
@Release 40.11 LibBase
@
text
@d10 1
a10 1
** $Id: mc60_libbase.i 1.5 1997/04/14 23:06:35 schlote Exp schlote $
d47 4
d54 6
d61 3
@


1.5
log
@Working Version 40.2, 40.10ß2
@
text
@d10 1
a10 1
** $Id: mc60_libbase.i 1.4 1997/04/14 23:00:04 schlote Exp schlote $
d55 1
a55 1
                        STRUCT	nc_Count,2*256           ; 16
@


1.4
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_libbase.i 1.3 1997/04/12 13:39:03 schlote Exp schlote $
@


1.3
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_libbase.i 1.2 1996/11/26 23:53:06 schlote Exp schlote $
@


1.2
log
@Reviewed & commented lib startup. Fixed minor bugs
Added SegList Ptr
@
text
@d10 1
a10 1
** $Id: mc60_libbase.i 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d13 15
a27 34
	STRUCTURE LibBase,LIB_SIZE
	UWORD	mc60_Flags			; $22
	APTR	mc60_LibBase		; $24

	ULONG	mc60_pad0			; $28
	ULONG	mc60_pad1           	; $2c

	APTR	mc60_SysBase		; $30		* l
	APTR	mc60_MMUFrame		; $34
	APTR	mc60_CardName		; $38
	APTR	mc60_CdStrap		; $3c
	APTR	mc60_Expansion		; $40
	APTR	mc60_BuildMMU		; $44
	APTR	mc60_TagAddr		; $48

	STRUCT	mc60_Patchport,MP_SIZE	; $4c

	ULONG	mc60_pad2           	; $6e

	APTR	mc60_fplsp			; $72
	APTR	mc60_ilsp			; $76

	APTR	mc60_imem_read		; $7a
	APTR	mc60_dmem_read		; $7e
	APTR	mc60_dmem_write		; $82
	APTR	mc60_imem_read_word		; $86
	APTR	mc60_imem_read_long		; $8a
	APTR	mc60_dmem_read_byte		; $8e
	APTR	mc60_dmem_read_word		; $92
	APTR	mc60_dmem_read_long		; $96
	APTR	mc60_dmem_write_byte	; $9a
	APTR	mc60_dmem_write_word	; $9e
	APTR	mc60_dmem_write_long	; $a2
	APTR	mc60_real_access        	; $a6
d29 4
a32 1
                        BPTR	mc60_SegList		; $aa
d34 3
a36 1
	LABEL	mc60_SIZEOF			; $ae
d38 10
d50 8
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d48 3
a50 1
	LABEL	mc60_SIZEOF			; $aa
@
