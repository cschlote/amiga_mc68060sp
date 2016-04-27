head	1.9;
access;
symbols;
locks
	schlote:1.9; strict;
comment	@;; @;


1.9
date	97.04.15.19.20.11;	author schlote;	state Exp;
branches;
next	1.8;

1.8
date	97.04.15.16.48.42;	author schlote;	state Exp;
branches;
next	1.7;

1.7
date	97.04.15.14.51.36;	author schlote;	state Exp;
branches;
next	1.6;

1.6
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.5;

1.5
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.14.22.47.28;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	97.04.12.13.39.03;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.04.10.22.04.43;	author schlote;	state Exp;
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


1.9
log
@Source clean up. All possible code moved to C language :-)
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
** $Id: mc60_dispatcher.asm 1.8 1997/04/15 16:48:42 schlote Exp schlote $
**
**
	machine	68060
	near             code
	opt	1

	include	"mc60_system.i"
	include	"mc60_libbase.i"

MYDEBUG	SET              0
DEBUG_DETAIL 	set 	10

**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
* New Switch Code for Task Scheduling. Is Supervisor Code. Save Context to USP
* Entered at execPrivate4()     ;ExecPrivate4 (Dispatcher) := $f81402
*  With FPU  execprivate4_FPU() ;                          := $f815a8
*
* This is the standard code taken from V39 Exec. Modified for new Stackframe
* formats of 060FPU. Things became simpler :-)
*
* Code is partly optimized compared with Exec StdCode.

	XDEF	_FPU_Dispatcher
_FPU_Dispatcher:
	MOVE.W	#$2000,SR	; Set Supervisor State
	MOVE.L	A5,-(SP)               ; Save a5 to SSP !!!!!
	MOVE.L	USP,A5	; Get USP to a5

	MOVEM.L	D0-D7/A0-A6,-(A5)	; Save all regs to USP = 60
			; 15*8 = 60 Bytes
	MOVEA.L	(4).W,A6	; Get SysBase
	MOVE.W	(IDNestCnt,A6),D0	; get nest irq & diable next cnt
	MOVE.W	#$FFFF,(IDNestCnt,A6) 	; lock both cnts to max.
	MOVE.W	#$C000,(_custom+intena).L

	MOVE.L	(SP)+,(52,A5)	; (8*4)+(5*4)=32+20=52  correct A5 on USP
	MOVE.W	(SP)+,-(A5)	;  SR to USP 62
	MOVE.L	(SP)+,-(A5)            ;  PC to USP 64

	LEA	(2,SP),SP              * Ignore this field
*                       MOVE.W           (SP)+,d1               ; OBSOLETE exception frame

	FSAVE	-(A5)	; Save Stackframe

	TST.B	(2,A5)	* Test for 060 Nullframe
	BEQ.B	.SWITCH_FPU_NullFrame

	MOVEQ	#-1,D2                	; On 060 This is the only state IDEL

*	MOVE.W	d2,-(a5)	* Caution Stackframe changed !
*	AND.W	#$F000,D1              * As we check 2(a5), we must
*	CMP.W	#$9000,D1              * save a long word. otherwise
*	BNE.B	lbC0015F2              * we break the checks.
*	MOVE.L	(SP)+,-(A5)            * As D1 is OBSOLETE we can use
*	MOVE.L	(SP)+,-(A5)	* it's space
*	MOVE.L	(SP)+,-(A5)
*	MOVE.W	D1,D2

	FMOVEM.X	FP0/FP1/FP2/FP3/FP4/FP5/FP6/FP7,-(A5)  ; Save Registers
	FMOVE.L	FPIAR/FPSR/FPCR,-(A5)

	MOVE.L	D2,-(A5)               * SAVE DUMMY FIELD -1
*	MOVE.W	D2,-(A5)               ; OBSOLETE

********************************************************************
** The following code is common to Std & FPU Dispatcher
********************************************************************

.SWITCH_FPU_NullFrame:
	MOVEA.L	(ex_LaunchPoint,A6),A4		; a4 = LaunchCOde

	MOVEA.L	(ThisTask,A6),A3
	MOVE.W	D0,(TC_IDNESTCNT,A3)		; Save nest count to task context
	MOVE.L	A5,(TC_SPREG,A3)		; Remember Task StackPtr

	BTST	#TB_SWITCH,(TC_FLAGS,A3)	; Set Custom Switch Code
	BEQ.B	.getNextTask
	MOVEA.L	(TC_SWITCH,A3),A5	; private switchcode
	JSR	(A5)

*lbC001450:	MOVEA.L	(ex_LaunchPoint,A6),A4  	;
*	MOVE.W	#$FFFF,(IDNestCnt,A6)          ; OBSOLETE
*	MOVE.W	#$C000,(_custom+intena).L      ;

.getNextTask:	LEA	(TaskReady,A6),A0		; get a ready Task
.taskloop:	MOVE.W	#$2700,SR      		; Travese ready list
	MOVEA.L	(LN_SUCC,A0),A3                ; wait until AddTail() added task
	MOVE.L	(LN_SUCC,A3),D0
	BNE.B	.taskendloop
	ADDQ.L	#1,(IdleCount,A6)
	BSET	#7,(SysFlags,A6)		; System in IDEL state
	STOP	#$2000		; Stop until next Irq
	BRA.B	.taskloop

.taskendloop:	MOVE.L	D0,(LN_SUCC,A0)                ; feed last task to end of ready queue
	MOVEA.L	D0,A1
	MOVE.L	A0,(LN_PRED,A1)

	MOVE.L	A3,(ThisTask,A6)		; Save to Aktual Task

	MOVE.W	(Quantum,A6),(Elapsed,A6)

	BCLR	#6,(SysFlags,A6)		; System state ??

	MOVE.B	#TS_RUN,(TC_STATE,A3)		; Set Taskstate

	MOVE.W	(TC_IDNESTCNT,A3),(IDNestCnt,A6) ; Restore Net Counts
	TST.B	(IDNestCnt,A6)                 ; restore IRQ state
	BMI.B	.idnest3
	MOVE.W	#$4000,(_custom+intena).L
.idnest3:	MOVE.W	#$2000,SR		; Set Superstate
	ADDQ.L	#1,(DispCount,A6)		; Inc DispCount

	MOVE.B	(TC_FLAGS,A3),D0
	ANDI.B	#(TF_EXCEPT|TF_LAUNCH),D0	; Launch this task ???
	BEQ.B	.conttask
	BSR.B	.launchnewtask		; launch new code

.conttask:	MOVEA.L	(TC_SPREG,A3),A5		; Get Task StackPtr
	JMP	(A4)                           ; ex_LaunchPoint code


	**----- Some obsolete Code deleted here


.launchnewtask:	BTST	#TB_LAUNCH,D0			; Launch new task ???
	BEQ.B	.nolaunch

	MOVE.B	D0,D2
	MOVEA.L	(TC_LAUNCH,A3),A5		; Launch new task
	JSR	(A5)
	MOVE.B	D2,D0

.nolaunch:	BTST	#TB_EXCEPT,D0                   	; do Exception state code
	BNE.B	.Exception
.endexception:	RTS                                              	; otherwise goon

.Exception:	BCLR	#TB_EXCEPT,(TC_FLAGS,A3)
	MOVE.L	(TC_EXCEPTCODE,A3),D1			; d1=ExeceptionCode
	BEQ.B	.endexception

	MOVE.W	#$4000,(_custom+intena).L		; DISABLE
	ADDQ.B	#1,(IDNestCnt,A6)

	MOVE.L	(TC_SIGRECVD,A3),D0 		; Get mask of exceptions
	AND.L	(TC_SIGEXCEPT,A3),D0
	EOR.L	D0,(TC_SIGEXCEPT,A3)		; reset flags set.
	EOR.L	D0,(TC_SIGRECVD,A3)

	SUBQ.B	#1,(IDNestCnt,A6)		; ENABLE
	BGE.B	.idnest
	MOVE.W	#$C000,(_custom+intena).L
.idnest:
	MOVEA.L	(TC_SPREG,A3),A1
	MOVE.L	(TC_FLAGS,A3),-(A1)

	TST.B	(IDNestCnt,A6)
	BNE.B	.idcont2

	SUBQ.B	#1,(IDNestCnt,A6)		; ENABLE
	BGE.B	.idcont2
	MOVE.W	#$C000,(_custom+intena).L
.idcont2:
	MOVE.L	#go_supervisor,-(A1)		; go supervisor
	MOVE.L	A1,USP

	BTST	#AFB_68010,(AttnFlags+1,A6)	;
	BEQ.B	.nofpuused
	MOVE.W	#$0020,-(SP)
.nofpuused:	MOVE.L	D1,-(SP)
	CLR.W	-(SP)
	MOVEA.L	(TC_EXCEPTDATA,A3),A1
	RTE

*------------------------------------------------------------------------------------------------

go_supervisor:	MOVEA.L	(4).W,A6	; Reenter SuperState after Execept Code
	LEA	(.supercode,PC),A5
	JMP	(_LVOSupervisor,A6)

.supercode:	MOVEA.L	(ex_LaunchPoint,A6),A4		; Get start of Launchcode
	BTST	#AFB_68010,(AttnFlags+1,A6)	; Care about FPU ???
	BEQ.B	.nofpuused

	ADDQ.L	#2,SP
.nofpuused:	ADDQ.L	#6,SP
	MOVEA.L	(ThisTask,A6),A3		; Set new Execept Bit if wanted
	OR.L	D0,(TC_SIGEXCEPT,A3)

	MOVE.L	USP,A1
	MOVE.L	(A1)+,(TC_FLAGS,A3)
	MOVE.L	A1,(TC_SPREG,A3)

	MOVE.W	(TC_IDNESTCNT,A3),(IDNestCnt,A6)
	TST.B	(IDNestCnt,A6)
	BMI.B	.end
	MOVE.W	#$4000,(_custom+intena).L
.end:	RTS

*-------------------------------------------------------------------------------
*-------------------------------------------------------------------------------
**
** This is the old ex_LaunchPoint Code with additions to load the extra
** Registers from the TaskStack, and then LaunchTask
** Information taken from Kickstart V39 Exec $F81600

** Some Code is removed because FPU Stackframes changed complettly, therefore
** many things simplefied. 060 FPU Frames are equal length :-)

	XDEF	_FPU_LaunchPoint
_FPU_LaunchPoint:
	MOVEQ	#$20,D1	; CPU Vector/Offset to save

	*** Each new Task has an NULL Frame at Stack at Buttom.
	***  So it should be zero.

	TST.B	(2,A5) 	; Test Frame Format NULL ?
	BEQ.B	.isNullFrame           ; yep. don't touch FPU

	*** CPU was used, and therefore a -1 longword is stored.
	*** Before only -1.w was stored as marker.
	*** The original source uses -1.w,regs,<frameformat>
	*** Changed ! Now  -1.L,regs,$0020 is used for 060.

	ADDQ.L	#4,A5                  ; SKIP DUMMY FIELD
*	ADDQ.L	#2,A5                  ; OBSOLETE -1.w Flag

	FMOVE.L	(A5)+,FPIAR/FPSR/FPCR
	FMOVEM.X	(A5)+,FP0/FP1/FP2/FP3/FP4/FP5/FP6/FP7  ; load FPU regs

*	CMP.B	#$90,D0	; OBSOLETE
*	BNE.B	lbC001620
*	MOVE.L	(A5)+,-(SP)
*	MOVE.L	(A5)+,-(SP)
*	MOVE.L	(A5)+,-(SP)
*	MOVE.W	#$9020,D1
*lbC001620:
*	ADDQ.L	#2,A5

.isNullFrame:
	FRESTORE	(A5)+	; rebuild fpu state
	LEA	(66,A5),A2	; Goto Top of TaskFrame
	MOVE.L	A2,USP                 ; Set old USP
	MOVE.W	D1,-(SP)               ; CPU Frame $0020
	MOVE.L	(A5)+,-(SP)	; PC
	MOVE.W	(A5)+,-(SP)            ; SR Task
	MOVEM.L	(A5),D0-D7/A0-A6       ; load regs
	RTE


	end
@


1.8
log
@Back checked. More commented and working.
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.6 1997/04/14 23:06:35 schlote Exp schlote $
d16 1
a16 1
	opt	0
d21 1
a21 1
MYDEBUG	SET              1
a23 85
*_LVOexecPrivate4:	EQU	-$00000036

**-------------------------------------------------------------------------------

	section          dispatcher,code
*> a6 = SysBase

	XDEF	_PatchDispatcher
_PatchDispatcher:
	MOVEM.L	D0-D7/A0-A6,-(SP)		; Stirtcly diabled....
	MOVE.l	4.w,a6
	JSR	(_LVODisable,A6)

	MOVE.W	(AttnFlags,A6),D0
	ANDI.W	#(AFF_68881|AFF_68882|AFF_FPU40),D0
	BEQ.W	.quit

	BSET	#(AFB_PRIVATE//8),(AttnFlags,A6)    ; Set AttnFlag & quit if set bevor
	BNE.W	.quit

	DBUG	10,"Brainless patch,"

	LEA	(go_supervisor,PC),A0		; Patch code . argl..
	LEA	(patchcode,PC),A1
	MOVE.L	A0,(A1)
	JSR	(_LVOCacheClearU,A6)		; dump caches to mem

	DBUG	10,", New SwitchCode"

	LEA	(FPU_Dispatcher,PC),A0		; Set new taskswitch code
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.W	#_LVOexecPrivate4,A0
	JSR	(_LVOSetFunction,A6)

	DBUG	10," (old:%08lx:), New ex_LaunchPoint Code",d0

	LEA	(NewLaunchPoint,PC),A0	; Set new LaunchPoint
                        DBUG             10," (old:%08lx:)",(ex_LaunchPoint,A6)
	MOVE.L	A0,(ex_LaunchPoint,A6)

	LEA	(GetVBR,PC),A5		; Get VBR
	JSR	(_LVOSupervisor,A6)
	MOVEA.L	D0,A2
	TST.L	D0
	BNE.B	.vbrmoved

	MOVE.L	#256*4,D0		; Alloc new VBR
	MOVE.L	#MEMF_FAST|MEMF_PUBLIC,D1
	JSR	(_LVOAllocMem,A6)
	MOVEA.L	D0,A2
	TST.L	D0
	BEQ.B	.vbrmoved		; No FastMem

	SUBA.L	A0,A0		; Copy VBR
	MOVEA.L	D0,A1
	MOVE.W	#255,D1
.copyvbr:	MOVE.L	(A0)+,(A1)+
	DBRA	D1,.copyvbr

.vbrmoved:
*	move.l	A2,a1                 		; patch bpe grap
*	move.l	2*4(a2),Old_AccessFault
*	Lea	(New_AccessFault,pc),a1
* 	move.l  	a1,2*4(a2)
* 	move.l	a1,(2*4).w

	*> a2 = vbr & set

	DBUG	10,", Patch Task Stacks\n"

	LEA	(Install_Tasks,PC),A5		; Patch existing tasks for
	JSR	(_LVOSupervisor,A6)            ; operation
.quit:
*	JSR	(_LVOCacheClearU,a6)		; Be sure
	JSR	(_LVOEnable,A6)

	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

	* -----------------------------------------------------

GetVBR:	MOVEC	VBR,D0
	RTE

a26 51

Install_Tasks:	MOVE.W	#$2700,SR      		; Disturb by noone
	MOVE.L	A2,D0
	BEQ.B	.no_VBR
	MOVEC	D0,VBR
.no_VBR:	CINVA	DC		; Invalidate all DataCache Entries
	LEA	(TaskReady,A6),A3		; Get ready task list
.Install_ReadyTasks_Loop:
	MOVEA.L	(LN_SUCC,A3),A3		; Traverse Ready Tasks
	TST.L	(LN_SUCC,A3)
	BEQ	.Install_WaitingTasks
	BSR	ConvertStackFrames
	BRA	.Install_ReadyTasks_Loop

.Install_WaitingTasks:
	LEA	(TaskWait,A6),A3		; Install waiting tasks
.Install_WaitingTasks_Loop:
	MOVEA.L	(LN_SUCC,A3),A3
	TST.L	(LN_SUCC,A3)
	BEQ	.Install_Tasks_End
	BSR	ConvertStackFrames
	BRA	.Install_WaitingTasks_Loop

.Install_Tasks_End:
	CPUSHA           DC
	RTE

	; ------------------------------------------------------
	; These stacks have no NULL Frame add it. Set -1 to markerfiled
ConvertStackFrames:
	MOVEA.L	(TC_SPREG,A3),A5
	DBUG             10,"Convert Task '%s' (Stk:$%08lx %08lx)",LN_NAME(A3),4(a5),8(a5)
	CLR.L	-(A5)
	CLR.L	-(A5)
	CLR.L	-(A5)
	MOVE.L	A5,(TC_SPREG,A3)
	DBUG             10,"->(Stk:$%08lx$%08lx)\n",12+4(a5),12+8(a5)
	RTS



**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------

d36 3
a38 4
	cnop	0,4


FPU_Dispatcher:	MOVE.W	#$2000,SR	; Set Supervisor State
d73 1
a73 3
	FMOVE.L	FPIAR,-(A5)	; Ctrl Regs
	FMOVE.L	FPSR,-(A5)	;@@@@@@@@ MOVEM !
	FMOVE.L	FPCR,-(A5)
d176 2
a177 2
.idcont2:	MOVE.L	#0,-(A1)		; go supervisor
patchcode:	EQU	*-4                            ; change this crap
d180 1
a180 1
	BTST	#AFB_68010,(AttnFlags+1,A6)		;
d223 3
a225 1
NewLaunchPoint:	MOVEQ	#$20,D1	; CPU Vector/Offset to save
d241 1
a241 3
	FMOVE.L	(A5)+,FPCR	; load ctrl regs
	FMOVE.L	(A5)+,FPSR	;@@@@MOVEM.l OK !
	FMOVE.L	(A5)+,FPIAR
a261 38









*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------


Old_AccessFault:	dc.l	0

New_AccessFault:	DBUG	10,"Exception AccessFault!!!\n"

	BTST	#2,(12+3,SP)		; BPE ?
	BNE.B	New_AccessFault_BranchPredictionError

	MOVE.L	(Old_AccessFault,PC),-(sp)
	RTS


New_AccessFault_BranchPredictionError:
	DBUG	10,"Flush Branch Cache\n"

	MOVE.L	D0,-(SP)

	MOVEC	CACR,D0
	bset	#22,D0	; CABC
	MOVEC	D0,CACR
	NOP
	CPUSHA	BC
	MOVE.L	(SP)+,D0
	RTE

; --------------------------------------------------------------------------
@


1.7
log
@Code checked back and compared with Exec V39
@
text
@d140 1
d143 1
a143 5

	move.l	LN_NAME(A3),a1
	MOVE.L	(4,A5),D0
	DBUG             10,"Convert Task '%s' (Stk:$%08lx)",a1,d0

d148 1
a148 4

	MOVEQ	#0,D0
	MOVE.W	(12+4,A5),D0
	DBUG             10,"(Stk:$%04x)\n",d0
d178 1
d189 4
a192 2
*	ADDQ.W	#2,SP                  * Align      66    <- TaskFrame
                        MOVE.W           (SP)+,d1
d198 11
a208 2
*	MOVEQ	#-1,D2                         	; Terminal LW
	MOVE.L	d1,d2
d213 3
a215 1
	MOVE.L	D2,-(A5)               ; save terminal
d220 1
d363 4
d370 8
a377 1
	ADDQ.L	#4,A5                  ; skip marker
d382 10
d403 7
a409 2
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
@


1.6
log
@Working Version 40.2, 40.10ß2
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.5 1997/04/14 23:00:04 schlote Exp schlote $
d21 1
a21 1
MYDEBUG	SET              0
d41 1
a41 2
*	BSET	#AFB_PRIVATE,(AttnFlags,A6)    ; Set AttnFlag & quit if set bevor
	BSET	#7,(AttnFlags,A6)    ; Set AttnFlag & quit if set bevor
d53 1
a53 1
	LEA	(SWITCH060_FPU,PC),A0		; Set new taskswitch code
d59 1
a59 1
	DBUG	10,", New Dispatch Code"
d61 2
a62 1
	LEA	(RestartTaskFromA5,PC),A0	; Set new LaunchPoint
d170 7
a176 1
* Entered at execPrivate4()
d180 2
a181 1
SWITCH060_FPU:	MOVE.W	#$2000,SR	; Set Supervisor State
d185 1
a185 1

a186 1

a188 1

d194 3
a196 1
	ADDQ.W	#2,SP                  ; Align      66    <- TaskFrame
d198 1
a198 2
	FSAVE	-(A5)	; Save Stackframe
	TST.B	(2,A5)	; Test for Nullframe
d201 2
a202 1
	MOVEQ	#-1,D2                         	; Terminal LW
d205 1
a205 1
	FMOVE.L	FPSR,-(A5)
d209 3
d224 4
d248 1
a248 1
	MOVE.B	#TS_RUN,(pr_Task+TC_STATE,A3)	; Set Taskstate
a264 1
                        cnop 	0,4
d266 2
a267 1
	**--------------------------------------------------------
d307 1
a307 1
patchcode:	EQU	*-4
a323 2
	cnop	0,4

d343 13
a355 6
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------

RestartTaskFromA5:	MOVEQ	#$20,D1	; CPU Vector/Offset to save
	TST.B	(2,A5) 	; Test for Marker
	BEQ.B	.RestartA5_NullFrame
d359 1
a359 1
	FMOVE.L	(A5)+,FPSR
d362 1
a362 1
.RestartA5_NullFrame:
a372 2


a378 2
	cnop	4,4

d392 1
d399 1
a399 1
	CINVA	BC
@


1.5
log
@Working version
.
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.4 1997/04/14 22:47:28 schlote Exp schlote $
@


1.4
log
@Working version
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.3 1997/04/12 13:39:03 schlote Exp schlote $
@


1.3
log
@Temporärer Check weil ws geht.
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.2 1997/04/10 22:04:43 schlote Exp schlote $
d31 2
a32 2
	XDEF	_Install_Dispatcher
_Install_Dispatcher:
@


1.2
log
@Currently executes fine.... :-(
@
text
@d11 1
a11 1
** $Id: mc60_dispatcher.asm 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d21 1
a21 1
MYDEBUG	SET              1
d135 3
a137 1
.Install_Tasks_End:	RTE
a142 1
	MOVEQ	#0,D0
d144 2
a145 2
	MOVE.W	(4,A5),D0
	DBUG             10,"Convert Task '%s' (Stk:$%04x)",a1,d0
d170 1
@


1.1
log
@Initial revision
@
text
@d11 1
a11 1
** $Id$
d15 2
a16 1
	near
d21 5
a26 6
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
* AttnFlags geändert jetzt AFF_RESERVED8 !
a28 2

*> a5 = LibBase
d34 1
a34 1

d37 1
a37 1
	MOVE.W	(AttnFlags,A6),D0		; Is any kind of emu set ??
d41 2
a42 2
*	BSET	#AFB_68060,(AttnFlags+1,A6)            ; Set AttnFlag & quit if set bevor
	BSET	#AFB_68060,(AttnFlags,A6)            ; Set AttnFlag & quit if set bevor
d45 6
a50 4
*	LEA	(go_supervisor,PC),A0		; Patch code . argl..
*	LEA	(patchcode,PC),A1
*	MOVE.L	A0,(A1)
*	JSR	(_LVOCacheClearU,A6)		; dump caches to mem
d62 1
a62 1
	LEA	(DISPATCH060_FPU,PC),A0		; Set new LaunchPoint
d71 1
a71 1
	MOVE.L	#1024,D0		; Alloc new VBR
d85 5
a89 4
	move.l	A2,a1                      		; patch bpe grap
	move.l	2*4(a1),Old_AccessFault
 	move.l  	#New_AccessFault,2*4(a1)

d96 1
a96 1
	JSR	(_LVOSupervisor,A6)                    ; operation
d98 1
a98 1
	JSR	(_LVOCacheClearU,a6)		; Be sure
d117 1
a117 3

.no_VBR:
	CINVA	DC		; Invalidate all DataCache Entries
d120 5
a124 5
	MOVEA.L	(A3),A3		; Traverse Ready Tasks
	TST.L	(0,A3)
	BEQ.B	.Install_WaitingTasks
	BSR.B	ConvertStackFrames
	BRA.B	.Install_ReadyTasks_Loop
d129 5
a133 5
	MOVEA.L	(A3),A3
	TST.L	(0,A3)
	BEQ.B	.Install_Tasks_End
	BSR.B	ConvertStackFrames
	BRA.B	.Install_WaitingTasks_Loop
d139 7
a145 4
	MOVEA.L	(pr_Task+TC_SPREG,A3),A5
*	MOVEQ	#0,D0
*	MOVE.W	(4,A5),D0
*	DBUG             10,"#%04x->",d0
d149 5
a153 4
	MOVE.L	A5,(pr_Task+TC_SPREG,A3)
*	MOVEQ	#0,D0
*	MOVE.W	(12+4,A5),D0
*	DBUG             10,"%04x# ",d0
d173 1
a173 2

	MOVE.L	A5,-(SP)                       ; Save a5 to SSP !!!!!
d175 1
d177 1
a177 1
	MOVEM.L	D0-D7/A0-A6,-(A5)	; Save all regs to USP
a178 1
	MOVEA.L	(4).W,A6
d180 1
a180 1
	MOVE.W	#$FFFF,(IDNestCnt,A6)          ; lock both cnts to max.
d184 4
a187 5
	MOVE.L	(SP)+,($34,A5)	; (8*4)+(5*4)=32+20=52  correct A5 on USP

	MOVE.W	(SP)+,-(A5)	; Execption Stackframe to USP
	MOVE.L	(SP)+,-(A5)                    ;
	ADDQ.W	#2,SP                          ; Align
d190 1
a190 1
	TST.B	(2,A5)
d195 1
a195 1
	FMOVE.L	FPIAR,-(A5)		; Ctrl Regs
d198 2
a199 1
	MOVE.L	D2,-(A5)                               ; save terminal
d204 2
a205 2
	MOVE.W	D0,(pr_Task+TC_IDNESTCNT,A3)		; Save nest count to task context
	MOVE.L	A5,(pr_Task+TC_SPREG,A3)		; Remember Task StackPtr
d207 3
a209 3
	BTST	#TB_SWITCH,(pr_Task+TC_FLAGS,A3)	; Set Custom Switch Code
	BEQ.B	.nocustomswitch
	MOVEA.L	(pr_Task+TC_SWITCH,A3),A5
d212 4
a215 5
.nocustomswitch:	LEA	(TaskReady,A6),A0		; get a ready Task

.taskloop:	MOVE.W	#$2700,SR      		; Travese readly list
	MOVEA.L	(pr_Task,A0),A3                        ; wait until AddTail() added task
	MOVE.L	(pr_Task,A3),D0
a216 1

d222 1
a222 1
.taskendloop:	MOVE.L	D0,(pr_Task,A0)                        ; feed last task to end of ready queue
d224 1
a224 1
	MOVE.L	A0,(pr_Task+LN_PRED,A1)
d232 1
a232 1
	MOVE.B	#TS_RUN,(pr_Task+TC_STATE,A3)		  ; Set Taskstate
d234 2
a235 2
	MOVE.W	(pr_Task+TC_IDNESTCNT,A3),(IDNestCnt,A6) ; Restore Net Counts
	TST.B	(IDNestCnt,A6)                           ; restore IRQ state
a237 1

a239 1
	MOVE.B	(pr_Task+TC_FLAGS,A3),D0
d241 2
a242 1
	ANDI.B	#(TF_EXCEPT|TF_LAUNCH),D0		; Launch this task ???
a243 1

d246 2
a247 4
.conttask:
*@@@@@@@@@@@@	MOVEA.L	(pr_Task+TC_SPREG,A3),A5		; Get Task StackPtr
	MOVEA.L	(SysStkUpper,A3),A5		; Get Task StackPtr
	JMP	(A4)                                   ; ex_LaunchPoint code
d251 3
a253 1
.launchnewtask:	BTST	#TB_LAUNCH,D0
d257 1
a257 1
	MOVEA.L	(pr_Task+TC_LAUNCH,A3),A5		; Launch new task
d263 1
d265 2
a266 6
.endexception:
	RTS                                              	; otherwise goon

.Exception:	BCLR	#TB_EXCEPT,(pr_Task+TC_FLAGS,A3)

	MOVE.L	(pr_Task+TC_EXCEPTCODE,A3),D1		; d1=ExeceptionCode
d272 4
a275 4
	MOVE.L	(pr_Task+TC_SIGRECVD,A3),D0 		; Get mask of exceptions
	AND.L	(pr_Task+TC_SIGEXCEPT,A3),D0
	EOR.L	D0,(pr_Task+TC_SIGEXCEPT,A3)		; reset flags set.
	EOR.L	D0,(pr_Task+TC_SIGRECVD,A3)
d281 2
a282 2
	MOVEA.L	(pr_Task+TC_SPREG,A3),A1
	MOVE.L	(pr_Task+TC_FLAGS,A3),-(A1)
d290 2
a291 3
.idcont2:

	MOVE.L	#go_supervisor,-(A1)		; go supervisor
d294 1
a294 1
	BTST	#0,(AttnFlags+1,A6)		; AFB_RESERVED8 ?!??!
a295 1

d297 1
a297 2
.nofpuused:
	MOVE.L	D1,-(SP)
d299 1
a299 1
	MOVEA.L	(pr_Task+TC_EXCEPTDATA,A3),A1
d310 2
a311 2
.supercode:	MOVEA.L	(ex_LaunchPoint,A6),A4
	BTST	#0,(AttnFlags+1,A6)
d313 1
d315 3
a317 4
.nofpuused:
	ADDQ.L	#6,SP
	MOVEA.L	(ThisTask,A6),A3	; Set new Execept Bit if wanted
	OR.L	D0,(pr_Task+TC_SIGEXCEPT,A3)
d320 2
a321 4
	MOVE.L	(A1)+,(pr_Task+TC_FLAGS,A3)
	MOVE.L	A1,(pr_Task+TC_SPREG,A3)

	MOVE.W	(pr_Task+TC_IDNESTCNT,A3),(IDNestCnt,A6)
d323 1
a330 12
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------
d332 3
a334 3
DISPATCH060_FPU:	MOVEQ	#$20,D1
	TST.B	(2,A5)
	BEQ.B	.DISPATCH060_FPU_NullFrame
d336 2
a337 2
	ADDQ.L	#4,A5
	FMOVE.L	(A5)+,FPCR
d340 10
a349 1
	FMOVEM.X	(A5)+,FP0/FP1/FP2/FP3/FP4/FP5/FP6/FP7
a350 9
.DISPATCH060_FPU_NullFrame:
	FRESTORE	(A5)+
	LEA	($0042,A5),A2
	MOVE.L	A2,USP
	MOVE.W	D1,-(SP)
	MOVE.L	(A5)+,-(SP)	; return
	MOVE.W	(A5)+,-(SP)
	MOVEM.L	(A5),D0-D7/A0-A6               ; load regs
	RTE
d381 1
a381 1
	PFLUSHA
@
