
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: 68060.library.asm,v 1.5 1996/06/09 21:16:18 schlote Exp schlote $
**
**
	include	68060.library.i

**-------------------------------------------------------------------------------

	SECTION	68060library_newrs000000,CODE
	MOVEQ	#-1,D0
	RTS

**-------------------------------------------------------------------------------
RomTag:	ILLEGAL
	dc.l	RomTag
	dc.l	RomTagEnd
	dc.b	RTF_AUTOINIT
	dc.b	40
	dc.b	NT_LIBRARY
	dc.b	0
	dc.l	LibName
	dc.l	IDString
	dc.l	InitTable
**-------------------------------------------------------------------------------

LibName:	dc.b	'68060.library',0
IDString:	dc.b	'68060.library (c) by Silicon Department',0,0
	dc.b	0

InitTable:	dc.l	170
	dc.l	funcTable
	dc.l	dataTable
	dc.l	initRoutine

funcTable:	dc.l	Open
	dc.l	Close
	dc.l	Expunge
	dc.l	Null
	dc.l	__SetIllegalPageValue
	dc.l	__SetIllegalPageMode
	dc.l	__GetIllegalPage
	dc.l	__SetZeroPageMode
	dc.l	__SetPageProtectMode
	dc.l	__SetRomAddress
	dc.l	_FlushMMU,$FFFFFFFF

dataTable:	INITBYTE	$08,9
	INITLONG	$0a,LibName
                        INITBYTE	$0e,6
	INITWORD	$14,40
	INITWORD	$16,1
	INITLONG	$18,IDString
                        dc.w	0
                        cnop	0,4
; --------------------------------------------------------------------------
LibBase:	dc.l	0
SysBase:	dc.l	0
; --------------------------------------------------------------------------

initRoutine:	MOVEM.L	D1-D7/A0-A6,-(SP)
	MOVEA.L	D0,A5
	MOVE.L	D0,(LibBase).L
	MOVE.L	A6,($0024,A5)
	MOVE.L	A6,(SysBase).L
	MOVE.L	A0,($0030,A5)

	LEA	(cardname,PC),A0
	MOVE.L	A0,($0038,A5)
	LEA	(cdstrapname,PC),A0
	MOVE.L	A0,($003C,A5)
	LEA	(expansionname,PC),A0
	MOVE.L	A0,($0040,A5)

	MOVE.L	#_BuildMMU,($0044,A5)
	MOVE.L	#$00F03400,($0048,A5)

	LEA	($004C,A5),A1

	LEA	($0014,A1),A0
	MOVE.L	A0,(8,A0)
	ADDQ.L	#4,A0
	CLR.L	(A0)
	MOVE.L	A0,-(A0)

	MOVE.B	#2,(14,A1)
	MOVE.B	#4,(8,A1)
	MOVE.B	#$80,(9,A1)
	LEA	(FPUPatchPortName,PC),A0
	MOVE.L	A0,(10,A1)

	JSR	(_LVOAddPort,A6)

	MOVE.W	#%0000000010001111,(AttnFlags,A6)
	LEA	(0).L,A4

	JSR	(_LVOCacheClearU,A6)
	JSR	(_LVOForbid,A6)

	MOVEA.L	(LibBase,PC),A6
	JSR	(Install_Mem_Library).L
	JSR	(Install_Exec_Patches).L	;-> _buildmmu
	JSR	(Install_Int_Emulation).L
	JSR	(Install_FPU_Emulation).L

	MOVEA.L	(LibBase,PC),A6
	JSR	(Install_FPU_Libraries).L

	MOVEA.L	(SysBase,PC),A6
	ORI.W	#%0000000001110000,(AttnFlags,A6)
	JSR	(Install_Dispatcher).L
	JSR	(Install_Caches).L
	JSR	(_LVOPermit,A6)

	MOVEQ	#0,D0
	MOVE.W	(AttnFlags,A6),D0

	MOVE.L	A5,D0
	MOVEM.L	(SP)+,D1-D7/A0-A6
	RTS

; --------------------------------------------------------------------------
Open:	ADDQ.W	#1,(LIB_OPENCNT,A6)
	BCLR	#3,(LIB_SIZE,A6)
	MOVE.L	A6,D0
	RTS

; --------------------------------------------------------------------------
Close:	MOVEQ	#0,D0
	SUBQ.W	#1,(LIB_OPENCNT,A6)
	BNE.B	lbC0001B4
	BTST	#3,(LIB_SIZE,A6)
	BEQ.B	lbC0001B4
	BSR.W	Expunge
lbC0001B4:	RTS

; --------------------------------------------------------------------------
Expunge:	MOVEQ	#0,D0
	RTS

;fiX Label expected
	MOVEM.L	D2/A5/A6,-(SP)
	MOVEA.L	A6,A5
	MOVEA.L	($0024,A5),A6
	TST.W	(LIB_OPENCNT,A5)
	BEQ.W	lbC0001D6
	BSET	#3,(LIB_SIZE,A5)
	MOVEQ	#0,D0
	BRA.B	Expunge_End

lbC0001D6:	MOVE.L	($0030,A5),D2
	MOVEA.L	A5,A1
	JSR	(_LVORemove,A6)
	MOVEQ	#0,D0
	MOVEA.L	A5,A1
	MOVE.W	($0010,A5),D0
	SUBA.L	D0,A1
	ADD.W	($0012,A5),D0
	JSR	(_LVOFreeMem,A6)
	MOVE.L	D2,D0
Expunge_End:	MOVEM.L	(SP)+,D2/A5/A6
	RTS

; --------------------------------------------------------------------------
Null:	MOVEQ	#0,D0
	RTS

; --------------------------------------------------------------------------
cardname:	dc.b	'card.resource',0
cdstrapname:	dc.b	'cdstrap',0
expansionname:	dc.b	'expansion.library',0
FPUPatchPortName:	dc.b	'68060_PatchPort',0




; ------------------------------------------------------------------------------------------------------
; ------------------------------------------------------------------------------------------------------
; ------------------------------------------------------------------------------------------------------
; ------------------------------------------------------------------------------------------------------
; ------------------------------------------------------------------------------------------------------
; ------------------------------------------------------------------------------------------------------

;	section	fpsp,data
Install_FPU_Emulation:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	(Install_FPU_Emulation_Traps,PC),A5
	MOVEA.L	(4).W,A6
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#0,D0
	RTS

; --------------------------------------------------------------

Install_FPU_Emulation_Traps:
	MOVEC	VBR,A2
	FPSP_SETVECTOR	0,54
	FPSP_SETVECTOR	1,52
	FPSP_SETVECTOR	2,53
	FPSP_SETVECTOR	3,51
	FPSP_SETVECTOR	4,50
	FPSP_SETVECTOR	5,49
	FPSP_SETVECTOR   6,11
	FPSP_SETVECTOR	7,55
	FPSP_SETVECTOR   8,60
	RTE

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

_060_fpsp_snan:         FPSP_ENTRY 	0	
_060_fpsp_operr:        FPSP_ENTRY  	1
_060_fpsp_ovfl:         FPSP_ENTRY 	2
_060_fpsp_unfl:         FPSP_ENTRY 	3
_060_fpsp_dz:           FPSP_ENTRY  	4
_060_fpsp_inex:         FPSP_ENTRY  	5
_060_fpsp_fline:        FPSP_ENTRY  	6
_060_fpsp_unsupp:       FPSP_ENTRY  	7
_060_fpsp_effadd:       FPSP_ENTRY  	8
                                    
; --------------------------------------------------------------

_FP_CALL_TOP:	dc.l	_060_real_bsun		- _FP_CALL_TOP
	dc.l	_060_real_snan		- _FP_CALL_TOP
	dc.l	_060_real_operr	- _FP_CALL_TOP
	dc.l	_060_real_ovfl		- _FP_CALL_TOP
	dc.l	_060_real_unfl		- _FP_CALL_TOP
	dc.l	_060_real_dz		- _FP_CALL_TOP
	dc.l	_060_real_inex		- _FP_CALL_TOP
	dc.l	_060_real_fline	- _FP_CALL_TOP
	dc.l	_060_real_fpu_disabled	- _FP_CALL_TOP
	dc.l	_060_real_trap		- _FP_CALL_TOP
	dc.l	_060_real_trace	- _FP_CALL_TOP
	dc.l	_060_real_access	- _FP_CALL_TOP
	dc.l	_060_fpsp_done		- _FP_CALL_TOP
	dcb.l	3,0

	dc.l	_060_imem_read		- _FP_CALL_TOP
	dc.l	_060_dmem_read		- _FP_CALL_TOP
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

*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------

*	section          compilerlib,data
Install_FPU_Libraries:
	LEA	(_060FPLSP_TOP,PC),A0
	MOVE.L	A0,($0072,A6)
	LEA	(_060ILSP_TOP,PC),A0
	MOVE.L	A0,($0076,A6)
	RTS

	cnop	0,4
_060FPLSP_TOP:	include          "fpsp_lib.sa"

	cnop	0,4
_060ILSP_TOP:	include          "isp_lib.sa"


*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------

*	section	isp,data
Install_Int_Emulation:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	(Install_I_Emulation_Traps,PC),A5
	MOVEA.L	(4).W,A6
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#0,D0
	RTS

Install_I_Emulation_Traps:
	MOVEC	VBR,A2
	ISP_SETVECTOR	_060_isp_unimp,61
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
	BRA.L	_060_real_trace2

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
	BRA.L	_060_real_trace2

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

_060_isp_unimp:	BRA.L	_isp+(0*8)
_060_isp_cas:	BRA.L	_isp+(1*8)
_060_isp_cas2:	BRA.L	_isp+(2*8)
_060_isp_cas_finish:	BRA.L	_isp+(3*8)
_060_isp_cas2_finish:	BRA.L	_isp+(4*8)
_060_isp_cas_inrange:	BRA.L	_isp+(5*8)
_060_isp_cas_terminate:	BRA.L	_isp+(6*8)
_060_isp_cas_restart:	BRA.L	_isp+(7*8)

* ----------------------------------------------------------

_I_CALL_TOP:	dc.l	_060_real_chk		- _I_CALL_TOP
	dc.l	_060_real_divbyzero	- _I_CALL_TOP
	dc.l	_060_real_trace	- _I_CALL_TOP
	dc.l	_060_real_access	- _I_CALL_TOP
	dc.l	_060_isp_done		- _I_CALL_TOP
	dc.l	_060_real_cas		- _I_CALL_TOP
	dc.l	_060_real_cas2		- _I_CALL_TOP
	dc.l	_060_real_lock_page	- _I_CALL_TOP
	dc.l	_060_real_unlock_page	- _I_CALL_TOP
	dcb.l	7,0


	dc.l	_060_imem_read		- _I_CALL_TOP
	dc.l	_060_dmem_read		- _I_CALL_TOP
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

*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------

*	section	memlib,data
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

Install_Mem_Library:
	LEA	(_060_imem_read,PC),A0
	MOVE.L	A0,($007A,A6)
	LEA	(_060_dmem_read,PC),A0
	MOVE.L	A0,($007E,A6)
	LEA	(_060_dmem_write,PC),A0
	MOVE.L	A0,($0082,A6)
	LEA	(_060_imem_read_word,PC),A0
	MOVE.L	A0,($0086,A6)
	LEA	(_060_imem_read_long,PC),A0
	MOVE.L	A0,($008A,A6)
	LEA	(_060_dmem_read_byte,PC),A0
	MOVE.L	A0,($008E,A6)
	LEA	(_060_dmem_read_word,PC),A0
	MOVE.L	A0,($0092,A6)
	LEA	(_060_dmem_read_long,PC),A0
	MOVE.L	A0,($0096,A6)
	LEA	(_060_dmem_write_byte,PC),A0
	MOVE.L	A0,($009A,A6)
	LEA	(_060_dmem_write_word,PC),A0
	MOVE.L	A0,($009E,A6)
	LEA	(_060_dmem_write_long,PC),A0
	MOVE.L	A0,($00A2,A6)

	LEA	(_060_real_access,PC),A0
	MOVE.L	A0,($00A6,A6)
	RTS

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
_060_dmem_write:	MOVE.L	A6,-(SP)
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
_060_imem_read:
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
_060_real_trace:	RTE
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
* into an infinite loop.
*
_060_real_access:	RTE


*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------


; --------------------------------------------------------------------------
Install_Exec_Patches:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVEA.L	A6,A2
	MOVEA.L	(4).W,A6

	JSR	(_LVODisable,A6)

	MOVEQ	#0,D0
	MOVEQ	#-1,D1
	JSR	(_LVOCacheControl,A6)
	MOVE.L	D0,-(SP)

	LEA	(NewCachePreDMA,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.W	#_LVOCachePreDMA,A0
	JSR	(_LVOSetFunction,A6)

	LEA	(NewCachePostDMA,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.W	#_LVOCachePostDMA,A0
	JSR	(_LVOSetFunction,A6)

	LEA	(NewSupervisor,PC),A0
	MOVE.L	(LIB_Supervisor+2,A6),D0
	MOVE.L	A0,(LIB_Supervisor+2,A6)
	LEA	(OldSupervisor,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewCacheControl,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOCacheControl,A0
	JSR	(_LVOSetFunction,A6)

	LEA	(NewAddLibrary,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOAddLibrary,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldAddLibrary,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewAddDevice,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOAddDevice,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldAddDevice,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewAddResource,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOAddResource,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldAddResource,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewAddTask,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOAddTask,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldAddTask,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewAddIntServer,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOAddIntServer,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldAddIntServer,PC),A0
	MOVE.L	D0,(A0)

	LEA	(NewSetIntVector,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.L	#_LVOSetIntVector,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldSetIntVector,PC),A0
	MOVE.L	D0,(A0)

	LEA	(DeviceList,A6),A0
	LEA	(InputName,PC),A1
	JSR	(_LVOFindName,A6)
	MOVEA.L	D0,A1
	TST.L	D0
	BEQ.B	NoINDPatch

	LEA	(NewBeginIO,PC),A0
	MOVE.L	A0,D0
	MOVEA.W	#$FFE2,A0
	JSR	(_LVOSetFunction,A6)
	LEA	(OldBeginIO,PC),A0
	MOVE.L	D0,(A0)

NoINDPatch:	MOVEA.L	A2,A6
	MOVEA.L	($0044,A6),A0	;_buildMMU
	JSR	(A0)
	MOVEA.L	(4).W,A6
	TST.L	D0
	BEQ.B	NoMMU
	MOVE.L	D0,($0034,A2)

	LEA	(OnMMU,PC),A5
	JSR	(_LVOSupervisor,A6)
NoMMU:	MOVE.L	(SP)+,D0
	MOVEQ	#-1,D1
	JSR	(_LVOCacheControl,A6)
	JSR	(_LVOEnable,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; --------------------------------------------------------------------------
TestMMU:	MOVEQ	#0,D0
	RTE

;fiX Label expected
	MOVEC	DTT1,D1
	ANDI.B	#$9F,D1
	ORI.B	#$20,D1
	MOVEC	D1,DTT1
	MOVEQ	#0,D0
	RTE

;fiX Label expected
	MOVEQ	#0,D0
	ORI.W	#$0700,SR
	MOVEC	TC,D1
	TST.W	D1
	BMI.B	tmmu_On
	BSET	#15,D1
	MOVEC	D1,TC
	MOVEC	TC,D1
	MOVEC	D0,TC
	TST.W	D1
	BPL.B	tmmu_Done
tmmu_On:	MOVE.L	#$00F80000,D0
	MOVEQ	#1,D1
	MOVEC	D1,DFC
	MOVEC	D1,SFC
tmmu_Done:	RTE

; --------------------------------------------------------------------------
OnMMU:	ORI.W	#$0700,SR	;d0=MMUFrame
	LEA	(MMUFrame,PC),A0
	MOVE.L	D0,(A0)

	MOVEA.L	D0,A0
	PFLUSHA		;MC68040
	MOVE.L	(0,A0),D0
	MOVEC	D0,URP
	MOVE.L	(4,A0),D0
	MOVEC	D0,SRP
	MOVE.L	(8,A0),D0
	MOVEC	D0,TC

	PFLUSHA		;MC68040
	MOVEQ	#0,D0
	MOVEC	D0,ITT0
	MOVEC	D0,ITT1
	MOVEC	D0,DTT0
	MOVEC	D0,DTT1
	RTE

; --------------------------------------------------------------------------
NewSupervisor:	CMPI.L	#$42A7F35F,(A5)
	BNE.B	NewSupervisor_Start
	CMPI.W	#$4E73,(4,A5)
	BNE.B	NewSupervisor_Start
	RTS

NewSupervisor_Start:
	MOVE.L	(OldSupervisor,PC),-(SP)
	RTS

; --------------------------------------------------------------------------
NewBusError:	BTST	#2,(15,SP)
	BNE.B	NewBusError_BranchPredictionError
	RTE

;fiX Label expected
	NOP
NewBusError_BranchPredictionError:
	MOVE.L	D0,-(SP)
	MOVEC	CACR,D0
	ORI.L	#$00400000,D0
	MOVEC	D0,CACR
	MOVE.L	(SP)+,D0
	RTE

; --------------------------------------------------------------------------
NewAddLibrary:	MOVE.L	(OldAddLibrary,PC),-(SP)
	MOVE.L	A1,-(SP)
	JSR	(_LVOCacheClearU,A6)
	MOVEA.L	(SP)+,A1
	RTS

; --------------------------------------------------------------------------
NewAddDevice:	MOVE.L	(OldAddDevice,PC),-(SP)
	MOVE.L	A1,-(SP)
	JSR	(_LVOCacheClearU,A6)
	MOVEA.L	(SP)+,A1
	RTS

; --------------------------------------------------------------------------
NewAddResource:	MOVE.L	(OldAddResource,PC),-(SP)
	MOVE.L	A1,-(SP)
	JSR	(_LVOCacheClearU,A6)
	MOVEA.L	(SP)+,A1
	RTS

; --------------------------------------------------------------------------
NewAddTask:	PEA	(NewAddTask_Start,PC)
	MOVE.L	(OldAddTask,PC),-(SP)
	MOVE.L	A1,-(SP)
	JSR	(_LVOForbid,A6)
	JSR	(_LVOCacheClearU,A6)
	MOVEA.L	(SP)+,A1
	RTS

NewAddTask_Start:	MOVEM.L	D0/D1/A0/A1,-(SP)
	TST.L	D0
	BEQ.B	lbC017708
	MOVEA.L	D0,A0
	MOVEA.L	(pr_Task+TC_SPREG,A0),A1
	CLR.L	-(A1)
	CLR.L	-(A1)
	MOVE.L	A1,(pr_Task+TC_SPREG,A0)
lbC017708:	JSR	(_LVOPermit,A6)
	MOVEM.L	(SP)+,D0/D1/A0/A1
	RTS

; --------------------------------------------------------------------------
NewAddIntServer:	MOVE.L	(OldAddIntServer,PC),-(SP)
	MOVEM.L	D0/A1,-(SP)
	JSR	(_LVOCacheClearU,A6)
	MOVEM.L	(SP)+,D0/A1
	RTS

; --------------------------------------------------------------------------
NewSetIntVector:	MOVE.L	(OldSetIntVector,PC),-(SP)
	MOVEM.L	D0/A1,-(SP)
	JSR	(_LVOCacheClearU,A6)
	MOVEM.L	(SP)+,D0/A1
	RTS

; --------------------------------------------------------------------------
NewBeginIO:	MOVE.L	(OldBeginIO,PC),-(SP)
	CMPI.W	#9,($001C,A1)
	BNE.B	Not_ADDHANDLER
	MOVEM.L	A1/A6,-(SP)
	MOVEA.L	(4).W,A6
	JSR	(_LVOCacheClearU,A6)
	MOVEM.L	(SP)+,A1/A6
Not_ADDHANDLER:	RTS

; --------------------------------------------------------------------------
NewCachePostDMA:	BTST	#3,D0
	BNE.W	dma_Caches
	MOVE.L	A0,D1
	OR.L	(A1),D1
	ANDI.B	#15,D1
	BEQ.W	dma_Caches
	MOVE.L	(MMUFrame,PC),D1
	BNE.B	On_MMU_Way
	LEA	(Nest_Count,PC),A1
	SUBQ.L	#1,(A1)
	BRA.B	dma_Caches

On_MMU_Way:	MOVE.L	A0,-(SP)
	MOVE.L	A4,-(SP)
	LEA	(On_MMU_Page,PC),A4
	BRA.W	MMU_Way

; --------------------------------------------------------------------------
NewCachePreDMA:	BTST	#1,D0
	BNE.B	ncp_Continue
	BTST	#3,D0
	BNE.B	ncp_Continue
	MOVE.L	A0,D1
	OR.L	(A1),D1
	ANDI.B	#15,D1
	BEQ.B	ncp_Continue
	MOVE.L	(MMUFrame,PC),D1
	BNE.B	Off_MMU_Way
	LEA	(Nest_Count,PC),A1
	ADDQ.L	#1,(A1)
ncp_Continue:	MOVE.L	A0,D0
dma_Caches:	MOVE.L	D0,-(SP)
ncp_DoWork:	MOVEQ	#0,D0
	MOVEQ	#0,D1
	BSR.B	NewCacheControl
	MOVE.L	(SP)+,D0
	RTS

Off_MMU_Way:	MOVE.L	A0,-(SP)
	MOVE.L	A4,-(SP)
	LEA	(Off_MMU_Page,PC),A4
	MOVE.L	(A1),D2
; --------------------------------------------------------------------------
MMU_Way:	MOVE.L	A5,-(SP)
	LEA	(Do_MMU_Way,PC),A5
	JSR	(_LVOSupervisor,A6)
	MOVEA.L	(SP)+,A5
	MOVEA.L	(SP)+,A4
	BRA.B	ncp_DoWork

; --------------------------------------------------------------------------
NewCacheControl:	MOVEM.L	D2-D4,-(SP)
	AND.L	D1,D0
	NOT.L	D1
	MOVEA.L	A5,A1
	LEA	(ncc_Sup,PC),A5
	JSR	(_LVOSupervisor,A6)
	MOVE.L	D3,D0
	MOVEM.L	(SP)+,D2-D4
	RTS

ncc_Sup:	ORI.W	#$0700,SR
	MOVE.L	#$80008000,D4
	MOVEC	CACR,D2
	AND.L	D4,D2
	SWAP	D2
	ROR.W	#8,D2
	ROL.L	#1,D2
	OR.L	(Base_Cache,PC),D2
	MOVE.L	D2,D3
	ROL.L	#4,D3
	OR.L	D3,D2
	BTST	#8,D2
	BEQ.B	ncc_NoCB
	BSET	#$1F,D2
ncc_NoCB:	MOVE.L	D2,D3
	AND.L	D1,D2
	OR.L	D0,D2
	MOVE.L	#$00000100,D0
	AND.L	D2,D0
	MOVE.L	D0,($0138,A5)
	TST.L	(Nest_Count,PC)
	BEQ.B	ncc_Normal
	BCLR	#8,D2
ncc_Normal:	ROR.L	#1,D2
	ROL.W	#8,D2
	SWAP	D2
	AND.L	D4,D2
ncc_NoECache:	NOT.L	D4
	CPUSHA	BC
	MOVEC	CACR,D1
	AND.L	D4,D1
	OR.L	D1,D2
	MOVEC	D2,CACR
	MOVEA.L	A1,A5
	RTE

; --------------------------------------------------------------------------
Do_MMU_Way:	MOVEA.L	D1,A5
	MOVE.L	A0,D0
	MOVE.L	D0,-(SP)
	ADD.L	(A1),D0
	BSR.B	Do_MMU_d0
	MOVE.L	(SP)+,D0
	BSR.B	Do_MMU_d0
	RTE

Do_MMU_d0:	MOVEQ	#15,D1
	AND.L	D0,D1
	BEQ.W	Do_MMU_RTS
	MOVE.L	D0,-(SP)
	BFEXTU	D0{1:$13},D0
	MOVE.L	($0030,A5),D1
dmd_Loop:	MOVEA.L	D1,A0
	MOVE.L	(A0),D1
	BEQ.W	dmd_NoFind
	CMP.L	(8,A0),D0
	BCS.B	dmd_Loop
	CMP.L	(12,A0),D0
	BHI.B	dmd_Loop
	SUB.L	(8,A0),D0
	LEA	($0010,A0),A1
	ADDA.L	D0,A1
	ADDA.L	D0,A1
	MOVE.L	(SP)+,D0
	MOVEC	URP,A0
	BFEXTU	D0{0:7},D1
	ASL.L	#2,D1
	ADDA.L	D1,A0
	MOVE.L	(A0),D1
	ANDI.L	#$FFFFFE00,D1
	MOVEA.L	D1,A0
	BFEXTU	D0{7:7},D1
	ASL.L	#2,D1
	ADDA.L	D1,A0
	MOVE.L	(A0),D1
	ANDI.L	#$FFFFFF00,D1
	MOVEA.L	D1,A0
	BFEXTU	D0{14:6},D1
	ASL.L	#2,D1
	ADDA.L	D1,A0
	MOVE.L	(A0),D1
	BTST	#0,D1
	BNE.B	dmd_skip
	BCLR	#1,D1
	BEQ.B	dmd_skip
	MOVEA.L	D1,A0
dmd_skip:	JMP	(A4)

dmd_NoFind:	MOVE.L	(SP)+,D0
Do_MMU_RTS:	RTS

Off_MMU_Page:	MOVE.W	(A1),D0
	ADDQ.W	#1,(A1)
	TST.W	D0
	BNE.B	Do_MMU_RTS
	ADDQ.L	#3,A0
	CPUSHA	DC
	PFLUSHA		;MC68040
	BCLR	#5,(A0)
	CPUSHL	DC,(A0)
	RTS

On_MMU_Page:	SUBQ.W	#1,(A1)
	MOVE.W	(A1),D0
	BNE.B	Do_MMU_RTS
	ADDQ.L	#3,A0
	PFLUSHA		;MC68040
	BSET	#5,(A0)
	CPUSHL	DC,(A0)
	RTS

OldAddLibrary:	dc.l	0
OldCloseLibrary:	dc.l	0
OldAddDevice:	dc.l	0
OldAddResource:	dc.l	0
OldAddTask:	dc.l	0
OldAddIntServer:	dc.l	0
OldSupervisor:	dc.l	0
OldSetIntVector:	dc.l	0
OldBeginIO:	dc.l	0
Base_Cache:	dc.l	0
Nest_Count:	dc.l	0
; --------------------------------------------------------------------------
MMUFrame:	dc.l	0
InputName:	dc.b	'input.device',0,0
	dcb.b	2,0








; --------------------------------------------------------------------------
Install_Caches:	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVEA.L	A6,A2
	MOVEA.L	(4).W,A6
	LEA	(Install_Caches_Doit,PC),A5
	JSR	(-$001E,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

Install_Caches_Doit:
	MOVEC	CACR,D0
	ORI.L	#$20000000,D0
	MOVEC	D0,CACR
	NOP
	CINVA	BC
	MOVEC	CACR,D0
	NOP
	ORI.L	#$00400000,D0
	MOVEC	D0,CACR
	NOP
	ANDI.L	#$FFBFFFFF,D0
	ORI.L	#$00800000,D0
	MOVEC	D0,CACR
	NOP
	dc.w	$4E7A,$0808

;fiX Bad code terminator
	NOP
	ORI.L	#1,D0
	dc.w	$4E7B,$0808

;fiX Bad code terminator
	NOP
	RTE




; --------------------------------------------------------------------------
Install_Dispatcher:	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVEA.L	(4).W,A6
	JSR	(_LVODisable,A6)

	MOVE.W	(AttnFlags,A6),D0
	ANDI.W	#(AFF_68881|AFF_68882|AFF_FPU40),D0
	BEQ.W	Install_Dispatcher_Quit
	BSET	#AFB_FPU40+1,(AttnFlags,A6)
	BNE.W	Install_Dispatcher_Quit

	LEA	(go_supervisor,PC),A0
	LEA	(patchcode,PC),A1
	MOVE.L	A0,(A1)

	JSR	(_LVOCacheClearU,A6)

	LEA	(SWITCH060_FPU,PC),A0
	MOVE.L	A0,D0
	MOVEA.L	A6,A1
	MOVEA.W	#_LVOexecPrivate4,A0
	JSR	(_LVOSetFunction,A6)

	LEA	(DISPATCH060_FPU,PC),A0
	MOVE.L	A0,(ex_LaunchPoint,A6)

	LEA	(GetVBR,PC),A5
	JSR	(_LVOSupervisor,A6)
	MOVEA.L	D0,A2
	TST.L	D0
	BNE.B	.vbrmoved

	MOVE.L	#$00000400,D0
	MOVE.L	#1,D1
	JSR	(_LVOAllocMem,A6)
	MOVEA.L	D0,A2
	TST.L	D0
	BEQ.B	.vbrmoved

	SUBA.L	A0,A0
	MOVEA.L	D0,A1
	MOVE.W	#$00FF,D0
.copyvbr:	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.copyvbr

.vbrmoved:	LEA	(Install_Tasks,PC),A5
	JSR	(_LVOSupervisor,A6)
Install_Dispatcher_Quit:
	JSR	(_LVOEnable,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; --------------------------------
GetVBR:	MOVEC	VBR,D0
	RTE

; ------------------------------------
Install_Tasks:	MOVE.W	#$2700,SR
	MOVE.L	A2,D0
	BEQ.B	notVBR
	MOVEC	D0,VBR
notVBR:	CINVA	DC
	LEA	(TaskReady,A6),A3
Install_ReadyTasks_Loop:
	MOVEA.L	(A3),A3
	TST.L	(0,A3)
	BEQ.B	Install_WaitingTasks
	BSR.B	ConvertStackFrames
	BRA.B	Install_ReadyTasks_Loop

Install_WaitingTasks:
	LEA	(TaskWait,A6),A3
Install_WaitingTasks_Loop:
	MOVEA.L	(A3),A3
	TST.L	(0,A3)
	BEQ.B	Install_Tasks_End
	BSR.B	ConvertStackFrames
	BRA.B	Install_WaitingTasks_Loop

Install_Tasks_End:	RTE

; ----------------------------------
ConvertStackFrames:	MOVEA.L	(pr_Task+TC_SPREG,A3),A5
	MOVEQ	#0,D0
	MOVE.W	(4,A5),D0
	CLR.L	-(A5)
	CLR.L	-(A5)
	CLR.L	-(A5)
	MOVE.L	A5,(pr_Task+TC_SPREG,A3)
	MOVEQ	#0,D0
	MOVE.W	($0010,A5),D0
	RTS

;fiX Label expected
	NOP
; ---------------------------------------
SWITCH060_FPU:	MOVE.W	#$2000,SR
	MOVE.L	A5,-(SP)
	MOVE.L	USP,A5
	MOVEM.L	D0-D7/A0-A6,-(A5)
	MOVEA.L	(4).W,A6
	MOVE.W	(IDNestCnt,A6),D0
	MOVE.W	#$FFFF,(IDNestCnt,A6)
	MOVE.W	#$C000,(_custom+intena).L
	MOVE.L	(SP)+,($0034,A5)
	MOVE.W	(SP)+,-(A5)
	MOVE.L	(SP)+,-(A5)
	ADDQ.W	#2,SP
	FSAVE	-(A5)
	TST.B	(2,A5)
	BEQ.B	.SWITCH_FPU_NullFrame
	MOVEQ	#-1,D2
	FMOVEM.X	FP0/FP1/FP2/FP3/FP4/FP5/FP6/FP7,-(A5)
	FMOVE.L	FPIAR,-(A5)
	FMOVE.L	FPSR,-(A5)
	FMOVE.L	FPCR,-(A5)
	MOVE.L	D2,-(A5)
.SWITCH_FPU_NullFrame:
	MOVEA.L	(ex_LaunchPoint,A6),A4
	MOVEA.L	(ThisTask,A6),A3
	MOVE.W	D0,(pr_Task+TC_IDNESTCNT,A3)
	MOVE.L	A5,(pr_Task+TC_SPREG,A3)
	BTST	#TB_SWITCH,(pr_Task+TC_FLAGS,A3)
	BEQ.B	.nocustomswitch
	MOVEA.L	(pr_Task+TC_SWITCH,A3),A5
	JSR	(A5)
.nocustomswitch:	LEA	(TaskReady,A6),A0

.taskloop:	MOVE.W	#$2700,SR
	MOVEA.L	(pr_Task,A0),A3
	MOVE.L	(pr_Task,A3),D0
	BNE.B	.taskendloop
	ADDQ.L	#1,(IdleCount,A6)
	BSET	#7,(SysFlags,A6)
	STOP	#$2000
;fiX Label expected
	BRA.B	.taskloop

.taskendloop:	MOVE.L	D0,(pr_Task,A0)
	MOVEA.L	D0,A1
	MOVE.L	A0,(pr_Task+LN_PRED,A1)
	MOVE.L	A3,(ThisTask,A6)

	MOVE.W	(Quantum,A6),(Elapsed,A6)
	BCLR	#6,(SysFlags,A6)
	MOVE.B	#TS_RUN,(pr_Task+TC_STATE,A3)
	MOVE.W	(pr_Task+TC_IDNESTCNT,A3),(IDNestCnt,A6)
	TST.B	(IDNestCnt,A6)
	BMI.B	.idnest3
	MOVE.W	#$4000,(_custom+intena).L
.idnest3:	MOVE.W	#$2000,SR
	ADDQ.L	#1,(DispCount,A6)
	MOVE.B	(pr_Task+TC_FLAGS,A3),D0
	ANDI.B	#(TF_EXCEPT|TF_LAUNCH),D0
	BEQ.B	.conttask
	BSR.B	.launchnewtask
.conttask:	MOVEA.L	(SysStkUpper,A3),A5
	JMP	(A4)

;fiX Label expected
	NOP
.launchnewtask:	BTST	#TB_LAUNCH,D0
	BEQ.B	.launch
	MOVE.B	D0,D2
	MOVEA.L	(pr_Task+TC_LAUNCH,A3),A5
	JSR	(A5)
	MOVE.B	D2,D0
.launch:	BTST	#TB_EXCEPT,D0
	BNE.B	.Exception
.diskout:	RTS

.Exception:	BCLR	#TB_EXCEPT,(pr_Task+TC_FLAGS,A3)
	MOVE.L	(pr_Task+TC_EXCEPTCODE,A3),D1
	BEQ.B	.diskout
	MOVE.W	#$4000,(_custom+intena).L
	ADDQ.B	#1,(IDNestCnt,A6)
	MOVE.L	(pr_Task+TC_SIGRECVD,A3),D0
	AND.L	(pr_Task+TC_SIGEXCEPT,A3),D0
	EOR.L	D0,(pr_Task+TC_SIGEXCEPT,A3)
	EOR.L	D0,(pr_Task+TC_SIGRECVD,A3)
	SUBQ.B	#1,(IDNestCnt,A6)
	BGE.B	.idnest
	MOVE.W	#$C000,(_custom+intena).L
.idnest:	MOVEA.L	(pr_Task+TC_SPREG,A3),A1
	MOVE.L	(pr_Task+TC_FLAGS,A3),-(A1)
	TST.B	(IDNestCnt,A6)
	BNE.B	.idcont2
	SUBQ.B	#1,(IDNestCnt,A6)
	BGE.B	.idcont2
	MOVE.W	#$C000,(_custom+intena).L
.idcont2:	MOVE.L	#0,-(A1)
patchcode:	EQU	*-4
	MOVE.L	A1,USP
	BTST	#0,(AttnFlags+1,A6)
	BEQ.B	nofpu
	MOVE.W	#$0020,-(SP)
nofpu:	MOVE.L	D1,-(SP)
	CLR.W	-(SP)
	MOVEA.L	(pr_Task+TC_EXCEPTDATA,A3),A1
	RTE

; --------------------------------------
go_supervisor:	MOVEA.L	(4).W,A6
	LEA	(.supercode,PC),A5
	JMP	(_LVOSupervisor,A6)

;fiX Label expected
	NOP
	NOP
.supercode:	MOVEA.L	(ex_LaunchPoint,A6),A4
	BTST	#0,(AttnFlags+1,A6)
	BEQ.B	.fpuused
	ADDQ.L	#2,SP
.fpuused:	ADDQ.L	#6,SP
	MOVEA.L	(ThisTask,A6),A3
	OR.L	D0,(pr_Task+TC_SIGEXCEPT,A3)
	MOVE.L	USP,A1
	MOVE.L	(A1)+,(pr_Task+TC_FLAGS,A3)
	MOVE.L	A1,(pr_Task+TC_SPREG,A3)
	MOVE.W	(pr_Task+TC_IDNESTCNT,A3),(IDNestCnt,A6)
	TST.B	(IDNestCnt,A6)
	BMI.B	.end
	MOVE.W	#$4000,(_custom+intena).L
.end:	RTS

; --------------------------------------------------------------------
DISPATCH060_FPU:	MOVEQ	#$20,D1
	TST.B	(2,A5)
	BEQ.B	.DISPATCH060_FPU_NullFrame
	ADDQ.L	#4,A5
	FMOVE.L	(A5)+,FPCR
	FMOVE.L	(A5)+,FPSR
	FMOVE.L	(A5)+,FPIAR
	FMOVEM.X	(A5)+,FP0/FP1/FP2/FP3/FP4/FP5/FP6/FP7
.DISPATCH060_FPU_NullFrame:
	FRESTORE	(A5)+
	LEA	($0042,A5),A2
	MOVE.L	A2,USP
	MOVE.W	D1,-(SP)
	MOVE.L	(A5)+,-(SP)
	MOVE.W	(A5)+,-(SP)
	MOVEM.L	(A5),D0-D7/A0-A6
	RTE

;fiX Label expected
	NOP
Install_Dispatcher_End:
	dc.l	$290D7AB8,$7E880EBD

;fiX Bad code terminator
; --------------------------------------------------------------------------
_FlushMMU:	MOVEM.L	A5/A6,-(SP)
	LEA	(FlushMMU_Trap,PC),A5
	MOVEA.L	(LowMemChkSum,A6),A6
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,A5/A6
	RTS

FlushMMU_Trap:	CPUSHL	DC,(A0)
	LEA	($0010,A0),A0
	CPUSHL	DC,(A0)
	PFLUSHA		;MC68040
	RTE

;fiX Label expected
; --------------------------------------------------------------------------
	dc.w	0

_kputch:	MOVE.L	(4,SP),D0
KPutChar:	MOVE.L	A6,-(SP)
	MOVEA.L	(SysBase).L,A6
	JSR	(_LVOexecPrivate9,A6)
	MOVEA.L	(SP)+,A6
	RTS

_KPutS:	MOVEA.L	(4,SP),A0
KPutStr:	MOVE.B	(A0)+,D0
	BEQ.B	ps1
	BSR.B	KPutChar
	BRA.B	KPutStr

ps1:	RTS

KGetChar:	BSR.B	KMayGetChar
	TST.L	D0
	BMI.B	KGetChar
	RTS

KMayGetChar:	MOVE.L	A6,-(SP)
	MOVEA.L	(SysBase).L,A6
	JSR	(_LVOexecPrivate8,A6)
	MOVEA.L	(SP)+,A6
	RTS

_KPutFmt:	MOVEA.L	(4,SP),A0
	MOVEA.L	(8,SP),A1
	BRA.B	KPrintF

_kprintf:	MOVEA.L	(4,SP),A0
	LEA	(8,SP),A1
KPrintF:	MOVEM.L	A2,-(SP)
	LEA	(KPutChar,PC),A2
	BSR.B	KDoFmt
	MOVEM.L	(SP)+,A2
	RTS

KDoFmt:	MOVE.L	A6,-(SP)
	MOVEA.L	(SysBase).L,A6
	JSR	(_LVORawDoFmt,A6)
	MOVEA.L	(SP)+,A6
	RTS

_KDoFmt:	MOVEM.L	A2/A3,-(SP)
	MOVEM.L	(12,SP),A0-A3
	BSR.B	KDoFmt
	MOVEM.L	(SP)+,A2/A3
	RTS

RomTagEnd:




	SECTION	68060library_newrs017D1C,CODE
; --------------------------------------------------------------------------
_AllocPatchPage:	MOVEM.L	D7/A4-A6,-(SP)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	D7,D0
	ADDI.L	#$00000FFF,D0
	MOVEQ	#1,D1
	MOVEA.L	(4).W,A6
	JSR	(_LVOAllocMem,A6)
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	BEQ.B	.nomem
	MOVE.L	D7,D0
	ADDI.L	#$00000FFF,D0
	MOVEA.L	A4,A1
	JSR	(_LVOFreeMem,A6)

	MOVE.L	A4,D0
	ADDI.L	#$00000FFF,D0
	ANDI.W	#$F000,D0
	MOVEA.L	D0,A1
	MOVE.L	D7,D0
	JSR	(_LVOAllocAbs,A6)
	MOVEA.L	D0,A4
	ADD.L	D7,($003C,A5)
.nomem:	MOVE.L	A4,D0
	MOVEM.L	(SP)+,D7/A4-A6
	RTS

; -----------------------------------------------------------------------------
_SetupRootPage:	MOVEM.L	D2/D5-D7/A4-A6,-(SP)
	MOVE.L	D1,D6	;d6=512-1
	MOVE.L	D0,D7	;d7=$200
	MOVEA.L	A0,A5	;a5=mmuframe

	MOVE.L	($0048,A5),D0
	CMP.L	D7,D0
	BCS.B	.alreadydone

	MOVEA.L	($0044,A5),A4
	MOVE.L	A4,D1
	ADD.L	D7,D1
	ADD.L	D6,D1

	MOVE.L	D6,D2
	NOT.L	D2
	AND.L	D2,D1
	MOVE.L	D1,($0044,A5)

	MOVE.L	A4,D0
	SUB.L	D0,D1
	MOVE.L	D1,D5
	SUB.L	D5,($0048,A5)

	MOVE.L	D5,D0
	SUB.L	D7,D0
	ADD.L	D0,($0040,A5)
	BRA.B	.end

.alreadydone:	MOVEA.L	(4).W,A6
	JSR	(_LVOForbid,A6)

	MOVE.L	D7,D0
	ADDI.L	#$00001000,D0
	MOVEQ	#1,D1
	JSR	(_LVOAllocMem,A6)
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	BEQ.B	.nomem

	MOVE.L	D7,D0
	ADDI.L	#$00001000,D0
	MOVEA.L	A4,A1
	JSR	(_LVOFreeMem,A6)

	MOVE.L	A4,D0
	ADDI.L	#$00000FFF,D0
	ANDI.W	#$F000,D0
	MOVEA.L	D0,A1
	MOVEQ	#$40,D0
	LSL.L	#6,D0
	JSR	(_LVOAllocAbs,A6)
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	ADD.L	D7,D0
	ADD.L	D6,D0

	MOVE.L	D6,D1
	NOT.L	D1
	AND.L	D1,D0
	MOVE.L	D0,($0044,A5)

	MOVE.L	A4,D1
	SUB.L	D1,D0
	MOVEQ	#$40,D1
	LSL.L	#6,D1
	MOVE.L	D1,D2
	SUB.L	D0,D2
	MOVE.L	D2,($0048,A5)

	ADDI.L	#$00001000,($003C,A5)
	BRA.B	.normend

.nomem:	CLR.L	($0044,A5)
	CLR.L	($0048,A5)
.normend:	JSR	(_LVOPermit,A6)
.end:	MOVE.L	A4,D0
	MOVEM.L	(SP)+,D2/D5-D7/A4-A6
	RTS

; -----------------------------------------------------------------------------
_SetMMUPageMode:	SUBA.W	#$001C,SP	;a0=mmuframe,d0=wo,d1=len,(sp)=mode

	MOVEM.L	D2/D3/D5-D7/A3-A5,-(SP)
	MOVE.L	($0040,SP),D5
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5

	CLR.W	($0038,SP)
	MOVEQ	#-1,D0
	CMP.L	($004C,A5),D0
	BNE.B	.case1
	MOVE.L	D7,D0
	ANDI.W	#$F000,D0
	MOVE.L	D0,($004C,A5)
	MOVE.L	D5,D1
	MOVE.L	D1,($0050,A5)
	BRA.B	.case2

.case1:	MOVE.L	D7,D0
	ANDI.W	#$F000,D0
	CMP.L	($004C,A5),D0
	BNE.B	.case2
	MOVE.L	($0050,A5),D0
	CMP.L	D5,D0
	BNE.B	.case2
	MOVE.L	A5,D0
	BRA.W	.end

.case2:	MOVE.L	D7,D0
	ANDI.W	#$F000,D0
	MOVE.L	D0,($004C,A5)
	MOVE.L	D5,($0050,A5)
	BSET	#0,D5
	MOVE.L	A5,D0
	BEQ.W	.loop3out
	MOVE.L	D7,D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	MOVE.L	D7,D1
	ADD.L	D6,D1
	SUBQ.L	#1,D1
	LSR.L	#8,D1
	LSR.L	#4,D1
	MOVE.L	D0,($0034,SP)
	MOVE.L	D1,($0030,SP)
	CMP.L	D1,D0
	BLS.B	.loop3
	MOVE.W	#1,($0038,SP)

.loop3:	MOVE.L	($0034,SP),D0
	CMP.L	($0030,SP),D0
	BHI.W	.loop3out
	CLR.W	($0038,SP)
	MOVE.L	D0,D1
	LSR.L	#8,D1
	LSR.L	#5,D1
	MOVE.L	D0,D2
	LSR.L	#6,D2
	MOVEQ	#$7F,D3
	AND.L	D3,D2
	MOVEQ	#$3F,D3
	AND.L	D3,D0
	MOVEA.L	(12,A5),A0
	LEA	(A0,D1.L*4),A1
	MOVE.L	D0,($0024,SP)
	MOVE.L	D1,($002C,SP)
	MOVE.L	D2,($0028,SP)
	MOVE.L	(A1),D0
	CMP.L	($0024,A5),D0
	BNE.B	.isnot

	MOVEA.L	A5,A0
	MOVEQ	#$40,D0
	LSL.L	#3,D0
	MOVE.L	#$000001FF,D1
	BSR.W	_SetupRootPage
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	BEQ.B	.isnot

	MOVE.L	($002C,SP),D0
	MOVEA.L	(12,A5),A0
	LEA	(A0,D0.L*4),A1
	MOVE.L	A4,D0
	ORI.W	#3,D0
	MOVE.L	D0,(A1)
	CLR.L	($0020,SP)

.loop:	MOVE.L	($0020,SP),D0
	MOVEQ	#$40,D1
	ADD.L	D1,D1
	CMP.L	D1,D0
	BCC.B	.loopout
	MOVE.L	($0028,A5),(A4,D0.L*4)
	ADDQ.L	#1,($0020,SP)
	BRA.B	.loop

.loopout:	PEA	($60).W
	MOVE.L	A4,D0
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#3,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A5
	ADDQ.W	#4,SP
.isnot:	MOVE.L	($002C,SP),D0
	MOVEA.L	(12,A5),A0
	LEA	(A0,D0.L*4),A1
	MOVE.L	(A1),D0
	MOVE.L	($0024,A5),D1
	CMP.L	D0,D1
	BEQ.W	.loopcont
	ANDI.W	#$FE00,D0
	MOVEA.L	D0,A4
	MOVE.L	($0028,SP),D0
	MOVE.L	(A4,D0.L*4),D0
	CMP.L	($0028,A5),D0
	BNE.B	.noframe

	MOVEA.L	A5,A0
	MOVEQ	#$40,D0
	LSL.L	#2,D0
	MOVE.L	#$000001FF,D1
	BSR.W	_SetupRootPage
	MOVEA.L	D0,A3

	MOVE.L	A3,D0
	BEQ.B	.noframe
	MOVE.L	A3,D0
	ORI.W	#3,D0
	MOVE.L	($0028,SP),D1
	MOVE.L	D0,(A4,D1.L*4)
	CLR.L	($0020,SP)
.loop2:	MOVE.L	($0020,SP),D0
	MOVEQ	#$40,D1
	CMP.L	D1,D0
	BCC.B	.loopout2
	MOVE.L	($002C,A5),(A3,D0.L*4)
	ADDQ.L	#1,($0020,SP)
	BRA.B	.loop2

.loopout2:	PEA	($60).W
	MOVE.L	A3,D0
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#2,D1
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A5
	ADDQ.W	#4,SP

.noframe:	MOVE.L	($0028,SP),D0
	MOVE.L	(A4,D0.L*4),D0
	MOVE.L	($0028,A5),D1
	CMP.L	D0,D1
	BEQ.B	.loopcont
	ANDI.W	#$FE00,D0
	MOVEA.L	D0,A3
	MOVE.L	($0024,SP),D0
	MOVE.L	(A3,D0.L*4),D0
	CMP.L	($002C,A5),D0
	BNE.B	.skipit

	MOVE.L	($0034,SP),D0
	MOVE.L	D0,D1
	ASL.L	#8,D1
	ASL.L	#4,D1
	MOVE.L	($0024,SP),D2
	MOVE.L	D1,(A3,D2.L*4)

.skipit:	MOVEQ	#$60,D0
	MOVE.L	($0024,SP),D1
	AND.L	(A3,D1.L*4),D0
	MOVEQ	#$20,D1
	CMP.L	D1,D0
	BHI.B	.ishigher
	MOVE.L	($0024,SP),D0
	MOVE.L	(A3,D0.L*4),D0
	OR.L	D5,D0
	MOVE.L	($0024,SP),D1
	MOVE.L	D0,(A3,D1.L*4)
.ishigher:	TST.L	D7
	BNE.B	.setit
	MOVE.L	A3,($0020,A5)
.setit:	MOVE.W	#1,($0038,SP)
.loopcont:	ADDQ.L	#1,($0034,SP)
	BRA.W	.loop3

.loop3out:	TST.W	($0038,SP)
	BNE.B	.allout
	SUBA.L	A5,A5

.allout:	MOVE.L	A5,D0
.end:	MOVEM.L	(SP)+,D2/D3/D5-D7/A3-A5
	ADDA.W	#$001C,SP
	RTS

; -----------------------------------------------------------------------------
_AllocMMUPages:	MOVEM.L	D5-D7/A4-A6,-(SP)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5

	MOVE.L	A5,D0
	BEQ.B	.addedpages

	MOVE.L	D7,D0
	ANDI.W	#$F000,D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	MOVE.L	D0,D7

	MOVE.L	D6,D0
	ADDI.L	#$00000FFE,D0
	ANDI.W	#$F000,D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	MOVE.L	D0,D6

	MOVE.L	D6,D0
	SUB.L	D7,D0
	MOVE.L	D0,D5

	ADDQ.L	#1,D5

	MOVE.L	D5,D0
	ADD.L	D0,D0

	MOVEQ	#16,D1

	ADD.L	D1,D0
	MOVE.L	#(MEMF_PUBLIC|MEMF_CLEAR),D1
	MOVEA.L	(4).W,A6
	JSR	(_LVOAllocVec,A6)
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	BEQ.B	.nomem
	MOVE.L	D7,(8,A4)
	MOVE.L	D6,(12,A4)
	LEA	($0030,A5),A0
	MOVEA.L	A4,A1
	JSR	(_LVOAddTail,A6)
	BRA.B	.addedpages

.nomem:	SUBA.L	A5,A5
.addedpages:	MOVE.L	A5,D0
	MOVEM.L	(SP)+,D5-D7/A4-A6
	RTS

; --------------------------------------------------------------------------
__SetRomAddress:	MOVEM.L	D6/D7/A3-A6,-(SP)
	MOVE.L	A0,D7
	MOVEA.L	A6,A5

	CLR.L	-(SP)
	MOVEA.L	($0034,A5),A0
	MOVE.L	#$00F80000,D0
	MOVEQ	#8,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A3

	ADDQ.W	#4,SP
	MOVE.L	A3,D0
	BEQ.B	.stdrom

	CMPI.L	#$00F80000,D7
	BEQ.B	.stdrom

	MOVEQ	#$7C,D6
	LSL.L	#5,D6
	MOVEA.L	(4).W,A6
	JSR	(_LVODisable,A6)

.loop:	CMPI.L	#$00000FFF,D6
	BHI.B	.loopend
	MOVE.L	D6,D0
	LSR.L	#8,D0
	LSR.L	#5,D0
	MOVEA.L	(12,A3),A0
	LEA	(A0,D0.L*4),A1
	MOVE.L	(A1),D0
	ANDI.W	#$FE00,D0
	MOVEA.L	D0,A4
	MOVE.L	D6,D0
	LSR.L	#6,D0
	MOVEQ	#$7F,D1
	AND.L	D1,D0
	MOVE.L	(A4,D0.L*4),D1
	ANDI.W	#$FE00,D1
	MOVEA.L	D1,A4
	MOVE.L	D6,D0
	MOVEQ	#$3F,D1
	AND.L	D1,D0
	MOVE.L	D7,D1
	ORI.W	#1,D1
	MOVE.L	D1,(A4,D0.L*4)
	ADDQ.L	#1,D6
	ADDI.L	#$00001000,D7
	BRA.B	.loop

.loopend:	MOVEA.L	(4).W,A6
	JSR	(_LVOEnable,A6)

.stdrom:	MOVE.L	A3,D0
	MOVEM.L	(SP)+,D6/D7/A3-A6
	RTS

; --------------------------------------------------------------------------
@Map_PatchArea:	MOVEM.L	D6/D7/A3-A5,-(SP)
	MOVEA.L	A1,A4
	MOVEA.L	A0,A5
	MOVEA.L	A4,A0
	MOVE.L	#$00008000,D0
	BSR.W	_AllocPatchPage

	MOVE.L	D0,D6
	TST.L	D6
	BEQ.B	.endloop
	MOVE.L	D6,($006E,A5)

	CLR.L	-(SP)
	MOVEA.L	A4,A0
	MOVE.L	#$FFFF8000,D0
	MOVE.L	#$00008000,D1
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A4

	ADDQ.W	#4,SP
	MOVE.L	A4,D0
	BEQ.B	.endloop

	MOVE.L	#$000FFFF8,D7

.loop:	CMPI.L	#$00100000,D7
	BEQ.B	.endloop
	MOVE.L	D7,D0
	LSR.L	#8,D0
	LSR.L	#5,D0
	MOVEA.L	(12,A4),A0
	LEA	(A0,D0.L*4),A1
	MOVE.L	(A1),D0
	ANDI.W	#$FE00,D0
	MOVEA.L	D0,A3
	MOVE.L	D7,D0
	LSR.L	#6,D0
	MOVEQ	#$7F,D1
	AND.L	D1,D0
	MOVE.L	(A3,D0.L*4),D1
	ANDI.W	#$FE00,D1
	MOVEA.L	D1,A3
	MOVE.L	D7,D0
	MOVEQ	#$3F,D1
	AND.L	D1,D0
	MOVE.L	D6,D1
	ORI.W	#$0020,D1
	ORI.W	#1,D1
	MOVE.L	D1,(A3,D0.L*4)
	ADDQ.L	#1,D7
	ADDI.L	#$00001000,D6
	BRA.B	.loop

.endloop:	MOVE.L	A4,D0
	MOVEM.L	(SP)+,D6/D7/A3-A5
	RTS

; -----------------------------------------------------------------------------
_SetupMMUFrame:	MOVEM.L	D6/D7/A5/A6,-(SP)

	MOVEQ	#0,D6	;rc

	MOVEQ	#$54,D0	;alloc MMUFrame
	MOVE.L	#(MEMF_PUBLIC|MEMF_CLEAR),D1
	MOVEA.L	(4).W,A6
	JSR	(_LVOAllocVec,A6)
	MOVEA.L	D0,A5

	MOVE.L	A5,D0
	BEQ.W	.nomem

	LEA	($0030,A5),A0
	MOVE.L	A0,($0038,A5)	;newlist LIST MMUSegMents
	CLR.L	($0034,A5)
	LEA	($0034,A5),A0
	MOVE.L	A0,($0030,A5)

	CLR.L	($003C,A5)
	CLR.L	($0040,A5)
	CLR.L	($0044,A5)
	CLR.L	($0048,A5)
	MOVEQ	#-1,D0
	MOVE.L	D0,($004C,A5)
	CLR.L	($0050,A5)

	MOVEA.L	A5,A0	;a0=mmuframe
	MOVEQ	#$40,D0	;40 << 3 = $200
	LSL.L	#3,D0
	MOVE.L	#$000001FF,D1	;d1=512-1
	BSR.W	_SetupRootPage
	MOVE.L	D0,(12,A5)

	MOVEA.L	A5,A0
	MOVEQ	#$40,D0	;d0=$200
	LSL.L	#3,D0
	MOVE.L	#$000001FF,D1
	BSR.W	_SetupRootPage
	MOVE.L	D0,($0010,A5)

	MOVEA.L	A5,A0
	MOVEQ	#$40,D0	;d0=$100
	LSL.L	#2,D0
	MOVE.L	#$000001FF,D1
	BSR.W	_SetupRootPage
	MOVE.L	D0,($0014,A5)

	MOVEA.L	A5,A0
	MOVEQ	#$40,D0	;d0=40<<6=$1000
	LSL.L	#6,D0
	MOVE.L	#$00000FFF,D1
	BSR.W	_SetupRootPage
	MOVE.L	D0,($001C,A5)

	TST.L	(12,A5)
	BEQ.W	.nomem
	TST.L	($0010,A5)
	BEQ.W	.nomem
	TST.L	($0014,A5)
	BEQ.W	.nomem
	TST.L	D0
	BEQ.W	.nomem

	ORI.W	#$0040,D0
	ORI.W	#1,D0
	MOVE.L	D0,($0018,A5)

	LEA	($0018,A5),A0
	MOVE.L	A0,D0
	ORI.W	#2,D0
	MOVE.L	D0,($002C,A5)

	MOVE.L	($0014,A5),D0
	ORI.W	#3,D0
	MOVE.L	D0,($0028,A5)

	MOVE.L	($0010,A5),D0
	ORI.W	#3,D0
	MOVE.L	D0,($0024,A5)

	MOVEQ	#0,D7
.loop0:	MOVEQ	#64,D0
	CMP.L	D0,D7
	BCC.B	.endloop
	MOVEA.L	($0014,A5),A0
	LEA	(A0,D7.L*4),A1
	MOVE.L	($002C,A5),(A1)
	ADDQ.L	#1,D7
	BRA.B	.loop0

.endloop:	MOVEQ	#0,D7
.loop:	MOVEQ	#64,D0
	ADD.L	D0,D0
	CMP.L	D0,D7
	BCC.B	.loopstart2
	MOVEA.L	($0010,A5),A0
	LEA	(A0,D7.L*4),A1
	MOVE.L	($0028,A5),(A1)
	ADDQ.L	#1,D7
	BRA.B	.loop

.loopstart2:	MOVEQ	#0,D7
.loop2:	MOVEQ	#64,D0
	ADD.L	D0,D0
	CMP.L	D0,D7
	BCC.B	.endloop2
	MOVEA.L	(12,A5),A0
	LEA	(A0,D7.L*4),A1
	MOVE.L	($0024,A5),(A1)
	ADDQ.L	#1,D7
	BRA.B	.loop2

.endloop2:	MOVE.L	#$00008008,(8,A5)
	MOVE.L	(12,A5),D0
	MOVE.L	D0,(A5)
	MOVE.L	(12,A5),D0
	MOVE.L	D0,(4,A5)
	MOVEQ	#1,D6
	MOVE.L	(12,A5),D0

	PEA	($60).W
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#3,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A5
	MOVE.L	($0010,A5),D0
	PEA	($60).W
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#3,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A5
	MOVE.L	($0014,A5),D0
	PEA	($60).W
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#2,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A5
	MOVE.L	($001C,A5),D0
	PEA	($60).W
	MOVEA.L	A5,A0
	MOVEQ	#$40,D1
	LSL.L	#6,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A5
	LEA	($0010,SP),SP
.nomem:	TST.W	D6
	BNE.B	.nofail
	SUBA.L	A5,A5
.nofail:	MOVE.L	A5,D0
	MOVEM.L	(SP)+,D6/D7/A5/A6
	RTS

; --------------------------------------------------------------------------
__SetIllegalPageValue:
	MOVEM.L	D5-D7/A2/A5/A6,-(SP)
	MOVE.L	D0,D7
	MOVEA.L	A6,A5

	MOVEA.L	($0034,A5),A0
	MOVEA.L	($001C,A0),A1
	MOVE.L	(A1),D5
	MOVEQ	#0,D6

.loop:	CMPI.L	#$00000400,D6
	BGE.B	.loopend

	MOVEA.L	($0034,A5),A0
	MOVEA.L	($001C,A0),A1
	LEA	(A1,D6.L*4),A2
	MOVE.L	D7,(A2)
	ADDQ.L	#1,D6
	BRA.B	.loop

.loopend:	MOVE.L	D5,D0
	MOVEM.L	(SP)+,D5-D7/A2/A5/A6
	RTS

; --------------------------------------------------------------------------
__GetIllegalPage:	MOVEM.L	A5/A6,-(SP)
	MOVEA.L	A6,A5
	MOVEA.L	($0034,A5),A0
	MOVEA.L	($001C,A0),A1
	MOVE.L	A1,D0
	MOVEM.L	(SP)+,A5/A6
	RTS

; --------------------------------------------------------------------------
__SetIllegalPageMode:
	MOVEM.L	D6/D7/A5/A6,-(SP)
	MOVE.L	D0,D7
	MOVEA.L	A6,A5

	MOVEA.L	($0034,A5),A0
	MOVE.L	($0018,A0),D6
	TST.W	D7
	BEQ.B	.false

	MOVE.L	D6,D0
	ANDI.W	#$FFFC,D0
	MOVE.L	D0,($0018,A0)
	BRA.B	.doit

.false:	MOVE.L	D6,D0
	ANDI.W	#$FFFC,D0
	ORI.W	#1,D0
	MOVE.L	D0,($0018,A0)

.doit:	MOVEA.L	($0034,A5),A0
	LEA	($0018,A0),A1
	MOVEA.L	A1,A0
	MOVEA.L	A5,A6
	JSR	(-$0042,A6)
	MOVE.L	D6,D0
	MOVEM.L	(SP)+,D6/D7/A5/A6
	RTS

; --------------------------------------------------------------------------
__SetZeroPageMode:	MOVEM.L	D6/D7/A5/A6,-(SP)
	MOVE.L	D0,D7
	MOVEA.L	A6,A5

	MOVEA.L	($0034,A5),A0
	MOVEA.L	($0020,A0),A1
	MOVE.L	(A1),D6
	MOVE.L	D7,D0
	TST.L	D0
	BEQ.B	.case0
	SUBQ.L	#1,D0
	BEQ.B	.case1
	SUBQ.L	#1,D0
	BEQ.B	.case3
	BRA.B	.default

.case0:	MOVEA.L	($0034,A5),A0
	MOVEA.L	($0020,A0),A1
	MOVEQ	#$41,D0
	MOVE.L	D0,(A1)
	BRA.B	.default

.case1:	MOVEA.L	($0034,A5),A0
	MOVEA.L	($0020,A0),A1
	MOVE.L	($0018,A0),D0
	ANDI.W	#$FFFC,D0
	ORI.W	#$0040,D0
	MOVE.L	D0,(A1)
	BRA.B	.default

.case3:	MOVEA.L	($0034,A5),A0
	MOVEA.L	($0020,A0),A1
	MOVE.L	($0018,A0),D0
	ANDI.W	#$FFFC,D0
	ORI.W	#1,D0
	ORI.W	#$0040,D0
	MOVE.L	D0,(A1)

.default:	MOVEA.L	($0034,A5),A0
	MOVEA.L	($0020,A0),A1
	MOVEA.L	A1,A0
	MOVEA.L	A5,A6
	JSR	(-$0042,A6)
	MOVE.L	D6,D0
	MOVEM.L	(SP)+,D6/D7/A5/A6
	RTS

; --------------------------------------------------------------------------
__SetPageProtectMode:
	SUBA.W	#$0018,SP
	MOVEM.L	D2-D7/A2/A4-A6,-(SP)
	MOVE.L	D1,D5
	MOVE.L	D0,D6
	MOVE.L	A1,D7
	MOVEA.L	A6,A5

	MOVE.L	D7,D0
	LSR.L	#8,D0
	LSR.L	#4,D0

	MOVE.L	D7,D1
	ADD.L	D6,D1
	SUBQ.L	#1,D1
	LSR.L	#8,D1
	LSR.L	#4,D1

	MOVE.L	D0,($003C,SP)
	MOVE.L	D1,($0038,SP)

.loop:	MOVE.L	($003C,SP),D0
	CMP.L	($0038,SP),D0
	BHI.B	.loopout
	MOVE.L	D0,D1
	LSR.L	#8,D1
	LSR.L	#5,D1
	MOVE.L	D0,D2
	LSR.L	#6,D2
	MOVEQ	#$7F,D3
	AND.L	D3,D2
	MOVEQ	#$3F,D3
	AND.L	D0,D3
	MOVEA.L	($0034,A5),A0
	MOVEA.L	(12,A0),A1
	LEA	(A1,D1.L*4),A2
	MOVE.L	(A2),D4
	ANDI.W	#$FE00,D4
	MOVEA.L	D4,A4
	MOVE.L	(A4,D2.L*4),D4
	ANDI.W	#$FE00,D4
	MOVEA.L	D4,A4
	MOVE.L	(A4,D3.L*4),($0034,SP)
	MOVE.L	D1,($0030,SP)
	MOVE.L	D2,($002C,SP)
	MOVE.L	D3,($0028,SP)
	TST.W	D5
	BEQ.B	.skip
	MOVE.L	(A4,D3.L*4),D1
	ORI.W	#4,D1
	MOVE.L	D1,(A4,D3.L*4)
	BRA.B	.loopcont

.skip:	MOVEQ	#$3F,D1
	AND.L	D0,D1
	MOVE.L	(A4,D1.L*4),D2
	ANDI.W	#$FFFB,D2
	MOVE.L	D2,(A4,D1.L*4)
.loopcont:	ADDQ.L	#1,($003C,SP)
	BRA.B	.loop

.loopout:	MOVE.L	($0034,SP),D0
	MOVEM.L	(SP)+,D2-D7/A2/A4-A6
	ADDA.W	#$0018,SP
	RTS

; --------------------------------------------------------------------------
_BuildMMU:	SUBQ.W	#4,SP
	MOVEM.L	D7/A2-A6,-(SP)

	MOVEA.L	A6,A5
	MOVEA.L	(4).W,A6
	JSR	(_LVOForbid,A6)

	BSR.W	_SetupMMUFrame
	MOVEA.L	D0,A3

	PEA	($40).W
	MOVEA.L	A3,A0
	MOVE.L	#$00BC0000,D0
	MOVEQ	#4,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	PEA	($40).W
	MOVEA.L	A3,A0
	MOVE.L	#$00D80000,D0
	MOVEQ	#8,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	CLR.L	(SP)
	MOVEA.L	A3,A0
	MOVE.L	#$00F00000,D0
	MOVEQ	#$10,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	ADDQ.W	#8,SP
	MOVEA.L	($0038,A5),A1
	JSR	(_LVOOpenResource,A6)
	TST.L	D0
	BEQ.B	.noresource

	PEA	($40).W
	MOVEA.L	A3,A0
	MOVEQ	#$60,D0
	SWAP	D0
	MOVE.L	#$00440002,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	ADDQ.W	#4,SP
.noresource:	MOVEA.L	($003C,A5),A1
	JSR	(_LVOFindResident,A6)
	TST.L	D0
	BEQ.B	.noresident

	PEA	($40).W
	MOVEA.L	A3,A0
	MOVE.L	#$00E00000,D0
	MOVEQ	#8,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A3
	ADDQ.W	#4,SP

.noresident:	MOVEA.W	#4,A0
	MOVEA.L	(A0),A1
	MOVE.L	(10,A1),D0
	CLR.W	D0
	SWAP	D0
	MOVEQ	#$20,D1
	CMP.L	D1,D0
	BNE.B	.wrongresver

	CLR.L	-(SP)
	MOVEA.L	A3,A0
	MOVEQ	#$20,D0
	SWAP	D0
	MOVEQ	#8,D1
	SWAP	D1
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A3
	ADDQ.W	#4,SP

.wrongresver:	PEA	($40).W
	MOVEA.L	A3,A0
	MOVEQ	#0,D0
	MOVEQ	#$40,D1
	LSL.L	#6,D1
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	ADDQ.W	#4,SP
	JSR	(_LVOForbid,A6)

	MOVEA.W	#4,A0
	MOVEA.L	(A0),A1
	MOVEA.L	(MemList,A1),A2
.setup_mem_loop:	TST.L	(LN_SUCC,A2)
	BEQ.B	.endofmemlist
	MOVEA.L	(MH_LOWER,A2),A1
	MOVEA.L	(4).W,A6
	JSR	(_LVOTypeOfMem,A6)
	BTST	#MEMF_PUBLIC,D0
	BEQ.B	.ispubmem
	MOVEQ	#$40,D7
	BRA.B	.isnotpubmem

.ispubmem:	MOVEQ	#$20,D7
.isnotpubmem:	MOVE.L	(MH_LOWER,A2),D0
	MOVE.L	(MH_UPPER,A2),D1
	SUB.L	D0,D1
	MOVE.L	D7,-(SP)
	MOVEA.L	A3,A0
	BSR.W	_SetMMUPageMode

	MOVEA.L	D0,A3
	ADDQ.W	#4,SP
	MOVEQ	#$20,D0
	CMP.L	D0,D7
	BNE.B	.waspublic
	MOVE.L	(MH_LOWER,A2),D0
	MOVE.L	(MH_UPPER,A2),D1
	MOVEA.L	A3,A0
	BSR.W	_AllocMMUPages

	MOVEA.L	D0,A3
.waspublic:	MOVEA.L	A2,A0
	MOVEA.L	(LN_SUCC,A0),A2
	BRA.B	.setup_mem_loop

.endofmemlist:	MOVEA.L	(4).W,A6
	JSR	(_LVOPermit,A6)

	MOVEA.L	($0040,A5),A1
	MOVEQ	#0,D0
	JSR	(_LVOOpenLibrary,A6)
	MOVEA.L	D0,A4

	MOVE.L	A4,D0
	BEQ.B	.nolib

	CLR.L	($0018,SP)
.reinit:	MOVEA.L	($0018,SP),A0
	MOVEQ	#-1,D0
	MOVE.L	D0,D1
	MOVEA.L	A4,A6
	JSR	(-$0048,A6)
	MOVE.L	D0,($0018,SP)
	BEQ.B	.initfailed

	MOVEA.L	D0,A0
	BTST	#5,($0010,A0)
	BNE.B	.reinit

	MOVE.L	($0020,A0),D1
	PEA	($40).W
	MOVE.L	D1,D0
	MOVE.L	($0024,A0),D1
	MOVEA.L	A3,A0
	BSR.W	_SetMMUPageMode
	MOVEA.L	D0,A3
	ADDQ.W	#4,SP
	BRA.B	.reinit

.initfailed:	MOVEA.L	A4,A1
	MOVEA.L	(4).W,A6
	JSR	(_LVOCloseLibrary,A6)

.nolib:	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	@Map_PatchArea

	MOVEA.L	(4).W,A6
	JSR	(_LVOPermit,A6)
	MOVE.L	A3,D0
	MOVE.L	A3,D0
	MOVEM.L	(SP)+,D7/A2-A6
	ADDQ.W	#4,SP
	RTS

;fiX Label expected
	NOP

	end
