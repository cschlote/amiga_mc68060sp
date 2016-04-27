head	1.8;
access;
symbols;
locks
	schlote:1.8; strict;
comment	@ * @;


1.8
date	97.04.15.19.20.11;	author schlote;	state Exp;
branches;
next	1.7;

1.7
date	97.04.14.23.06.35;	author schlote;	state Exp;
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
date	96.11.26.22.11.10;	author schlote;	state Exp;
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


1.8
log
@Source clean up. All possible code moved to C language :-)
@
text
@
/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department         Telefax             06404-64760
**  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
**    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
** \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_init.c 1.7 1997/04/14 23:06:35 schlote Exp schlote $
**
*/

//#define __USE_SYSBASE

#include	<clib/alib_protos.h>

#include	<proto/exec.h>
#include <exec/exec.h>
#include <exec/execbase.h>
#include <exec/ports.h>

#include <dos.h>

//**------------------------------------------------------------------------------------------------

#include "mc60_rev.h"
#include	"mc60_Debug.h"
#include	"mc60_LibBase.h"

//**------------------------------------------------------------------------------------------------

#define REG(x) register __ ## x


//**----------------------------------------------------------------------------
//** This code is directly taken from M.Sinz and left as is, with some
//** Patches. MMUFrame is set with valid MMUFrame or NOT !

extern 	void	__asm 		PatchExec(REG(a6) struct ExecBase*SysBase);
extern   struct mc60_mmu 	*MMUFrame;

extern void __asm 			FPU_Dispatcher(void);			// New Dispatcher
extern void __asm 			FPU_LaunchPoint(void);			// New Launchcode

//**----------------------------------------------------------------------------
//** This are the enry points for the Amiga ISP/FPSP

extern 	void	__asm 		Install_AmigaISP(void);
extern 	void	__asm 		Install_AmigaFPSP(void);

//**----------------------------------------------------------------------------
//** This is some misc routines for PCR/VBR crap. Supervisor Code

extern	void  __asm			GetVBR(void);
extern	void  __asm			SetVBR(void);
extern	BOOL  __asm 		CheckMMU(void);			// Check MMU and set DTTR1 for all data no caache
extern	void  __asm  		SetMMUTables(void);		// Load URP/SRP(TCR with _valid_ MMUFrame
extern 	void	__asm 		EnableCaches(void);

//**----------------------------------------------------------------------------
//** This routine will return a _valid_ MMUFrame or NULL

extern 	struct mc60_mmu* 	BuildMMUTables(void);


//**-----------------------------------------------------------------------------
//**-----------------------------------------------------------------------------

static 
void MoveVBR(void)
{
APTR vbr;
	vbr = (APTR)Supervisor( (APTR)GetVBR );
	if (vbr==NULL)
	{
		if ( vbr = AllocMem( 256*4, MEMF_PUBLIC ) )
		{
			CopyMem( (APTR)NULL, vbr, 256*4 );
			CacheClearU();
			putreg(REG_D0,(LONG)vbr),Supervisor( (APTR)SetVBR );
		}
	}
}

//**-----------------------------------------------------------------------------
//**-----------------------------------------------------------------------------

#define LVOexecPrivate4 (ULONG)(-54)									// Dispatcher Entry to Exec

static
void ConvertStack(struct Task*task)
{
ULONG *stack;
	D(bug("Patch Stack : %s\n",task->tc_Node.ln_Name ));
	stack = task->tc_SPReg;
	*(--stack) = NULL;
	*(--stack) = NULL;
	*(--stack) = NULL;
	task->tc_SPReg = stack;
}
void SetDispatcher(struct ExecBase*SysBase)
{
struct Task*task;

	if ( !(SysBase->AttnFlags & AFF_PRIVATE) )
	{
		Disable();
      CacheClearU();															// Be sure....
		SysBase->AttnFlags |= (AFF_68060|AFF_FPU40);					//	Set AttnFlags
		SysBase->AttnFlags |= AFF_PRIVATE;
      D(bug("Attn: %04lx\n",SysBase->AttnFlags));

		SetFunction(SysBase,LVOexecPrivate4,(APTR)FPU_Dispatcher);		// Install FPU Dispatcher
      SysBase->ex_LaunchPoint = (ULONG)&FPU_LaunchPoint;				// Setup Launchcode

      for ( task = (struct Task*)SysBase->TaskReady.lh_Head;
            task->tc_Node.ln_Succ; task = (struct Task*)task->tc_Node.ln_Succ
			 ) ConvertStack(task);

      for ( task = (struct Task*)SysBase->TaskWait.lh_Head;
            task->tc_Node.ln_Succ; task = (struct Task*)task->tc_Node.ln_Succ
			 ) ConvertStack(task);


      CacheClearU();															// Be sure....
      Enable();
	}
}

//**-----------------------------------------------------------------------------

struct mc60_Lib*  __asm LibInit(	REG(d0) struct mc60_Lib *base,
					                  REG(a0) BPTR seglist,
					                  REG(a6) struct ExecBase*SysBase)
{
	D(bug("\n\n\nMC68060 Support Library (Version%ld.%ld)\n"
			"\tLibInit(Base:%08lx,SegList:%08lx,SysBase:%08lx)\n"
			"\t\tAttnFlags = %04lx\n"
			"\t\tChecking Kickstart version :",
			VERSION,REVISION,base,seglist,SysBase,SysBase->AttnFlags));

   if (	!(  ( SysBase->LibNode.lib_Version >= 37 ) &&				// right Kicklevel ?
   		  	 ( SysBase->AttnFlags & AFF_68040     )	 )   )		// right CPU ???
	{
		D(bug("Kickstart Version < 37 - upgrade your Kickstart\n"));
		Alert(AN_Unknown|AG_OpenLib|AO_ExecLib);							// Alert User
		FreeMem(  (VOID*)((int)base-base->Lib.lib_NegSize),			// Free Library Data immediatly and rc=NULL
					base->Lib.lib_NegSize+base->Lib.lib_PosSize);
      base = NULL;
   }
   else //**----------------------------------------------------------------------
	{
   ULONG cachebits;															// Remember CacheState
		D(bug("Kickstart Version >=37 - setup MC68060\n\n",base));

		base->SegList		= seglist;								// store seglist
		base->SysBase 		= SysBase;								// for fast access
		base->MMUFrame 	= &MMUFrame;							// for fun

		D(bug("\tGo forbid(), Disable/Flush Caches...\n"));

		Forbid(); cachebits = CacheControl(0,-1);				// Stall and disable caches.

		//**----------------------------------------------
		//** Install CPU 68060 Patches from Motorola

		DQ(bug("\tInstalling ISP & FPSP Code to Base & VBR\n"));
		Install_AmigaISP();											// Install Amiga ISP
		Install_AmigaFPSP();
		SysBase->AttnFlags |= (AFF_68882|AFF_68881); 		//	Set AttnFlags

		//**----------------------------------------------
		//** Do Exec Patches.

		DQ(bug("\tPatching exec.library : \n"));
		MMUFrame = NULL;												// No MMU yet.
		PatchExec(SysBase);                     				// patches from 68040.library

		DQ(bug("\tMoving VBR:\n"));
		MoveVBR();

		DQ(bug("\tSetup new dispatcher\n"));
		SetDispatcher(SysBase);									// Install the new dispatcher


		//**----------------------------------------------
		//** Setup MMU Tables if possible

		DQ(bug("\tInstalling MMU support\n"));


		if ( Supervisor( (void*)CheckMMU ) )			// Check for existent MMU
		{
			 MMUFrame = BuildMMUTables(); 	// Store at local code for exec patches !!!!
		}
      DQ(bug("\tMMUStruct=$%08lx\n",MMUFrame));	// Was nu

		if ( MMUFrame ) 	Supervisor( (void*)SetMMUTables );

		//**----------------------------------------------

		DQ(bug("\tInstall 060 caches.\n"));
		Supervisor( (void*)EnableCaches);

		//**----------------------------------------------

		CacheControl(cachebits,-1);
		Permit();

   }
   D(bug("SYSTEM SET UP.  RC=%08lx\n",base));
	return base;
}



@


1.7
log
@Working Version 40.2, 40.10ß2
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.6 1997/04/14 23:00:04 schlote Exp schlote $
d23 2
a34 1
extern   APTR	MMUFrame;
d36 12
a47 2
extern 	void	__asm PatchExec(REG(a6) struct ExecBase*SysBase);
extern 	void	__asm PatchDispatcher(REG(a6) struct ExecBase*SysBase);
d49 2
a50 2
extern 	void	__asm Install_AmigaISP(void);
extern 	void	__asm Install_AmigaFPSP(void);
d52 11
a62 1
extern	BOOL  __asm CheckMMU(void);
a64 1
extern	void __asm  		SetMMUTables(REG(a0)struct mc60_mmu*);
a65 1
extern 	void	__asm EnableCaches(void);
d67 23
d91 39
d163 1
a163 1
		Forbid(); cachebits = CacheControl(0,-1);			// Stall and disable caches.
d166 1
a166 1
		//** Do Exec Patches.
d168 4
a171 3
		DQ(bug("\tPatching exec.library : \n"));        // patches from 68040.library
		MMUFrame = 0;
		PatchExec(SysBase);
d174 1
a174 1
		//** Install CPU 68060 Patches from Motorola
d176 3
a178 1
		DQ(bug("\tInstalling MC68060 ISP & FPSP Code to Base & VBR\n"));
d180 2
a181 3
		Install_AmigaISP();
		Install_AmigaFPSP();
		SysBase->AttnFlags |= (AFF_68882|AFF_68881); 	//	Set AttnFlags
d184 2
a185 2
		SysBase->AttnFlags |= (AFF_68060|AFF_FPU40);		//	Set AttnFlags
		PatchDispatcher(SysBase);							// Install the new dispatcher
d193 1
a193 1
		if ( Supervisor( (void*)CheckMMU ) )
@


1.6
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.5 1997/04/14 22:47:28 schlote Exp schlote $
@


1.5
log
@Working version
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.4 1997/04/12 13:39:03 schlote Exp schlote $
@


1.4
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.3 1996/11/27 00:10:35 schlote Exp schlote $
d35 2
a36 2
extern 	void	__asm Install_Exec_Patches(REG(a6) struct ExecBase*SysBase);
extern 	void	__asm Install_Dispatcher(REG(a6) struct ExecBase*SysBase);
d43 2
a44 1
extern 	struct mc60_mmu* BuildMMUTables(void);
d46 1
a46 3
extern	void __asm SetMMUTables(REG(a0)struct mc60_mmu*);

extern 	void	__asm Install_Caches(REG(a6) struct ExecBase*SysBase);
d89 1
a89 1
		Install_Exec_Patches(SysBase);
d102 1
a102 1
		Install_Dispatcher(SysBase);							// Install the new dispatcher
d116 1
a116 4
		if ( MMUFrame )
			Supervisor( (void*)SetMMUTables );
			
		MMUFrame = NULL;
d121 1
a121 1
		Install_Caches(SysBase);
@


1.3
log
@Reviewed & commented lib startup. Fixed minor bugs
Added SegList Ptr Save
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.2 1996/11/26 22:11:10 schlote Exp schlote $
d14 1
a14 1
#define __USE_SYSBASE
d33 1
a33 3
extern 	void	__asm Install_Exec_Patches(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
extern 	void	__asm Install_Dispatcher(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
extern 	void	__asm Install_Caches(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
d35 2
a36 3
extern 	void	__asm Install_Mem_Library(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
extern 	void	__asm Install_Int_Emulation(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
extern 	void	__asm Install_FPU_Emulation(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
d38 2
a39 1
extern 	void	__asm Install_Link_Libraries(REG(a5) struct MC60LibBase*base,REG(a6) struct ExecBase*SysBase);
d41 1
a41 3
extern	BOOL _CheckMMU(void);
extern	VOID _Set060MMUTables(void);
extern 	APTR __asm _BuildMMUTables(REG(a6) struct MC60LibBase*base);
d43 1
a43 1
extern   APTR	_060MMUFrame;
d45 1
a45 1
//**------------------------------------------------------------------------------------------------
d47 1
a47 6
struct MC60LibBase*
__asm LibInit(	REG(d0) struct MC60LibBase *base,
					REG(a0) BPTR seglist,
					REG(a6) struct ExecBase*SysBase)
{
	D(bug("MC68060 Support Library LibInit (Version%ld.%ld)\n",VERSION,REVISION));
a48 1
	D(bug("... AttnFlags = %04lx\n",SysBase->AttnFlags));
a49 4
   if (!(  ( SysBase->LibNode.lib_Version >= 37 ) &&			// right Kicklevel ?
   		  ( SysBase->AttnFlags & AFF_68040 )		))			// right CPU ???
		{
			D(bug("... found Kickstart below V37 - upgrade your Kickstart\n"));
d51 1
a51 7
			FreeMem(  (VOID*)((int)base-base->Lib.lib_NegSize),			// Free Library Data immediatly .. no expunge hook
						base->Lib.lib_NegSize+base->Lib.lib_PosSize);
         base = NULL;
      }
      else //**------------------------------------------------------------------------------------
      {
      ULONG cachebits;							// Remember CacheState
d53 9
a61 1
			D(bug("... found right Kickstart Version >=37 - LibBase $%08lx.\n",base));
d63 13
a75 1
			//**----------------------------------------------
d77 3
a79 1
         D(bug("Do phase5 compatible library values....\n"));
d81 1
a81 4
			base->LibBase 		= base;									// non sense - to access it you must have it already
			base->SegList		= seglist;								// store seglist
			base->SysBase 		= SysBase;								// for fast access
			base->MMUFrame 	= (APTR)&_BuildMMUTables;			// for product check
d83 1
a83 4
			base->PatchPort.mp_Node.ln_Type = NT_MSGPORT;			// Set Type
			base->PatchPort.mp_Node.ln_Pri  = -128;					// Set Pri
			base->PatchPort.mp_Node.ln_Name = "68060_PatchPort";	// Set Type
			base->PatchPort.mp_Flags = PA_IGNORE;						// SetupPort
d85 2
a86 2
			NewList(&base->PatchPort.mp_MsgList);
			if ( FindPort("68060_PatchPort")==NULL ) AddPort(&base->PatchPort);
d88 3
a90 2
			Install_Link_Libraries(base,SysBase);					//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			Install_Mem_Library(base,SysBase);
d92 2
a93 1
			//**----------------------------------------------
d95 1
a95 1
			D(bug("Go forbid(), Disable/Flush Caches...\n"));
d97 3
a99 2
 			Forbid();
 			cachebits = CacheControl(0,-1);												// Stall and disable caches.
d101 3
a103 1
			//**----------------------------------------------
d105 2
a106 2
			DQ(bug("Patching exec.library\n"));                      			// patches from 68040.library
			Install_Exec_Patches(base,SysBase);
d108 1
a108 2
			SysBase->AttnFlags |= (AFF_68040|AFF_68030|AFF_68020|AFF_68010); 	//	Set AttnFlags
			DQ(bug("... AttnFlags = %04lx\n",SysBase->AttnFlags));
a109 1
			//**----------------------------------------------
d111 5
d117 4
a120 2
			DQ(bug("Install Emu ISP Code to Base & VBR\n"));							// Install Integer Patches from Motorola
			Install_Int_Emulation(base,SysBase);
d122 1
a122 2
			DQ(bug("Install Emu FPSP Code to Base & VBR\n"));      				// FPUPatches Integer Patches from Motorola
			Install_FPU_Emulation(base,SysBase);
d124 2
d127 1
a127 2
			SysBase->AttnFlags |= (AFF_FPU40|AFF_68882|AFF_68881); 				//	Set AttnFlags
			DQ(bug("... AttnFlags = %04lx\n",SysBase->AttnFlags));
d129 2
a130 1
			//**----------------------------------------------
d132 4
a135 8
			DQ(bug("Install dispatcher\n"));
			Install_Dispatcher(base,SysBase);											// Install the new dispatcher
			DQ(bug("... AttnFlags = %04lx\n",SysBase->AttnFlags));

			SysBase->AttnFlags |= (AFF_68060); 											//	Set AttnFlags
			DQ(bug("... AttnFlags = %04lx\n",SysBase->AttnFlags));

			//**----------------------------------------------
a136 12
			DQ(bug("Installing MMU support, check, "));
			if ( Supervisor( (void*)_CheckMMU ) )
			{
//*
            DQ(bug("building tables, "));
				if ( _060MMUFrame = _BuildMMUTables(base) )							// Store at local code for exec patches !!!!
				{
					DQ(bug("setup tables at $%08lx\n",_060MMUFrame));
					Supervisor( (void*)_Set060MMUTables );
            }
//*/
			}
a137 17
			//**----------------------------------------------

			DQ(bug("Install 060 caches.\n"));
			Install_Caches(base,SysBase);


			//**----------------------------------------------

			CacheControl(cachebits,-1);
			Permit();

      }

   D(bug("Returning to System. RC=%08lx\n",base));

	return base;
}
@


1.2
log
@Changed name of REVISION Header
Now set to "mc60_rev.(i|h)"
@
text
@d10 1
a10 1
** $Id: mc60_init.c 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d52 3
a54 1
__asm LibInit(REG(d0) struct MC60LibBase *base,REG(a6) struct ExecBase*SysBase)
d80 1
d88 1
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d25 1
a25 1
#include "68060_rev.h"
@
