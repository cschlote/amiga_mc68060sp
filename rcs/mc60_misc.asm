

**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department         Telefax             06404-64760
**  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
**    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
** \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_mmu.asm 1.3 1997/04/14 22:47:28 schlote Exp schlote $
**

	machine	68060
	near

	include	"mc60_system.i"
	include	"mc60_libbase.i"

	section          mmu_code,code
MYDEBUG	SET              0
DEBUG_DETAIL 	set 	10


**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
** following code ripped from 68040.library
**
**
** Load CPU Ctrl Regs with MMU Parameters.

TTDISABLE	MACRO	
	movec.l          \1,\2
	bclr.l	#15,\2
	movec.l	\2,\1
	ENDM

	XREF	_MMUFrame
	XDEF	_SetMMUTables

_SetMMUTables:
	MOVEM.L          d0-d7/a0-a6,-(sp)
	MOVE.L	(_MMUFrame,pc),a0
	DBUG	10,'\t\tURP: %08lx,SRP: %08lx,TCR: %08lx\n',(a0),4(a0),8(a0)

	ORI.W	#$0700,SR	; Stop IRqs
	PFLUSHA                                 ;
	CPUSHA           BC
	MOVE.L	(A0)+,D0
	MOVEC	D0,URP	;SetUserRootPtr
	NOP
	MOVE.L	(A0)+,D0
	MOVEC	D0,SRP	;Set RootPtr
                        NOP
	MOVE.L	(A0)+,D0	;set Translation Ctrl Reg - go !
	MOVEC	D0,TC
                        NOP
 	PFLUSHA		;MC68040

	TTDISABLE	ITT0,d0                ;Disable all transparent translation
	TTDISABLE	ITT1,d1
	TTDISABLE	DTT0,d2
	TTDISABLE	DTT1,d3
	DBUG	10,'\t\tITT0: %08lx,ITT1: %08lx,DTT0: %08lx, DTT0: %08lx\n',d0,d1,d2,d3

	MOVEM.L          (sp)+,d0-d7/a0-a6
	RTE



**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
** following code ripped from 68040.library

	XDEF	_CheckMMU
_CheckMMU:
	MOVEM.L          d0-d7/a0-a6,-(sp)

	DBUG	10,'\t\tInstall Data Translation : '

	MOVEC	DTT1,D1	;transparent data set to nocache, precise
	AND.B	#$9F,D1
	OR.B	#$40,D1
	DBUG	10," DTT1=$%08lx",d1
	MOVEC	D1,DTT1

	MOVEQ	#0,D0	;rc = FALSE
	ORI.W	#$0700,SR	;stop any irq

	MOVEC	TC,D1	;mmu paging on ?
	TST.W	D1
	DBUG	10," TCR=%$%08lx\n",d1
	BMI.B	.is_set

	BSET	#15,D1	;set mmu paging
	MOVEC	D1,TC
	MOVEC	TC,D1	;set & readback
	MOVEC	D0,TC	;no mmu paging!
	TST.W	D1	;was paging set ?
	BPL.B	.no_MMU

.is_set:	AND.W	#$F000,D1
	MOVE.L	D1,D0

.no_MMU:
	MOVEM.L          (sp)+,d0-d7/a0-a6
	RTE

	end


