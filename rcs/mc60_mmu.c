
/**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department         Telefax             06404-64760
**  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
**    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
** \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
**--------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_build.c 1.2 1997/04/14 22:47:28 schlote Exp schlote $
**
**--------------------------------------------------------------------------------
*/
// #define __USE_SYSBASE
// include	<clib/alib_protos.h>
extern __stdargs void NewList(struct List*);

//**--------------------------------------------------------------------------------

#include	<proto/exec.h>
#include <exec/exec.h>
#include <exec/execbase.h>
#include <exec/memory.h>
#include <exec/libraries.h>
#include <exec/lists.h>
#include <exec/nodes.h>

#include <proto/expansion.h>
#include <libraries/configvars.h>

//**--------------------------------------------------------------------------------

#include "mc60_rev.h"
#include	"mc60_Debug.h"
#include	"mc60_LibBase.h"

#define REG(x) register __ ## x

//**--------------------------------------------------------------------------------

extern __regargs struct mc60_mmu* Map_PatchArea(struct mc60_mmu*);

//**--------------------------------------------------------------------------------
//** FreeMMUFrame
//**--------------------------------------------------------------------------------
//**
//** Free MMUFrame, traverse lists and free custom pages, then delte default
//** pages and Structure.

void FreeMMUFrame(struct mc60_mmu *fptr)
{
struct mc60_nc* nc;				// Ptr to nest count tables
ULONG *rptr,rdesc;				// Ptr to 128 RootTable and current Desc
ULONG *tptr,tdesc;            // Ptr to 128 PointerTable and curr. desc
ULONG *pptr;						// Ptr to 64 PageTable
int i,j;

	D(bug("\tFreeMMUFrame\n"));
	if ( fptr )
	{
   	//*****************************************************************
      //*** Trackdown tree and free all custom chunks

      if ( fptr->mmu_RootTable &&		// Default tables were inited ??
           fptr->mmu_PointerTable &&
           fptr->mmu_PageTable )
      {
			//-------------------------------------------------
      	rptr = (ULONG*)fptr->mmu_RootTable;					// Copy APTR to Ptr;
      	for ( i = 0; i<128; i++)								// Scan complet RootTable
      	{
      	   rdesc = rptr[i];                     			// Get current RootDesc
            if ((rdesc|3)!= fptr->mmu_RootTableDesc)	// Custom Entry ?
            {
					//------------------------------------------
            	tptr = (ULONG*)( rdesc & ~0x1ff );			// Get Custom PointerTab Addr
            	for ( j = 0; j<128; j++ )						// Scan custom ptr table
            	{
            		tdesc = tptr[j];             				// Get custom ptr desc.
            		if ((tdesc|3)!=fptr->mmu_PointerTableDesc) // Custom Entry ?
            		{
            			pptr = (ULONG*)(tdesc & ~0x1ff);		// Get custom PageTab Addr
                     FreeMem( pptr, 64*4); 					// Free custom PageTable
            		}
            	}
					//------------------------------------------
            	FreeMem( tptr, 128*4 );			// Free custom PointerTable
            }
      	}
      }
      //*****************************************************************
      // Free Base MMU Tables - but only if allocated

      if (fptr->mmu_RootTable    ) FreeMem( fptr->mmu_RootTable   , 128*4 );
      if (fptr->mmu_PointerTable ) FreeMem( fptr->mmu_PointerTable, 128*4 );
      if (fptr->mmu_PageTable    ) FreeMem( fptr->mmu_PageTable   ,  64*4 );

      FreeMem( fptr->mmu_IllegalPage,   4096 );    		// Free DummyPage

      nc = (struct mc60_nc*)fptr->mmu_NestCounts.mlh_Head;	// Delete NestCounts
      while ( nc->nc_Node.mln_Succ )
      	FreeVec(	nc = (struct mc60_nc*)RemHead((struct List*)&fptr->mmu_NestCounts ));

		FreeMem( fptr, sizeof(struct mc60_mmu) );				// Free MMUFrame
	}
}

//**--------------------------------------------------------------------------------
//** Alloc Memory Aligned
//**--------------------------------------------------------------------------------
//**
//** Allocate aligned Memory chunks reversed from PUBLIC mem pool.

APTR AllocMemAligned( ULONG size, ULONG align )
{
APTR mptr;
	if ( mptr = AllocMem( size+align, MEMF_PUBLIC | MEMF_REVERSE | MEMF_CLEAR ) )
	{
      Forbid();													// Don't disturb
		FreeMem(mptr,size+align);              			// Free mem chunk legally
		mptr = AllocAbs( size,
				(APTR)( ((ULONG)(mptr)+ align)&(~align)) ); // Now round addr to next align
      Permit();													  // Allocate and free system
	}
	D2(bug("AllocMemAligned(%08lx,%08lx):=%08lx\n",size,align,mptr));
   return mptr;
}

//**--------------------------------------------------------------------------------
//** Map Memory
//**--------------------------------------------------------------------------------
//** Add the memory range to the mmu table and set cache mode.

struct mc60_mmu *Map_Memory(struct mc60_mmu* fptr, ULONG addr, ULONG size , ULONG mode)
{
ULONG spage,epage;			// Number of 4 KB aligned Page
ULONG *rptr,rindx;         // Index to RootTable
ULONG *tptr,tindx;         // Index to PointerTable
ULONG *pptr,pindx;         // Index to PageTable
ULONG *mptr;
BOOL rc = FALSE;
int i;

	D2(bug("\tMap Memory: %08lx, %08lx, %04lx\n",addr,size,mode));

	mode |= 1;					// Or PageResident to Mode

	if ( fptr )					// Only if MMUFrame valid.
	{
		for(                                // 2^12 = 4096
			spage = addr >> 12, 					// Calculate Page Number for start
   	   epage = (addr+size-1) >> 12 ;    //                       for end
   	   spage <= epage;                  // For all pages in range
   	   spage += 1 )                     // step on ....
		{
	      D2(bug("\tPageDescriptor %08lx\n",pptr,pindx,pptr[pindx]));
			rc = FALSE;								// On work

      	//********** Search RootTable for custom page, create if needed.
      	//*** New PointerTable will be filled with def PointerTableDesc

      	rptr  = (ULONG*)fptr->mmu_RootTable;		// Get RootTable
      	rindx = spage >> 13 ;                     // Calculate Index

      	if ( rptr[rindx] ==  fptr->mmu_RootTableDesc )	// Default Desc ???
      	{
				if ( mptr = AllocMemAligned( 128*4, 0x1ff ))		// Allocate new PointerTable
				{
      	      rptr[rindx] = (ULONG)(mptr) | 0x3;				// Store new Table
      	      for ( i=0; i<128; i++ )                      // Fill it wit def Desc
						mptr[i] = (ULONG)fptr->mmu_PointerTableDesc;

               fptr = Map_Memory(fptr, (ULONG)mptr, 128*4, 0x60);	// Make it non cacheable
				}
      	}

      	//********* Search Pointer Table for custom PageTable, create if needed
      	//*** New PageTable will be filled with def IndIllPageDesc

  			if ( rptr[rindx] != fptr->mmu_RootTableDesc ) // Is
  			{
  				tptr = (ULONG*)(rptr[rindx] & ~3);	// Get custom ptr page
      	   tindx = (spage >> 6) & 0x7F;			// Get Index to page

      	   if ( tptr[tindx] ==  fptr->mmu_PointerTableDesc )	// Default Desc ???
      	   {
      	     	if ( mptr = AllocMemAligned( 64*4, 0x1ff ))		// Alloc new PageTable
      	     	{
      	         tptr[tindx] = (ULONG)(mptr) | 3;		// Store Valid Ptr to PageTable
	   	         for ( i=0; i<64; i++ )					// Fill with def PageDes
							mptr[i] = (ULONG)fptr->mmu_IndIllPageDesc;

	               fptr = Map_Memory(fptr, (ULONG)mptr, 64*4, 0x60);	// Make it non cacheable
      	     	}
      	   }

				//******** Search or create Custom page descriptor
				//** Memory is translated plain. No VMem !

      	   if ( tptr[tindx] != fptr->mmu_PointerTableDesc )	// Is PageTable inst.
      	   {
      	      pptr = (ULONG*)(tptr[tindx] & ~3);
      	      pindx = spage & 0x3F;							// Lower 6 Bit of page number

					if ( pptr[pindx] ==  fptr->mmu_IndIllPageDesc )
      	      	pptr[pindx] = spage << 12;					// Map Logical -> Physikal Addr :-=)

	 	     		 pptr[pindx] = pptr[pindx] | mode;			// Patch Mode Bits

					if ( (pptr[pindx] & 0x60) == 0x60 )
						pptr[pindx] &= ~0x20;

/*
					if ( ( 0x60 & pptr[pindx] ) > 0x20 )
					{
      	     		 pptr[pindx] = pptr[pindx] | mode;			// Patch Mode Bits
					}
*/
					rc = TRUE;											// So long it's ok.
      	   }
      	   else break;	// No custom page table
  			}
  			else break; // No custom ptr Table
      }
	}
	if ( !rc )										// Everything went ok ????
	{
		FreeMMUFrame(fptr); fptr = NULL;		// Game over
	}
	return fptr;
}
//**--------------------------------------------------------------------------------
//** Map Kickstart
//**--------------------------------------------------------------------------------

struct mc60_mmu *Map_Kickstart(struct mc60_mmu *fptr, ULONG addr)
{
ULONG i, *x;
	D(bug("\tMap Kickstart as cacheable\n"));
	if ( fptr  = Map_Memory( fptr, 0xF80000,  0x80000, 0x00 ))
	{
		if ( addr != 0xf80000 )
		{
        	for( i=0xf80; i<=0xfff; i++ )
        	{
        		x = (ULONG*)fptr->mmu_RootTable;
         	x = (ULONG*)( x[ i >> 13          ] & ~0x1ff );	// Get PointerDesc, Strip Flags
         	x = (ULONG*)( x[( i >> 6 ) & 0x7f ] & ~0x1ff );	// Get PageDesc, Strip Flags

         	x[ i & 0x3f ] = addr | 1;				// Map to New Address, cache/wthrg

            addr += 0x1000;							// Next 4k Page  :-)
         }
		}
	}
	return fptr;
}



//**--------------------------------------------------------------------------------
//** Create DMA NestCOunt Segment or Memory :-) see. mc60_patches ... !!!
//**--------------------------------------------------------------------------------

struct mc60_mmu *CreateNestCount(struct mc60_mmu *fptr, ULONG lower, ULONG upper)
{
ULONG spage, epage;				// Start 1k Memory Page
ULONG size;							// Entries needed
struct mc60_nc *nc;				// Ptr to Segment

	D2(bug("\tAllocate Nestcount\n"));
	if (fptr)
	{
		spage = (lower & ~0xfff) >> 12;			// Get start und end page number
		epage = (upper +  0xfff) >> 12;
		size = (epage - spage)+1;       			// Number of Pages Needed.

      size = sizeof(struct mc60_nc) + size*sizeof(UWORD);		// Allocate Segment

      if ( nc = (struct mc60_nc*)AllocVec( size, MEMF_PUBLIC|MEMF_CLEAR ) )
      {
      	nc->nc_Low = spage;						// Add Segment to List
      	nc->nc_High = epage;
         AddTail( (struct List*)&fptr->mmu_NestCounts, (struct Node*)nc );
      }
	}
   return fptr;
}

//**--------------------------------------------------------------------------------
//** SetupMMUFrame - Build basic MMUFrame
//**--------------------------------------------------------------------------------
//**
//**  Setup a fresh mmu frame and a Default and blank  MMU setup incl. DummyPage

struct mc60_mmu *SetupMMUFrame(void)
{
struct mc60_mmu *fptr;
ULONG i,ready=FALSE;
	D(bug("\tSetupMMUFrame\n"));

	if ( fptr = AllocMem( sizeof(struct mc60_mmu), MEMF_PUBLIC | MEMF_CLEAR ))
	{
   	NewList((struct List*)&fptr->mmu_NestCounts );		// Initialize NestCount List

		//******* Allocate Default MMU Tables.

		D(bug("\t\tAllocate Buffers\n"));
		if (   ( fptr->mmu_RootTable    = AllocMemAligned( 128*4, 0x1ff ) )
	        &&( fptr->mmu_PointerTable = AllocMemAligned( 128*4, 0x1ff ) )
	        &&( fptr->mmu_PageTable    = AllocMemAligned(  64*4, 0x1ff ) )
	        &&( fptr->mmu_IllegalPage  = AllocMemAligned(  4096, 0xfff ) ) )
      {
			D(bug("\t\tSetup Values\n"));
      	//******** Precalculate Descriptors for Default Tables.
      	//** This is the dummy page descriptor - cache inhibited, precise
      	//** It is located and modified inside of MMUFrame. The indirekt
      	//** IllPageDesc points to the desc inside MMUFrame  - nice !

      	fptr->mmu_IllPageDesc      = (ULONG)(fptr->mmu_IllegalPage)  | 0x41;
      	fptr->mmu_IndIllPageDesc   = (ULONG)(&fptr->mmu_IllPageDesc) | 0x02;

			//** These points down to next down level default mmu table

			fptr->mmu_PointerTableDesc = (ULONG)(fptr->mmu_PageTable)    | 0x03;
      	fptr->mmu_RootTableDesc    = (ULONG)(fptr->mmu_PointerTable) | 0x03;

			//** Fill default pages.

         for (i=0;i<64;  i++ )
				((ULONG*)fptr->mmu_PageTable)[i]    = fptr->mmu_IndIllPageDesc;

         for (i=0;i<128; i++ )
				((ULONG*)fptr->mmu_PointerTable)[i] = fptr->mmu_PointerTableDesc;

         for (i=0;i<128; i++ )
				((ULONG*)fptr->mmu_RootTable)[i]    = fptr->mmu_RootTableDesc;

			//** Now create default registers for URP,SRP, TCR

         fptr->mmu_TCR = 0x8008;
         fptr->mmu_URP = fptr->mmu_SRP = fptr->mmu_RootTable;

         //** Special Setup for 060er

         fptr = Map_Memory( fptr, (ULONG)fptr->mmu_RootTable   , 128*4, 0x60 );
         fptr = Map_Memory( fptr, (ULONG)fptr->mmu_PointerTable, 128*4, 0x60 );
         fptr = Map_Memory( fptr, (ULONG)fptr->mmu_PageTable   ,  64*4, 0x60 );

         fptr = Map_Memory( fptr, (ULONG)fptr->mmu_IllegalPage ,  4096, 0x40 );
         ready = TRUE;
      }
      if (!ready) FreeMMUFrame(fptr);
   }
	return fptr;
}


//**--------------------------------------------------------------------------------
//** This code builds the MMU Tables for your MC060
//**--------------------------------------------------------------------------------
//**
//**

#define SysBase (*(struct ExecBase**)4)

struct mc60_mmu *BuildMMUTables(void)
{
struct mc60_mmu *fptr;       	// Ptr to MMUFrame, it's our tag ptr

	//***************************************************************
	// First create standard mmu table
	// Table Memory will be marked non cacheable.

	D(bug("\nSetup MMU Frame Structure:\n"));
   fptr = SetupMMUFrame();

	//***************************************************************
	// Map standard ranges to noncachable/precise ?

   fptr  = Map_Memory( fptr, 0xBC0000,  0x40000, 0x40 );
   fptr  = Map_Memory( fptr, 0xD80000,  0x80000, 0x40 );
   fptr  = Map_Memory( fptr, 0xF00000,  0x80000, 0x00 );

	//***************************************************************
	// Map Kickstart or shadow as cacheable

   fptr = Map_Kickstart(fptr,0xf80000);

	//***************************************************************
	// Hmm now care abot 'special' Amiga, CD32, A1200 PCMCIA ....

	if ( OpenResource("card.resource") )
	   fptr  = Map_Memory( fptr, 0x600000, 0x440002, 0x40 );

	if ( FindResident("cdstrap") )
	   fptr  = Map_Memory( fptr, 0xE00000, 0x080000, 0x40 );

	//***************************************************************
	// Is ExecBase located in $200000 Ram. Yep ? It is a developer
	// kick ..... make it cacheable

	if ( (UBYTE)((ULONG)(SysBase->LibNode.lib_Node.ln_Name)>>16) == 0x20 )
	   fptr  = Map_Memory( fptr, 0x200000, 0x80000, 0x00 );

	//***************************************************************
	// Make low memory page non cache cachable

   fptr  = Map_Memory( fptr, 0x0000, 0x1000, 0x40 );

	//***************************************************************
   //** Now map PUBLIC Memory Lists as cacheable.
   //** All other entries are non cachable
   //** This code is single threaded as we don't want to be disturbed
	{
	struct MemHeader *memhdr;        // Ptr to MemHdr

	   Forbid();
	   for ( memhdr = (struct MemHeader*)SysBase->MemList.lh_Head;
	         memhdr->mh_Node.ln_Succ != 0;
				memhdr = (struct MemHeader*)memhdr->mh_Node.ln_Succ	)
	   {
	   ULONG pagemode;

   		pagemode =(TypeOfMem( memhdr->mh_Lower ) & MEMF_CHIP )? 0x40:0x20;

	   	fptr  = Map_Memory( fptr, (ULONG)memhdr->mh_Lower,
															 (ULONG)memhdr->mh_Upper -
            	                               (ULONG)memhdr->mh_Lower,
															pagemode );
			if ( pagemode == 0x40 )
   	      fptr = CreateNestCount(fptr,(ULONG)memhdr->mh_Lower,(ULONG)memhdr->mh_Upper);
   	}
   	Permit();
	}
   //*********************************************************************
	//** Check for AutoConfig Memory Boards and map mem as cachable.
	//**
	{
	struct Library *ExpansionBase;

		if ( ExpansionBase = OpenLibrary( "expansion.library",0 ) )
		{
   	struct ConfigDev *cd = NULL;

	      while ( cd = FindConfigDev( cd, -1, -1 ) )
   	   {
      		if ( cd && !(cd->cd_Rom.er_Type & ERTF_MEMLIST ))
				   fptr  = Map_Memory( fptr,
													(ULONG)cd->cd_BoardAddr,
													cd->cd_BoardSize, 0x40 );
	      }
			CloseLibrary(ExpansionBase);
		}
   }
	//***********************************************************************

	D(bug("End of MMU Setup.\n"));
   return fptr;
}

/*

void main(void)
{
struct mc60_mmu *fp;
   fp = BuildMMUTables();
	FreeMMUFrame(fp);
}

*/
