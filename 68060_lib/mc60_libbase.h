
/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_libbase.h 1.7 1997/04/28 20:13:34 schlote Exp $
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

