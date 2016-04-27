head	1.2;
access;
symbols;
locks; strict;
comment	@;; @;


1.2
date	97.04.08.20.13.10;	author schlote;	state Exp;
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


1.2
log
@obsolete file ... now use isp.o and fpsp.o
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
** $Id: mc60_emulation.asm 1.1 1996/11/26 21:15:01 schlote Exp schlote $
**
** This module contains the Motorola Emulation Core for 060. 100% taken from Motorola !!!!
**

	machine	68060
	near

	include	"mc60_system.i"
	include	"mc60_libbase.i"
	include	"mc60_macros.i"

	section	emulation,code


*----------------------------------------------------------------------
*
* _060_dmem_write():
*
* Writes to data memory while in supervisor mode.
*
* INPUTS:
*	a0 - supervisor source address
*	a1 - user destination address
*	d0 - number of bytes to write
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_write
_060_dmem_write:
	MOVE.L	A6,-(SP)
	MOVEA.L	(4).W,A6
	JSR	(_LVOCopyMem,A6)
	MOVEA.L	(SP)+,A6
	MOVEQ	#0,D1
	RTS
*----------------------------------------------------------------------
*
* _060_imem_read(), _060_dmem_read():
*
* Reads from data/instruction memory while in supervisor mode.
*
* INPUTS:
*	a0 - user source address
*	a1 - supervisor destination address
*	d0 - number of bytes to read
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_imem_read
_060_imem_read:
	XDEF	_060_dmem_read
_060_dmem_read:
	MOVE.L	A6,-(SP)
	MOVEA.L	(4).W,A6
	JSR	(_LVOCopyMem,A6)
	MOVEA.L	(SP)+,A6
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_read_byte():
*
* Read a data byte from user memory.
*
* INPUTS:
*	a0 - user source address
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d0 - data byte in d0
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_read_byte
_060_dmem_read_byte:
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_read_word():
*
* Read a data word from user memory.
*
* INPUTS:
*	a0 - user source address
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d0 - data word in d0
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_read_word
_060_dmem_read_word:
	MOVEQ	#0,D0
	MOVE.W	(A0),D0
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_read_long():
*

*
* INPUTS:
*	a0 - user source address
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d0 - data longword in d0
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_read_long
_060_dmem_read_long:
	MOVE.L	(A0),D0
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_write_byte():
*
* Write a data byte to user memory.
*
* INPUTS:
*	a0 - user destination address
* 	d0 - data byte in d0
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_write_byte
_060_dmem_write_byte:
	MOVE.B	D0,(A0)
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_write_word():
*
* Write a data word to user memory.
*
* INPUTS:
*	a0 - user destination address
* 	d0 - data word in d0
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_write_word
_060_dmem_write_word:
	MOVE.W	D0,(A0)
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_dmem_write_long():
*
* Write a data longword to user memory.
*
* INPUTS:
*	a0 - user destination address
* 	d0 - data longword in d0
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_dmem_write_long
_060_dmem_write_long:
	MOVE.L	D0,(A0)
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_imem_read_word():
*
* Read an instruction word from user memory.
*
* INPUTS:
*	a0 - user source address
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d0 - instruction word in d0
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_imem_read_word
_060_imem_read_word:
	MOVE.W	(A0),D0
	MOVEQ	#0,D1
	RTS

*----------------------------------------------------------------------
*
* _060_imem_read_long():
*
* Read an instruction longword from user memory.
*
* INPUTS:
*	a0 - user source address
* 	0x4(%a6),bit5 - 1 = supervisor mode, 0 = user mode
* OUTPUTS:
*	d0 - instruction longword in d0
*	d1 - 0 = success, !0 = failure
*
	XDEF	_060_imem_read_long
_060_imem_read_long:
	MOVE.L	(A0),D0
	MOVEQ	#0,D1
	RTS


*----------------------------------------------------------------------
*
* _060_real_trace():
*
* This is the exit point for the 060FPSP when an instruction is being traced
* and there are no other higher priority exceptions pending for this instruction
* or they have already been processed.
*
* The sample code below simply executes an "rte".
*
	XDEF	_060_real_trace
_060_real_trace:
	RTE


*----------------------------------------------------------------------
*
* _060_real_access():
*
* This is the exit point for the 060FPSP when an access error exception
* is encountered. The routine below should point to the operating system
* handler for access error exceptions. The exception stack frame is an
* 8-word access error frame.
*
* The sample routine below simply executes an "rte" instruction which
* is most likely the incorrect thing to do and could put the system
* into an infinite loop. @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ !!!!!!!!!!!
*
                        XDEF	_060_real_access
_060_real_access:
	RTE






**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------


	XDEF	_Install_FPU_Emulation
_Install_FPU_Emulation:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	(Install_FPU_Emulation_Traps,PC),A5
	MOVEA.L	(4).W,A6
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#0,D0
	RTS

; --------------------------------------------------------------

Install_FPU_Emulation_Traps:
	ORI.W	#$0700,SR
	MOVEC	VBR,A2
	SETVECTOR	_060_fpsp_snan,54              ; _FPUExceptionHandler_SNAN
	SETVECTOR	_060_fpsp_operr,52             ; _FPUExceptionHandler_OpError
	SETVECTOR	_060_fpsp_ovfl,53              ; _FPUExceptionHandler_Overflow
	SETVECTOR	_060_fpsp_unfl,51              ; _FPUExceptionHandler_Underflow
	SETVECTOR	_060_fpsp_dz,50                ; _FPUExceptionHandler_DivByZero
	SETVECTOR	_060_fpsp_inex,49              ; _FPUExceptionHandler_InexactResult

	SETVECTOR	_060_fpsp_fline,11             ; _ExceptionHandler_UnimplFPUInst
	SETVECTOR	_060_fpsp_unsupp,55            ; _FPUExceptionHandler_UnimplDType
	SETVECTOR	_060_fpsp_effadd,60            ; _Unimplemented Eff Addr
	CPUSHA	DC
	RTE

* 48 ?? _FPUExceptionHandler_UnorderedCond


; --------------------------------------------------------------

Vector_54:	dc.l	0
Vector_52:	dc.l	0
Vector_53:	dc.l	0
Vector_51:	dc.l	0
Vector_50:	dc.l	0
Vector_49:	dc.l	0

Vector_11:	dc.l	0
Vector_55:	dc.l	0
Vector_60:	dc.l	0

; --------------------------------------------------------------
;  Emulation follows
; --------------------------------------------------------------
;
; _060_fpsp_done():
;
; This is the main exit point for the 68060 Floating-Point
; Software Package. For a normal exit, all 060FPSP routines call this
; routine. The operating system can do system dependent clean-up or
; simply execute an "rte" as with the sample code below.
;

_060_fpsp_done:	RTE

; --------------------------------------------------------------
;
; _060_real_ovfl():
;
; This is the exit point for the 060FPSP when an enabled overflow exception
; is present. The routine below should point to the operating system handler
; for enabled overflow conditions. The exception stack frame is an overflow
; stack frame. The FP state frame holds the EXCEPTIONAL OPERAND.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;

_060_real_ovfl:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_unfl():
;
; This is the exit point for the 060FPSP when an enabled underflow exception
; is present. The routine below should point to the operating system handler
; for enabled underflow conditions. The exception stack frame is an underflow
; stack frame. The FP state frame holds the EXCEPTIONAL OPERAND.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;
_060_real_unfl:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_operr():
;
; This is the exit point for the 060FPSP when an enabled operand error exception
; is present. The routine below should point to the operating system handler
; for enabled operand error exceptions. The exception stack frame is an operand error
; stack frame. The FP state frame holds the source operand of the faulting
; instruction.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;
_060_real_operr:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_snan():
;
; This is the exit point for the 060FPSP when an enabled signalling NaN exception
; is present. The routine below should point to the operating system handler
; for enabled signalling NaN exceptions. The exception stack frame is a signalling NaN
; stack frame. The FP state frame holds the source operand of the faulting
; instruction.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;
_060_real_snan:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_dz():
;
; This is the exit point for the 060FPSP when an enabled divide-by-zero exception
; is present. The routine below should point to the operating system handler
; for enabled divide-by-zero exceptions. The exception stack frame is a divide-by-zero
; stack frame. The FP state frame holds the source operand of the faulting
; instruction.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;
_060_real_dz:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_inex():
;
; This is the exit point for the 060FPSP when an enabled inexact exception
; is present. The routine below should point to the operating system handler
; for enabled inexact exceptions. The exception stack frame is an inexact
; stack frame. The FP state frame holds the source operand of the faulting
; instruction.
;
; The sample routine below simply clears the exception status bit and
; does an "rte".
;
_060_real_inex:	FSAVE	-(SP)
	MOVE.W	#$6000,(2,SP)
	FRESTORE	(SP)+
	RTE

; --------------------------------------------------------------
;
; _060_real_bsun():
;
; This is the exit point for the 060FPSP when an enabled bsun exception
; is present. The routine below should point to the operating system handler
; for enabled bsun exceptions. The exception stack frame is a bsun
; stack frame.
;
; The sample routine below clears the exception status bit, clears the NaN
; bit in the FPSR, and does an "rte". The instruction that caused the
; bsun will now be re-executed but with the NaN FPSR bit cleared.
;
_060_real_bsun:	FSAVE	-(SP)
	FMOVE.L	FPSR,-(SP)
	ANDI.B	#$FE,(SP)
	FMOVE.L	(SP)+,FPSR
	ADDA.L	#12,SP
	RTE

; --------------------------------------------------------------
;
; _060_real_fline():
;
; This is the exit point for the 060FPSP when an F-Line Illegal exception is
; encountered. Three different types of exceptions can enter the F-Line exception
; vector number 11: FP Unimplemented Instructions, FP implemented instructions when
; the FPU is disabled, and F-Line Illegal instructions. The 060FPSP module
; _fpsp_fline() distinguishes between the three and acts appropriately. F-Line
; Illegals branch here.
;
_060_real_fline:	MOVE.L	(Vector_11,PC),-(SP)
	RTS

; --------------------------------------------------------------
;
; _060_real_fpu_disabled():
;
; This is the exit point for the 060FPSP when an FPU disabled exception is
; encountered. Three different types of exceptions can enter the F-Line exception
; vector number 11: FP Unimplemented Instructions, FP implemented instructions when
; the FPU is disabled, and F-Line Illegal instructions. The 060FPSP module
; _fpsp_fline() distinguishes between the three and acts appropriately. FPU disabled
; exceptions branch here.
;
; The sample code below enables the FPU, sets the PC field in the exception stack
; frame to the PC of the instruction causing the exception, and does an "rte".
; The execution of the instruction then proceeds with an enabled floating-point
; unit.
;
_060_real_fpu_disabled:
	DBUG	10,"*** fpu disabled exception.  Solution: Enable FPU.\n"
	MOVE.L	D0,-(SP)	; enable FPU
                        MOVEC	PCR,D0
	BCLR	#1,D0
	MOVEC	D0,PCR
	MOVE.L	(SP)+,D0
	MOVE.L	(12,SP),(2,SP)	; set Current pc
	RTE

; --------------------------------------------------------------
;
; _060_real_trap():
;
; This is the exit point for the 060FPSP when an emulated "ftrapcc" instruction
; discovers that the trap condition is true and it should branch to the operating
; system handler for the trap exception vector number 7.
;
; The sample code below simply executes an "rte".
;
_060_real_trap:	RTE


; --------------------------------------------------------------

_060_fpsp_snan:         CALL_IN	_fpsp,0,"_060_fpsp_snan:        (SP: %08lx %08lx)\n"
_060_fpsp_operr:        CALL_IN	_fpsp,1,"_060_fpsp_operr:       (SP: %08lx %08lx)\n"
_060_fpsp_ovfl:         CALL_IN	_fpsp,2,"_060_fpsp_ovfl:        (SP: %08lx %08lx)\n"
_060_fpsp_unfl:         CALL_IN	_fpsp,3,"_060_fpsp_unfl:        (SP: %08lx %08lx)\n"
_060_fpsp_dz:           CALL_IN	_fpsp,4,"_060_fpsp_dz:          (SP: %08lx %08lx)\n"
_060_fpsp_inex:         CALL_IN	_fpsp,5,"_060_fpsp_inex:        (SP: %08lx %08lx)\n"
_060_fpsp_fline:        CALL_IN	_fpsp,6,"_060_fpsp_fline:       (SP: %08lx %08lx)\n"
_060_fpsp_unsupp:       CALL_IN	_fpsp,7,"_060_fpsp_unsupp:      (SP: %08lx %08lx)\n"
_060_fpsp_effadd:       CALL_IN	_fpsp,8,"_060_fpsp_effadd:      (SP: %08lx %08lx)\n"

; --------------------------------------------------------------

****  This is the list of Callouts !
****
****
****

_FP_CALL_TOP:
	dc.l	_060_real_bsun	- _FP_CALL_TOP
	dc.l	_060_real_snan	- _FP_CALL_TOP
	dc.l	_060_real_operr	- _FP_CALL_TOP
	dc.l	_060_real_ovfl	- _FP_CALL_TOP
	dc.l	_060_real_unfl	- _FP_CALL_TOP
	dc.l	_060_real_dz	- _FP_CALL_TOP
	dc.l	_060_real_inex	- _FP_CALL_TOP
	dc.l	_060_real_fline	- _FP_CALL_TOP
	dc.l	_060_real_fpu_disabled	- _FP_CALL_TOP
	dc.l	_060_real_trap	- _FP_CALL_TOP
	dc.l	_060_real_trace	- _FP_CALL_TOP
	dc.l	_060_real_access	- _FP_CALL_TOP
	dc.l	_060_fpsp_done	- _FP_CALL_TOP
	dcb.l	3,0

	dc.l	_060_imem_read	- _FP_CALL_TOP
	dc.l	_060_dmem_read	- _FP_CALL_TOP
	dc.l	_060_dmem_write	- _FP_CALL_TOP
	dc.l	_060_imem_read_word	- _FP_CALL_TOP
	dc.l	_060_imem_read_long	- _FP_CALL_TOP
	dc.l	_060_dmem_read_byte	- _FP_CALL_TOP
	dc.l	_060_dmem_read_word	- _FP_CALL_TOP
	dc.l	_060_dmem_read_long	- _FP_CALL_TOP
	dc.l	_060_dmem_write_byte	- _FP_CALL_TOP
	dc.l	_060_dmem_write_word	- _FP_CALL_TOP
	dc.l	_060_dmem_write_long	- _FP_CALL_TOP
	dcb.l	5,0

_fpsp:	include     "fpsp.sa"

	end
@


1.1
log
@Initial revision
@
text
@d11 1
a11 1
** $Id$
a25 48
*--------------------------------------------------------
*
* Each IO routine checks to see if the memory write/read is to/from user
* or supervisor application space. The examples below use simple "move"
* instructions for supervisor mode applications and call _copyin()/_copyout()
* for user mode applications.
* When installing the 060SP, the _copyin()/_copyout() equivalents for a
* given operating system should be substituted.
*
* The addresses within the 060SP are guaranteed to be on the stack.
* The result is that Unix processes are allowed to sleep as a consequence
* of a page fault during a _copyout.
*

  	XDEF	_Install_Mem_Library
_Install_Mem_Library:
	LEA	(_060_imem_read,PC),A0
	MOVE.L	A0,(mc60_imem_read,A5)

	LEA	(_060_dmem_read,PC),A0
	MOVE.L	A0,(mc60_dmem_read,A5)

	LEA	(_060_dmem_write,PC),A0
	MOVE.L	A0,(mc60_dmem_write,A5)

	LEA	(_060_imem_read_word,PC),A0
	MOVE.L	A0,(mc60_imem_read_word,A5)
	LEA	(_060_imem_read_long,PC),A0
	MOVE.L	A0,(mc60_imem_read_long,A5)
	LEA	(_060_dmem_read_byte,PC),A0
	MOVE.L	A0,(mc60_dmem_read_byte,A5)

	LEA	(_060_dmem_read_word,PC),A0
	MOVE.L	A0,(mc60_dmem_read_word,A5)
	LEA	(_060_dmem_read_long,PC),A0
	MOVE.L	A0,(mc60_dmem_read_long,A5)

	LEA	(_060_dmem_write_byte,PC),A0
	MOVE.L	A0,(mc60_dmem_write_byte,A5)
	LEA	(_060_dmem_write_word,PC),A0
	MOVE.L	A0,(mc60_dmem_write_word,A5)
	LEA	(_060_dmem_write_long,PC),A0
	MOVE.L	A0,(mc60_dmem_write_long,A5)

	LEA	(_060_real_access,PC),A0
	MOVE.L	A0,(mc60_real_access,A5)
	RTS

a261 213
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------
**-------------------------------------------------------------------------------

  	XDEF	_Install_Int_Emulation
_Install_Int_Emulation:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	(Install_I_Emulation_Traps,PC),A5
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

Install_I_Emulation_Traps:
	ORI.W	#$0700,SR
	MOVEC	VBR,A2
	SETVECTOR	_060_isp_unimp,61
	CPUSHA	DC
	RTE

* ----------------------------------------------------------

Vector_61:	dc.l	0

* ----------------------------------------------------------
*
* _060_isp_done():
*
* This is and example main exit point for the Unimplemented Integer
* Instruction exception handler. For a normal exit, the
* _isp_unimp() branches to here so that the operating system
* can do any clean-up desired. The stack frame is the
* Unimplemented Integer Instruction stack frame with
* the PC pointing to the instruction following the instruction
* just emulated.
* To simply continue execution at the next instruction, just
* do an "rte".
*
_060_isp_done:	RTE

* ----------------------------------------------------------
*
* _060_real_chk():
*
* This is an alternate exit point for the Unimplemented Integer
* Instruction exception handler. If the instruction was a "chk2"
* and the operand was out of bounds, then _isp_unimp() creates
* a CHK exception stack frame from the Unimplemented Integer Instrcution
* stack frame and branches to this routine.
*
_060_real_chk:	TST.B	(SP)
	BPL.B	real_chk_end
*
*	    CHK FRAME		   TRACE FRAME
*	*****************	*****************
*	*   Current PC	*	*   Current PC	*
*	*****************	*****************
*	* $2 *  $018	*	* $2 *  $024	*
*	*****************	*****************
*	*     Next	*	*     Next	*
*	*      PC	*	*      PC	*
*	*****************	*****************
*	*      SR	*	*      SR	*
*	*****************	*****************
*
	MOVE.B	#$24,(7,SP)
	BRA.L	_060_real_trace

real_chk_end:	RTE

* ----------------------------------------------------------
*
* _060_real_divbyzero:
*
* This is an alternate exit point for the Unimplemented Integer
* Instruction exception handler isp_unimp(). If the instruction is a 64-bit
* integer divide where the source operand is a zero, then the _isp_unimp()
* creates a Divide-by-zero exception stack frame from the Unimplemented
* Integer Instruction stack frame and branches to this routine.
*
* Remember that a trace exception may be pending. The code below performs
* no action associated with the "chk" exception. If tracing is enabled,
* then it create a Trace exception stack frame from the "chk" exception
* stack frame and branches to the _real_trace() entry point.
*
_060_real_divbyzero:
	TST.B	(SP)
	BPL.B	real_divbyzero_end
*
*	 DIVBYZERO FRAME	   TRACE FRAME
*	*****************	*****************
*	*   Current PC	*	*   Current PC	*
*	*****************	*****************
*	* $2 *  $014	*	* $2 *  $024	*
*	*****************	*****************
*	*     Next	*	*     Next	*
*	*      PC	*	*      PC	*
*	*****************	*****************
*	*      SR	*	*      SR	*
*	*****************	*****************
*
	MOVE.B	#$24,(7,SP)
	BRA.L	_060_real_trace

real_divbyzero_end:	RTE

* ----------------------------------------------------------
*
* _060_real_cas():
*
* Entry point for the selected cas emulation code implementation.
* If the implementation provided by the 68060ISP is sufficient,
* then this routine simply re-enters the package through _isp_cas.
*
_060_real_cas:	BRA.L	_isp+(1*8)

* ----------------------------------------------------------
*
* _060_real_cas2():
*
* Entry point for the selected cas2 emulation code implementation.
* If the implementation provided by the 68060ISP is sufficient,
* then this routine simply re-enters the package through _isp_cas2.
*
_060_real_cas2:	BRA.L            _isp+(2*8)

* ----------------------------------------------------------
*
* _060_lock_page():
*
* Entry point for the operating system's routine to "lock" a page
* from being paged out. This routine is needed by the cas/cas2
* algorithms so that no page faults occur within the "core" code
* region. Note: the routine must lock two pages if the operand
* spans two pages.
* NOTE: THE ROUTINE SHOULD RETURN AN FSLW VALUE IN D0 ON FAILURE
* SO THAT THE 060SP CAN CREATE A PROPER ACCESS ERROR FRAME.
* Arguments:
*	a0 = operand address
*	d0 = `xxxxxxff -> supervisor; `xxxxxx00 -> user
*	d1 = `xxxxxxff -> longword; `xxxxxx00 -> word
* Expected outputs:
*	d0 = 0 -> success; non-zero -> failure
*
_060_real_lock_page:
	CLR.L	D0
	RTS


* ----------------------------------------------------------
*
* _060_unlock_page():
*
* Entry point for the operating system's routine to "unlock" a
* page that has been "locked" previously with _real_lock_page.
* Note: the routine must unlock two pages if the operand spans
* two pages.
* Arguments:
* 	a0 = operand address
*	d0 = `xxxxxxff -> supervisor; `xxxxxx00 -> user
*	d1 = `xxxxxxff -> longword; `xxxxxx00 -> word
*
_060_real_unlock_page:
	CLR.L	D0
	RTS



* ----------------------------------------------------------

_060_isp_unimp:	CALL_IN	_isp,0,"_060_isp_unimp:	 (SP: %08lx %08lx)\n"
_060_isp_cas:           CALL_IN	_isp,1,"_060_isp_cas:           (SP: %08lx %08lx)\n"
_060_isp_cas2:          CALL_IN	_isp,2,"_060_isp_cas2:          (SP: %08lx %08lx)\n"
_060_isp_cas_finish:    CALL_IN	_isp,3,"_060_isp_cas_finish:    (SP: %08lx %08lx)\n"
_060_isp_cas2_finish:   CALL_IN	_isp,4,"_060_isp_cas2_finish:   (SP: %08lx %08lx)\n"
_060_isp_cas_inrange:   CALL_IN	_isp,5,"_060_isp_cas_inrange:   (SP: %08lx %08lx)\n"
_060_isp_cas_terminate: CALL_IN	_isp,6,"_060_isp_cas_terminate: (SP: %08lx %08lx)\n"
_060_isp_cas_restart:   CALL_IN	_isp,7,"_060_isp_cas_restart:   (SP: %08lx %08lx)\n"

* ----------------------------------------------------------

_I_CALL_TOP:	dc.l	_060_real_chk	- _I_CALL_TOP
	dc.l	_060_real_divbyzero	- _I_CALL_TOP
	dc.l	_060_real_trace	- _I_CALL_TOP
	dc.l	_060_real_access	- _I_CALL_TOP
	dc.l	_060_isp_done	- _I_CALL_TOP
	dc.l	_060_real_cas	- _I_CALL_TOP
	dc.l	_060_real_cas2	- _I_CALL_TOP
	dc.l	_060_real_lock_page	- _I_CALL_TOP
	dc.l	_060_real_unlock_page	- _I_CALL_TOP
	dcb.l	7,0


	dc.l	_060_imem_read	- _I_CALL_TOP
	dc.l	_060_dmem_read	- _I_CALL_TOP
	dc.l	_060_dmem_write	- _I_CALL_TOP
	dc.l	_060_imem_read_word	- _I_CALL_TOP
	dc.l	_060_imem_read_long	- _I_CALL_TOP
	dc.l	_060_dmem_read_byte	- _I_CALL_TOP
	dc.l	_060_dmem_read_word	- _I_CALL_TOP
	dc.l	_060_dmem_read_long	- _I_CALL_TOP
	dc.l	_060_dmem_write_byte	- _I_CALL_TOP
	dc.l	_060_dmem_write_word	- _I_CALL_TOP
	dc.l	_060_dmem_write_long	- _I_CALL_TOP
	dcb.l	5,0

_isp:	include 	"isp.sa"

d494 1
a494 1
	DBUG	10,"*** fpu disabled exception.\n"
@
