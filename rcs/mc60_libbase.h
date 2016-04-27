head	1.7;
access;
symbols;
locks; strict;
comment	@ * @;


1.7
date	97.04.28.20.13.34;	author schlote;	state Exp;
branches;
next	1.6;

1.6
date	97.04.15.03.05.15;	author schlote;	state Exp;
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
/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_libbase.h 1.6 1997/04/15 03:05:15 schlote Exp schlote $
**
*/

//**-----------------------------------------------------------------------------
// This is the lib vector table for mc60.lib. The jump table is just in front
// this structure. Keep care

struct mc60_Lib
{
	struct Library 	Lib;            // Standard LibBase
	BPTR		SegList;	// Library SegList
	APTR		SysBase;	// SysBase Cache
	APTR		MMUFrame;	// Pointer to MMU Frame
};

//**-------------------------------------------------------------------------------
// This is the MMU Frame Structure

struct mc60_mmu
{
	ULONG	mmu_URP;		// Register Mirror - MMU Regs
	ULONG	mmu_SRP;
	ULONG	mmu_TCR;                // Translation Ctrl Defaults.

	APTR	mmu_RootTable;          // Pointer to 4k page aligned tables
	APTR	mmu_PointerTable;
	APTR	mmu_PageTable;

	ULONG	mmu_IllPageDesc;   	// Std PageDesc for DummyPage
	APTR	mmu_IllegalPage;	// Ptr to dummy page

	ULONG	mmu_RootTableDesc;   	// Def RootDesc to Def PointerTable
	ULONG	mmu_PointerTableDesc;   // Def PtrDesc to Def Page
	ULONG	mmu_IndIllPageDesc;	// IndirektDesc to Pagedescriptor

	struct MinList mmu_NestCounts;	//  STRUCT mc60_mmu_SegList,MLH_SIZE

	//------- Alloction Addons for optimized tables

        struct MinList mmu_PageList;	// Resource Tracking by List

        APTR	mmu_MemPage;        	// Addr of last Page
        WORD    mmu_MemPageOffset;      // neg. Offset to next free address
};

//**-------------------------------------------------------------------------------

struct mc60_pl
{
	struct MinNode	pl_Node;
	APTR		pl_PageAddr;		// Where to free 4K MemPage
};

//**-------------------------------------------------------------------------------

struct mc60_nc
{
	struct MinNode 	nc_Node;        // Segment AllocVec'ed
	ULONG           nc_Low;         // 1k Segment Range !
	ULONG           nc_High;
        UWORD		nc_Count; 	// Begin of Word Array
};

@


1.6
log
@Release 40.11 LibBase
@
text
@d10 1
a10 1
** $Id: mc60_libbase.h 1.5 1997/04/14 23:06:35 schlote Exp schlote $
d31 1
a31 1
	ULONG	mmu_URP;			// Register Mirror - MMU Regs
d33 1
a33 1
	ULONG	mmu_TCR;                        // Translation Ctrl Defaults.
d35 1
a35 1
	APTR	mmu_RootTable;          	// Pointer to 4k page aligned tables
d39 2
a40 2
	ULONG	mmu_IllPageDesc;   		// Std PageDesc for DummyPage
	APTR	mmu_IllegalPage;		// Ptr to dummy page
d42 3
a44 3
	ULONG	mmu_RootTableDesc;   		// Def RootDesc to Def PointerTable
	ULONG	mmu_PointerTableDesc;           // Def PtrDesc to Def Page
	ULONG	mmu_IndIllPageDesc;		// IndirektDesc to Pagedescriptor
d46 16
a61 1
	struct MinList mmu_NestCounts;		//  STRUCT mc60_mmu_SegList,MLH_SIZE
@


1.5
log
@Working Version 40.2, 40.10ß2
@
text
@d10 1
a10 1
** $Id: mc60_libbase.h 1.4 1997/04/14 23:00:04 schlote Exp schlote $
d31 2
a32 2
	APTR	mmu_URP;			// Register Mirror - MMU Regs
	APTR	mmu_SRP;
@


1.4
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_libbase.h 1.3 1997/04/12 13:39:03 schlote Exp schlote $
@


1.3
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_libbase.h 1.2 1996/11/26 23:53:06 schlote Exp schlote $
@


1.2
log
@Added SegList Ptr
@
text
@d10 1
a10 1
** $Id: mc60_libbase.h 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d14 5
a18 1
struct MC60LibBase
d20 5
a24 1
	struct Library 	Lib;              		// $00
d26 2
a27 2
	UWORD		Flags;				// $22
	APTR		LibBase;			// $24
d29 16
a44 2
	ULONG		pad0;				// $28
	ULONG		pad1;	           		// $2c
d46 2
a47 28
	APTR		SysBase;			// $30		* l
	APTR		MMUFrame;			// $34
	APTR		CardName;			// $38
	APTR		CdStrap;			// $3c
	APTR		Expansion;			// $40

	APTR		BuildMMU;			// $44
	APTR		TagAddr;			// $48

	struct MsgPort	PatchPort;			// $4c

	ULONG		mc60_pad2;     			// $6e

	APTR		mc60_fplsp;			// $72
	APTR		mc60_ilsp;			// $76

	APTR		imem_read;			// $7a
	APTR		dmem_read;			// $7e
	APTR		dmem_write;			// $82
	APTR		imem_read_word;			// $86
	APTR		imem_read_long;			// $8a
	APTR		dmem_read_byte;			// $8e
	APTR		dmem_read_word;			// $92
	APTR		dmem_read_long;			// $96
	APTR		dmem_write_byte;		// $9a
	APTR		dmem_write_word;		// $9e
	APTR		dmem_write_long;		// $a2
	APTR		real_access;        		// $a6
d49 1
a49 1
	BPTR		SegList;			// $aa
d51 6
a56 1
//	LABEL	mc60_SIZEOF				// $aa
a58 1
//**-------------------------------------------------------------------------------
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d52 2
@
