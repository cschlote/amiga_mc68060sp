
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: 68060.library.asm,v 1.3 1996/06/09 20:03:14 schlote Exp schlote $
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
_060_real_trace:	RTE
_060_real_access:	RTE

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

Install_Int_Emulation:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	(_I_CALL_TOP_MEM,PC),A0
	LEA	(_I_CALL_TOP,PC),A1
	MOVE.L	($007A,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($007E,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($0082,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($0086,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($008A,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($008E,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($0092,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($0096,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($009A,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($009E,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	($00A2,A6),D0
	SUB.L	A1,D0
	MOVE.L	D0,(A0)
	LEA	(Install_I_Emulation_Traps,PC),A5
	MOVEA.L	(4).W,A6
	JSR	(_LVOSupervisor,A6)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#0,D0
	RTS

Install_I_Emulation_Traps:
	MOVEC	VBR,A2
	LEA	(Vector_61,PC),A1
	MOVE.L	($00F4,A2),(A1)
	LEA	(lbW015B5A,PC),A1
	ADDA.L	(A1),A1
	LEA	(_060_isp_unimp,PC),A1
	MOVE.L	A1,($00F4,A2)
	MOVE.L	A1,($F4).W
	RTE

Vector_61:	dc.l	0

_060_isp_done:	RTE

_060_real_chk:	TST.B	(SP)
	BPL.B	real_chk_end
	MOVE.B	#$24,(7,SP)
	BRA.L	_060_real_trace2

real_chk_end:	RTE

_060_real_divbyzero:
	TST.B	(SP)
	BPL.B	real_divbyzero_end
	MOVE.B	#$24,(7,SP)
	BRA.L	_060_real_trace2

real_divbyzero_end:	RTE

_060_real_cas:	BRA.L	lbW015B60

;fiX Code reference expected
_060_real_cas2:	BRA.L	lbW015B68

;fiX Code reference expected
_060_real_lock_page:
	CLR.L	D0
	RTS

_060_real_unlock_page:
	CLR.L	D0
	RTS

_060_real_trace2:	RTE

_060_real_access2:	RTE

_060_isp_unimp:	BRA.L	lbW015B58

;fiX Code reference expected
_060_isp_cas:	BRA.L	lbW015B60

;fiX Code reference expected
_060_isp_cas2:	BRA.L	lbW015B68

;fiX Code reference expected
_060_isp_cas_finish:
	BRA.L	lbW015B70

;fiX Code reference expected
_060_isp_cas2_finish:
	BRA.L	lbW015B78

;fiX Code reference expected
_060_isp_cas_inrange:
	BRA.L	lbW015B80

;fiX Code reference expected
_060_isp_cas_terminate:
	BRA.L	lbW015B88

;fiX Code reference expected
_060_isp_cas_restart:
	BRA.L	lbW015B90

;fiX Code reference expected
_I_CALL_TOP:	dc.l	$FFFFFF94,$FFFFFFA6,$FFFFFFCC,$FFFFFFCE,$FFFFFF92,$FFFFFFB8,$FFFFFFBE
	dc.l	$FFFFFFC4,$FFFFFFC8,0,0,0,0,0,0,0
_I_CALL_TOP_MEM:	dcb.l	$00000010,0
lbW015B58:	dc.w	$60FF
lbW015B5A:	dc.w	0,$0236,0
lbW015B60:	dc.w	$60FF,0,$1626,0
lbW015B68:	dc.w	$60FF,0,$12DC,0
lbW015B70:	dc.w	$60FF,0,$11EA,0
lbW015B78:	dc.w	$60FF,0,$10DE,0
lbW015B80:	dc.w	$60FF,0,$12A4,0
lbW015B88:	dc.w	$60FF,0,$1256,0
lbW015B90:	dc.w	$60FF,0,$122A,0,$51FC
	dcb.w	$0000001F,$51FC
	dc.w	$2F00,$203A,$FEFC,$487B,$0930,$FFFF,$FEF8,$202F,4,$4E74,4,$2F00,$203A
	dc.w	$FEEA,$487B,$0930,$FFFF,$FEE2,$202F,4,$4E74,4,$2F00,$203A,$FED8,$487B
	dc.w	$0930,$FFFF,$FECC,$202F,4,$4E74,4,$2F00,$203A,$FEC6,$487B,$0930,$FFFF
	dc.w	$FEB6,$202F,4,$4E74,4,$2F00,$203A,$FEB4,$487B,$0930,$FFFF,$FEA0,$202F
	dc.w	4,$4E74,4,$2F00,$203A,$FEA2,$487B,$0930,$FFFF,$FE8A,$202F,4,$4E74,4
	dc.w	$2F00,$203A,$FE90,$487B,$0930,$FFFF,$FE74,$202F,4,$4E74,4,$2F00,$203A
	dc.w	$FE7E,$487B,$0930,$FFFF,$FE5E,$202F,4,$4E74,4,$2F00,$203A,$FE6C,$487B
	dc.w	$0930,$FFFF,$FE48,$202F,4,$4E74,4,$2F00,$203A,$FE76,$487B,$0930,$FFFF
	dc.w	$FE32,$202F,4,$4E74,4,$2F00,$203A,$FE64,$487B,$0930,$FFFF,$FE1C,$202F
	dc.w	4,$4E74,4,$2F00,$203A,$FE52,$487B,$0930,$FFFF,$FE06,$202F,4,$4E74,4
	dc.w	$2F00,$203A,$FE40,$487B,$0930,$FFFF,$FDF0,$202F,4,$4E74,4,$2F00,$203A
	dc.w	$FE2E,$487B,$0930,$FFFF,$FDDA,$202F,4,$4E74,4,$2F00,$203A,$FE1C,$487B
	dc.w	$0930,$FFFF,$FDC4,$202F,4,$4E74,4,$2F00,$203A,$FE0A,$487B,$0930,$FFFF
	dc.w	$FDAE,$202F,4,$4E74,4,$2F00,$203A,$FDF8,$487B,$0930,$FFFF,$FD98,$202F
	dc.w	4,$4E74,4,$2F00,$203A,$FDE6,$487B,$0930,$FFFF,$FD82,$202F,4,$4E74,4
	dc.w	$2F00,$203A,$FDD4,$487B,$0930,$FFFF,$FD6C,$202F,4,$4E74,4,$2F00,$203A
	dc.w	$FDC2,$487B,$0930,$FFFF,$FD56,$202F,4,$4E74,4,$4E56,$FFA0,$48EE,$3FFF
	dc.w	$FFC0,$2D56,$FFF8,$082E,5,4,$6608,$4E68,$2D48,$FFFC,$6008,$41EE,12
	dc.w	$2D48,$FFFC,$422E,$FFAA,$3D6E,4,$FFA8,$2D6E,6,$FFA4,$206E,$FFA4,$58AE
	dc.w	$FFA4,$61FF,$FFFF,$FF26,$2D40,$FFA0,$0800,$001E,$6768,$0800,$0016
	dc.w	$6628,$61FF,0,$0CB0,$082E,5,4,$6700,$00AC,$082E,2,$FFAA,$6700,$00A2
	dc.w	$082E,7,4,$6600,$0186,$6000,$01B0,$61FF,0,$0A28,$082E,2,$FFAA,$660E
	dc.w	$082E,5,$FFAA,$6600,$010A,$6000,$0078,$082E,5,4,$67EA,$082E,5,$FFAA
	dc.w	$6600,$0126,$4A2E,4,$6B00,$014C,$6000,$0176,$0800,$0018,$670A,$61FF,0
	dc.w	$07AE,$6000,$004A,$0800,$001B,$6730,$4840,$0C00,$00FC,$670A,$61FF,0
	dc.w	$0E92,$6000,$0032,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$FE68,$4A81
	dc.w	$6600,$0198,$61FF,0,$0D20,$6000,$0014,$61FF,0,$08C4,$0C2E,$0010,$FFAA
	dc.w	$6600,4,$605C,$1D6E,$FFA9,5,$082E,5,4,$6606,$206E,$FFFC,$4E60,$4CEE
	dc.w	$3FFF,$FFC0,$082E,7,4,$6612,$2D6E,$FFA4,6,$2CAE,$FFF8,$4E5E,$60FF
	dc.w	$FFFF,$FD62,$2D6E,$FFF8,$FFFC,$3D6E,4,0,$2D6E,6,8,$2D6E,$FFA4,2,$3D7C
	dc.w	$2024,6,$598E,$4E5E,$60FF,$FFFF,$FD0E,$1D6E,$FFA9,5,$4CEE,$3FFF,$FFC0
	dc.w	$3CAE,4,$2D6E,6,8,$2D6E,$FFA4,2,$3D7C,$2018,6,$2C6E,$FFF8,$DFFC,0
	dc.w	$0060,$60FF,$FFFF,$FCB0,$1D6E,$FFA9,5,$4CEE,$3FFF,$FFC0,$3CAE,4,$2D6E
	dc.w	6,8,$2D6E,$FFA4,2,$3D7C,$2014,6,$2C6E,$FFF8,$DFFC,0,$0060,$60FF,$FFFF
	dc.w	$FC94,$1D6E,$FFA9,5,$4CEE,$3FFF,$FFC0,$2D6E,6,12,$3D7C,$2014,10,$2D6E
	dc.w	$FFA4,6,$2C6E,$FFF8,$DFFC,0,$0064,$60FF,$FFFF,$FC66,$1D6E,$FFA9,5
	dc.w	$4CEE,$3FFF,$FFC0,$2D6E,6,12,$3D7C,$2024,10,$2D6E,$FFA4,6,$2C6E,$FFF8
	dc.w	$DFFC,0,$0064,$60FF,$FFFF,$FC4E,$1D6E,$FFA9,5,$4CEE,$3FFF,$FFC0,$3D7C
	dc.w	$00F4,14,$2D6E,$FFA4,10,$3D6E,4,8,$2C6E,$FFF8,$DFFC,0,$0068,$60FF
	dc.w	$FFFF,$FC4C,$2C88,$2D40,$FFFC,$4FEE,$FFC0,$4CDF,$7FFF,$2F2F,12,$2F6F
	dc.w	4,$0010,$2F6F,12,4,$2F6F,8,12,$2F5F,4,$3F7C,$4008,6,$6028,$4CEE,$3FFF
	dc.w	$FFC0,$4E5E,$514F,$2EAF,8,$3F6F,12,4,$3F7C,$4008,6,$2F6F,2,8,$2F7C
	dc.w	$0942,$8001,12,$0817,5,$6706,$08EF,2,13,$60FF,$FFFF,$FBCC,$0C2E,$0040
	dc.w	$FFAA,$660C,$4280,$102E,$FFAB,$2DAE,$FFAC,$0CE0,$4E75,$2040,$302E
	dc.w	$FFA0,$3200,$0240,$003F,$0281,0,7,$303B,$020A,$4EFB,6,$4AFC,$0040,0,0
	dcb.w	14,0
	dc.w	$0080,$0086,$008C,$0092,$0098,$009E,$00A4,$00AA,$00B0,$00CE,$00EC
	dc.w	$010A,$0128,$0146,$0164,$0182,$0196,$01B4,$01D2,$01F0,$020E,$022C
	dc.w	$024A,$0268,$027C,$029A,$02B8,$02D6,$02F4,$0312,$0330,$034E,$036C
	dcb.w	7,$036C
	dc.w	$03D6,$03F0,$040A,$042A,$03CA,0,0,0,$206E,$FFE0,$4E75,$206E,$FFE4
	dc.w	$4E75,$206E,$FFE8,$4E75,$206E,$FFEC,$4E75,$206E,$FFF0,$4E75,$206E
	dc.w	$FFF4,$4E75,$206E,$FFF8,$4E75,$206E,$FFFC,$4E75,$2008,$206E,$FFE0
	dc.w	$D088,$2D40,$FFE0,$2D48,$FFAC,$1D7C,0,$FFAB,$1D7C,$0040,$FFAA,$4E75
	dc.w	$2008,$206E,$FFE4,$D088,$2D40,$FFE4,$2D48,$FFAC,$1D7C,1,$FFAB,$1D7C
	dc.w	$0040,$FFAA,$4E75,$2008,$206E,$FFE8,$D088,$2D40,$FFE8,$2D48,$FFAC
	dc.w	$1D7C,2,$FFAB,$1D7C,$0040,$FFAA,$4E75,$2008,$206E,$FFEC,$D088,$2D40
	dc.w	$FFEC,$2D48,$FFAC,$1D7C,3,$FFAB,$1D7C,$0040,$FFAA,$4E75,$2008,$206E
	dc.w	$FFF0,$D088,$2D40,$FFF0,$2D48,$FFAC,$1D7C,4,$FFAB,$1D7C,$0040,$FFAA
	dc.w	$4E75,$2008,$206E,$FFF4,$D088,$2D40,$FFF4,$2D48,$FFAC,$1D7C,5,$FFAB
	dc.w	$1D7C,$0040,$FFAA,$4E75,$2008,$206E,$FFF8,$D088,$2D40,$FFF8,$2D48
	dc.w	$FFAC,$1D7C,6,$FFAB,$1D7C,$0040,$FFAA,$4E75,$1D7C,4,$FFAA,$2008,$206E
	dc.w	$FFFC,$D088,$2D40,$FFFC,$4E75,$202E,$FFE0,$2D40,$FFAC,$9088,$2D40
	dc.w	$FFE0,$2040,$1D7C,0,$FFAB,$1D7C,$0040,$FFAA,$4E75,$202E,$FFE4,$2D40
	dc.w	$FFAC,$9088,$2D40,$FFE4,$2040,$1D7C,1,$FFAB,$1D7C,$0040,$FFAA,$4E75
	dc.w	$202E,$FFE8,$2D40,$FFAC,$9088,$2D40,$FFE8,$2040,$1D7C,2,$FFAB,$1D7C
	dc.w	$0040,$FFAA,$4E75,$202E,$FFEC,$2D40,$FFAC,$9088,$2D40,$FFEC,$2040
	dc.w	$1D7C,3,$FFAB,$1D7C,$0040,$FFAA,$4E75,$202E,$FFF0,$2D40,$FFAC,$9088
	dc.w	$2D40,$FFF0,$2040,$1D7C,4,$FFAB,$1D7C,$0040,$FFAA,$4E75,$202E,$FFF4
	dc.w	$2D40,$FFAC,$9088,$2D40,$FFF4,$2040,$1D7C,5,$FFAB,$1D7C,$0040,$FFAA
	dc.w	$4E75,$202E,$FFF8,$2D40,$FFAC,$9088,$2D40,$FFF8,$2040,$1D7C,6,$FFAB
	dc.w	$1D7C,$0040,$FFAA,$4E75,$1D7C,8,$FFAA,$202E,$FFFC,$9088,$2D40,$FFFC
	dc.w	$2040,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F9D4,$4A81,$66FF
	dc.w	$FFFF,$FD04,$3040,$D1EE,$FFE0,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF
	dc.w	$FFFF,$F9B6,$4A81,$66FF,$FFFF,$FCE6,$3040,$D1EE,$FFE4,$4E75,$206E
	dc.w	$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F998,$4A81,$66FF,$FFFF,$FCC8,$3040
	dc.w	$D1EE,$FFE8,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F97A,$4A81
	dc.w	$66FF,$FFFF,$FCAA,$3040,$D1EE,$FFEC,$4E75,$206E,$FFA4,$54AE,$FFA4
	dc.w	$61FF,$FFFF,$F95C,$4A81,$66FF,$FFFF,$FC8C,$3040,$D1EE,$FFF0,$4E75
	dc.w	$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F93E,$4A81,$66FF,$FFFF,$FC6E
	dc.w	$3040,$D1EE,$FFF4,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F920
	dc.w	$4A81,$66FF,$FFFF,$FC50,$3040,$D1EE,$FFF8,$4E75,$206E,$FFA4,$54AE
	dc.w	$FFA4,$61FF,$FFFF,$F902,$4A81,$66FF,$FFFF,$FC32,$3040,$D1EE,$FFFC
	dc.w	$4E75,$2F01,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F8E2,$4A81,$66FF
	dc.w	$FFFF,$FC12,$221F,$2076,$14E0,$0800,8,$670E,$48E7,$3C00,$2A00,$2608
	dc.w	$60FF,0,$00EC,$2F02,$2200,$E959,$0241,15,$2236,$14C0,$0800,11,$6602
	dc.w	$48C1,$2400,$EF5A,$0282,0,3,$E5A9,$49C0,$D081,$D1C0,$241F,$4E75,$1D7C
	dc.w	$0080,$FFAA,$206E,$FFA4,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF
	dc.w	$F87A,$4A81,$66FF,$FFFF,$FBAA,$3040,$4E75,$206E,$FFA4,$58AE,$FFA4
	dc.w	$61FF,$FFFF,$F876,$4A81,$66FF,$FFFF,$FB90,$2040,$4E75,$206E,$FFA4
	dc.w	$54AE,$FFA4,$61FF,$FFFF,$F846,$4A81,$66FF,$FFFF,$FB76,$3040,$D1EE
	dc.w	$FFA4,$5588,$4E75,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F826,$4A81
	dc.w	$66FF,$FFFF,$FB56,$206E,$FFA4,$5588,$0800,8,$670E,$48E7,$3C00,$2A00
	dc.w	$2608,$60FF,0,$0030,$2F02,$2200,$E959,$0241,15,$2236,$14C0,$0800,11
	dc.w	$6602,$48C1,$2400,$EF5A,$0282,0,3,$E5A9,$49C0,$D081,$D1C0,$241F,$4E75
	dc.w	$0805,6,$6704,$4282,$6016,$E9C5,$2404,$2436,$24C0,$0805,11,$6602
	dc.w	$48C2,$E9C5,$0542,$E1AA,$0805,7,$6702,$4283,$E9C5,$0682,$0C00,2,$6D34
	dc.w	$6718,$206E,$FFA4,$58AE,$FFA4,$61FF,$FFFF,$F7AC,$4A81,$66FF,$FFFF
	dc.w	$FAC6,$6018,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F77E,$4A81,$66FF
	dc.w	$FFFF,$FAAE,$48C0,$D680,$E9C5,$0782,$6700,$006A,$0C00,2,$6D34,$6718
	dc.w	$206E,$FFA4,$58AE,$FFA4,$61FF,$FFFF,$F76A,$4A81,$66FF,$FFFF,$FA84
	dc.w	$601C,$206E,$FFA4,$54AE,$FFA4,$61FF,$FFFF,$F73C,$4A81,$66FF,$FFFF
	dc.w	$FA6C,$48C0,$6002,$4280,$2800,$0805,2,$6712,$2043,$61FF,$FFFF,$F776
	dc.w	$4A81,$6624,$D082,$D084,$6016,$D682,$2043,$61FF,$FFFF,$F762,$4A81
	dc.w	$6610,$D084,$6004,$D682,$2003,$2040,$4CDF,$003C,$4E75,$2043,$203C
	dc.w	$0101,1,$60FF,$FFFF,$F9F0,$322E,$FFA0,$1001,$0240,7,$2076,$04E0,$D0EE
	dc.w	$FFA2,$0801,7,$6700,$008C,$3001,$EF58,$0240,7,$2036,$04C0,$0801,6
	dc.w	$6752,$2400,$2448,$E19A,$2002,$61FF,$FFFF,$F71C,$4A81,$6600,$00FC
	dc.w	$544A,$204A,$E19A,$2002,$61FF,$FFFF,$F708,$4A81,$6600,$00E8,$544A
	dc.w	$204A,$E19A,$2002,$61FF,$FFFF,$F6F4,$4A81,$6600,$00D4,$544A,$204A
	dc.w	$E19A,$2002,$61FF,$FFFF,$F6E0,$4A81,$6600,$00C0,$4E75,$2400,$2448
	dc.w	$E048,$61FF,$FFFF,$F6CC,$4A81,$6600,$00AC,$544A,$204A,$2002,$61FF
	dc.w	$FFFF,$F6BA,$4A81,$6600,$009A,$4E75,$0801,6,$675C,$2448,$61FF,$FFFF
	dc.w	$F662,$4A81,$6600,$0092,$2400,$544A,$204A,$61FF,$FFFF,$F650,$4A81
	dc.w	$6600,$0080,$E14A,$1400,$544A,$204A,$61FF,$FFFF,$F63C,$4A81,$6600
	dc.w	$006C,$E18A,$1400,$544A,$204A,$61FF,$FFFF,$F628,$4A81,$6600,$0058
	dc.w	$E18A,$1400,$122E,$FFA0,$E209,$0241,7,$2D82,$14C0,$4E75,$2448,$61FF
	dc.w	$FFFF,$F606,$4A81,$6600,$0036,$2400,$544A,$204A,$61FF,$FFFF,$F5F4
	dc.w	$4A81,$6600,$0024,$E14A,$1400,$122E,$FFA0,$E209,$0241,7,$3D82,$14C2
	dc.w	$4E75,$204A,$203C,$00A1,1,$60FF,$FFFF,$F8A8,$204A,$203C,$0121,1,$60FF
	dc.w	$FFFF,$F89A,$61FF,$FFFF,$F914,$102E,$FFA2,$E918,$0240,15,$2436,$04C0
	dc.w	$0C2E,2,$FFA0,$6D50,$6728,$2448,$61FF,$FFFF,$F5C4,$4A81,$6600,$009E
	dc.w	$2600,$588A,$204A,$61FF,$FFFF,$F5B2,$4A81,$6600,$008C,$2200,$2003
	dc.w	$6000,$0048,$2448,$61FF,$FFFF,$F59C,$4A81,$6600,$0076,$3200,$4840
	dc.w	$48C0,$48C1,$082E,7,$FFA2,$6600,$0028,$48C2,$6000,$0022,$2448,$61FF
	dc.w	$FFFF,$F560,$4A81,$6600,$005E,$1200,$E048,$49C0,$49C1,$082E,7,$FFA2
	dc.w	$6602,$49C2,$9480,$42C3,$0203,4,$9280,$B282,$42C4,$8604,$0203,5,$382E
	dc.w	$FFA8,$0204,$001A,$8803,$3D44,$FFA8,$082E,3,$FFA2,$6602,$4E75,$0804,0
	dc.w	$6602,$4E75,$1D7C,$0010,$FFAA,$4E75,$204A,$203C,$0101,1,$60FF,$FFFF
	dc.w	$F7C4,$204A,$203C,$0141,1,$60FF,$FFFF,$F7B6,$102E,$FFA1,$0200,$0038
	dc.w	$6600,$0208,$102E,$FFA1,$0240,7,$2E36,$04C0,$6700,$00C0,$102E,$FFA3
	dc.w	$122E,$FFA2,$0240,7,$E809,$0241,7,$3D40,$FFB2,$3D41,$FFB4,$2A36,$04C0
	dc.w	$2C36,$14C0,$082E,3,$FFA2,$671A,$4A87,$5DEE,$FFB0,$6A02,$4487,$4A85
	dc.w	$5DEE,$FFB1,$6A08,$44FC,0,$4086,$4085,$4A85,$6616,$4A86,$6700,$0048
	dc.w	$BE86,$6306,$CB46,$6000,$0012,$4C47,$6005,$600A,$BE85,$634E,$61FF,0
	dc.w	$0068,$082E,3,$FFA2,$6724,$4A2E,$FFB1,$6702,$4485,$102E,$FFB0,$B12E
	dc.w	$FFB1,$670C,$0C86,$8000,0,$6226,$4486,$6006,$0806,$001F,$661C,$44EE
	dc.w	$FFA8,$4A86,$42EE,$FFA8,$302E,$FFB2,$322E,$FFB4,$2D85,$04C0,$2D86
	dc.w	$14C0,$4E75,$08EE,1,$FFA9,$08AE,0,$FFA9,$4E75,$022E,$001E,$FFA9,$002E
	dc.w	$0020,$FFAA,$4E75,$0C87,0,$FFFF,$621E,$4281,$4845,$4846,$3A06,$8AC7
	dc.w	$3205,$4846,$3A06,$8AC7,$4841,$3205,$4245,$4845,$2C01,$4E75,$42AE
	dc.w	$FFBC,$422E,$FFB6,$4281,$0807,$001F,$660E,$52AE,$FFBC,$E38F,$E38E
	dc.w	$E395,$6000,$FFEE,$2607,$2405,$4842,$4843,$B443,$6606,$323C,$FFFF
	dc.w	$600A,$2205,$82C3,$0281,0,$FFFF,$2F06,$4246,$4846,$2607,$2401,$C4C7
	dc.w	$4843,$C6C1,$2805,$9883,$4844,$3004,$3806,$4A40,$6600,10,$B484,$6304
	dc.w	$5381,$60DE,$2F05,$2C01,$4846,$2A07,$61FF,0,$006A,$2405,$2606,$2A1F
	dc.w	$2C1F,$9C83,$9B82,$64FF,0,$001A,$5381,$4282,$2607,$4843,$4243,$DC83
	dc.w	$DB82,$2607,$4243,$4843,$DA83,$4A2E,$FFB6,$6616,$3D41,$FFB8,$4281
	dc.w	$4845,$4846,$3A06,$4246,$50EE,$FFB6,$6000,$FF6C,$3D41,$FFBA,$3C05
	dc.w	$4846,$4845,$2E2E,$FFBC,$670A,$5387,$E28D,$E296,$51CF,$FFFA,$2A06
	dc.w	$2C2E,$FFB8,$4E75,$2406,$2606,$2805,$4843,$4844,$CCC5,$CAC3,$C4C4
	dc.w	$C6C4,$4284,$4846,$DC45,$D744,$DC42,$D744,$4846,$4245,$4242,$4845
	dc.w	$4842,$DA82,$DA83,$4E75,$7004,$61FF,$FFFF,$F61C,$0C2E,$0080,$FFAA
	dc.w	$6712,$2448,$61FF,$FFFF,$F2DC,$4A81,$661E,$2E00,$6000,$FDE6,$58AE
	dc.w	$FFA4,$61FF,$FFFF,$F286,$4A81,$66FF,$FFFF,$F5A0,$2E00,$6000,$FDCE
	dc.w	$61FF,$FFFF,$F5CE,$204A,$203C,$0101,1,$60FF,$FFFF,$F556,$102E,$FFA1
	dc.w	$0C00,7,$6E00,$00B4,$0240,7,$2636,$04C0,$342E,$FFA2,$4241,$1202,$E95A
	dc.w	$0242,7,$2836,$24C0,$4A84,$6700,$0088,$4A83,$6700,$0082,$422E,$FFB0
	dc.w	$082E,3,$FFA2,$6718,$4A83,$6C08,$4483,$002E,1,$FFB0,$4A84,$6C08,$4484
	dc.w	$0A2E,1,$FFB0,$2A03,$2C03,$2E04,$4846,$4847,$C6C4,$C8C6,$CAC7,$CCC7
	dc.w	$4287,$4843,$D644,$DD87,$D645,$DD87,$4843,$4244,$4245,$4844,$4845
	dc.w	$D885,$D886,$4A2E,$FFB0,$6708,$4683,$4684,$5283,$D987,$2D83,$24C0
	dc.w	$44FC,0,$2D84,$14C0,$42C7,$0207,8,$1C2E,$FFA9,$0206,$0010,$8C07,$1D46
	dc.w	$FFA9,$4E75,$42B6,$24C0,$42B6,$14C0,$7E04,$60E4,$7004,$61FF,$FFFF
	dc.w	$F510,$0C2E,$0080,$FFAA,$6714,$2448,$61FF,$FFFF,$F1D0,$4A81,$6600
	dc.w	$0020,$2600,$6000,$FF34,$58AE,$FFA4,$61FF,$FFFF,$F178,$4A81,$66FF
	dc.w	$FFFF,$F492,$2600,$6000,$FF1C,$61FF,$FFFF,$F4C0,$204A,$203C,$0101,1
	dc.w	$60FF,$FFFF,$F448,$2D40,$FFB4,$2200,$E958,$0240,15,$2276,$04C0,$2D49
	dc.w	$FFB0,$2001,$EC49,$0241,7,$2A36,$14C0,$0240,7,$2636,$04C0,$3D40,$FFBA
	dc.w	$302E,$FFA2,$2200,$E958,$0240,15,$2076,$04C0,$2D48,$FFBC,$2001,$EC49
	dc.w	$0241,7,$2836,$14C0,$0240,7,$2436,$04C0,$3D40,$FFB8,$082E,1,$FFA0
	dc.w	$56C7,$082E,5,4,$56C6,$2448,$2649,$2207,$2006,$61FF,$FFFF,$F05C,$204A
	dc.w	$4A80,$66FF,0,$01C8,$2207,$2006,$204B,$61FF,$FFFF,$F046,$204B,$4A80
	dc.w	$660A,$204A,$224B,$60FF,$FFFF,$F020,$2F00,$2207,$2006,$204A,$61FF
	dc.w	$FFFF,$F03E,$201F,$204B,$60FF,0,$0194,$082E,1,$FFA0,$6648,$44EE,$FFA8
	dc.w	$B042,$6602,$B243,$42EE,$FFA8,$4A04,$6610,$362E,$FFBA,$3D81,$34C2
	dc.w	$342E,$FFB8,$3D80,$24C2,$082E,5,4,$56C2,$2002,$51C1,$206E,$FFBC,$61FF
	dc.w	$FFFF,$EFF4,$2002,$51C1,$206E,$FFB0,$61FF,$FFFF,$EFE6,$4E75,$44EE
	dc.w	$FFA8,$B082,$6602,$B283,$42EE,$FFA8,$4A04,$6610,$362E,$FFBA,$2D81
	dc.w	$34C0,$342E,$FFB8,$2D80,$24C0,$082E,5,4,$56C2,$2002,$50C1,$206E,$FFBC
	dc.w	$61FF,$FFFF,$EFAC,$2002,$50C1,$206E,$FFB0,$61FF,$FFFF,$EF9E,$4E75
	dc.w	$202E,$FFB4,$6000,$FEAE,$082E,1,$FFA0,$6610,$7002,$61FF,$FFFF,$F364
	dc.w	$2D48,$FFB4,$51C7,$600E,$7004,$61FF,$FFFF,$F354,$2D48,$FFB4,$50C7
	dc.w	$302E,$FFA2,$2200,$EC48,$0240,7,$2436,$04C0,$0241,7,$2836,$14C0,$3D41
	dc.w	$FFB8,$082E,5,4,$56C6,$2448,$2207,$2006,$61FF,$FFFF,$EF28,$4A80,$6600
	dc.w	$0096,$204A,$60FF,$FFFF,$EEEE,$082E,1,$FFA0,$662C,$44EE,$FFA8,$B044
	dc.w	$42EE,$FFA8,$4A01,$6608,$362E,$FFB8,$3D80,$34C2,$206E,$FFB4,$51C1
	dc.w	$082E,5,4,$56C0,$61FF,$FFFF,$EEFE,$4E75,$44EE,$FFA8,$B084,$42EE,$FFA8
	dc.w	$4A01,$6608,$362E,$FFB8,$2D80,$34C0,$206E,$FFB4,$50C1,$082E,5,4,$56C0
	dc.w	$61FF,$FFFF,$EED2,$4E75,$4E7B,$6000,$4E7B,$6001,$0C2E,$00FC,$FFA1
	dc.w	$67FF,$FFFF,$FF24,$206E,$FFB4,$082E,1,$FFA0,$56C7,$6000,$FF40,$4E7B
	dc.w	$6000,$4E7B,$6001,$2448,$2F00,$61FF,$FFFF,$F264,$201F,$588F,$518F
	dc.w	$518E,$721A,$41EF,8,$43EF,0,$22D8,$51C9,$FFFC,$3D7C,$4008,10,$2D4A,12
	dc.w	$2D40,$0010,$4CEE,$3FFF,$FFC0,$4E5E,$60FF,$FFFF,$EDF8,$4280,$43FB
	dc.w	$0170,0,$05AE,$B3C8,$6D0E,$43FB,$0170,0,$0010,$B1C9,$6D02,$4E75,$70FF
	dc.w	$4E75,$4A06,$6604,$7001,$6002,$7005,$4A07,$6700,$01E4,$2448,$2649
	dc.w	$2848,$2A49,$568C,$568D,$220A,$40C7,$007C,$0700,$4E7A,$6000,$4E7B,0
	dc.w	$4E7B,1,$F58A,$F58C,$F58B,$F58D,$F46A,$F46C,$F46B,$F46D,$2441,$5681
	dc.w	$2841,$F5CA,$F5CC,$247C,$8000,0,$267C,$A000,0,$287C,0,0,$2008,$0200,3
	dc.w	$671C,$0C00,2,$6700,$0096,$6000,$0102,$51FC,$4E7B,$A008,$0E91,$1000
	dc.w	$0E90,0,$6002,$600E,$B082,$661C,$B283,$6618,$0E91,$5800,$6002,$600E
	dc.w	$4E7B,$B008,$0E90,$4800,$4E7B,$C008,$6034,$600E,$4E7B,$B008,$0E90
	dc.w	$0800,$4E7B,$C008,$6012,$600E,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71
	dc.w	$4E71,$60B0,$4E7B,$6000,$4E7B,$6001,$46C7,$51C4,$60FF,$FFFF,$FD42
	dc.w	$4E7B,$6000,$4E7B,$6001,$46C7,$50C4,$60FF,$FFFF,$FD30,$51FC,$51FC
	dcb.w	4,$51FC
	dc.w	$4E7B,$A008,$0E91,$1000,$0E90,0,$6002,$600E,$B082,$662C,$B283,$6628
	dc.w	$0E91,$5800,$6002,$600E,$4844,$0E58,$4800,$4E7B,$B008,$4844,$6002
	dc.w	$600E,$0E50,$4800,$4E7B,$C008,$6000,$FFA8,$4E71,$600E,$4840,$0E58
	dc.w	$0800,$4E7B,$B008,$4840,$6002,$600E,$0E50,$0800,$4E7B,$C008,$6000
	dc.w	$FF76,$4E71,$600E,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$6090
	dc.w	$4E7B,$A008,$0E91,$1000,$0E90,0,$6002,$600E,$B082,$663C,$B283,$6638
	dc.w	$0E91,$5800,$6002,$600E,$E19C,$0E18,$4800,$4844,$0E58,$4800,$6002
	dc.w	$600E,$E19C,$4E7B,$B008,$0E10,$4800,$6004,$4E71,$600E,$4E7B,$C008
	dc.w	$6000,$FF2C,$4E71,$4E71,$4E71,$600E,$E198,$0E18,$0800,$4840,$0E58
	dc.w	$0800,$6002,$600E,$E198,$4E7B,$B008,$0E10,$0800,$6004,$4E71,$600E
	dc.w	$4E7B,$C008,$6000,$FEEA,$4E71,$4E71,$4E71,$600C,$4E71,$4E71,$4E71
	dcb.w	3,$4E71
	dc.w	$6000,$FF72,$2448,$2649,$2848,$2A49,$528C,$528D,$220A,$40C7,$007C
	dc.w	$0700,$4E7A,$6000,$4E7B,0,$4E7B,1,$F58A,$F58C,$F58B,$F58D,$F46A,$F46C
	dc.w	$F46B,$F46D,$2441,$5681,$2841,$F5CA,$F5CC,$247C,$8000,0,$267C,$A000,0
	dc.w	$287C,0,0,$2008,$0800,0,$6600,$009A,$6016,$51FC,$51FC,$51FC,$51FC
	dc.w	$4E7B,$A008,$0E51,$1000,$0E50,0,$6002,$600E,$B042,$661C,$B243,$6618
	dc.w	$0E51,$5800,$6002,$600E,$4E7B,$B008,$0E50,$4800,$4E7B,$C008,$6034
	dc.w	$600E,$4E7B,$B008,$0E50,$0800,$4E7B,$C008,$6012,$600E,$4E71,$4E71
	dcb.w	5,$4E71
	dc.w	$60B0,$4E7B,$6000,$4E7B,$6001,$46C7,$51C4,$60FF,$FFFF,$FB62,$4E7B
	dc.w	$6000,$4E7B,$6001,$46C7,$50C4,$60FF,$FFFF,$FB50,$51FC,$51FC,$51FC
	dcb.w	3,$51FC
	dc.w	$4E7B,$A008,$0E51,$1000,$0E50,0,$6002,$600E,$B042,$662C,$B243,$6628
	dc.w	$0E51,$5800,$6002,$600E,$E09C,$0E18,$4800,$4E7B,$B008,$E19C,$6002
	dc.w	$600E,$0E10,$4800,$4E7B,$C008,$6000,$FFA8,$4E71,$600E,$E098,$0E18
	dc.w	$0800,$4E7B,$B008,$E198,$6002,$600E,$0E10,$0800,$4E7B,$C008,$6000
	dc.w	$FF76,$4E71,$600E,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$6090
	dc.w	$4A06,$6604,$7001,$6002,$7005,$4A07,$6600,$00C6,$2248,$2448,$528A
	dc.w	$2602,$E04A,$40C7,$007C,$0700,$4E7A,$6000,$4E7B,0,$4E7B,1,$F589,$F58A
	dc.w	$F469,$F46A,$227C,$8000,0,$247C,$A000,0,$267C,0,0,$6016,$51FC,$51FC
	dcb.w	2,$51FC
	dc.w	$4E7B,$9008,$0E50,0,$B044,$6624,$6002,$600E,$0E18,$2800,$4E7B,$A008
	dc.w	$0E10,$3800,$6002,$600E,$4E7B,$B008,$604C,$4E71,$4E71,$4E71,$4E71
	dc.w	$600E,$E098,$0E18,$0800,$4E7B,$A008,$E198,$6002,$600E,$0E10,$0800
	dc.w	$4E7B,$B008,$6016,$4E71,$4E71,$600E,$4E71,$4E71,$4E71,$4E71,$4E71
	dcb.w	2,$4E71
	dc.w	$60A0,$4E7B,$6000,$4E7B,$6001,$46C7,$51C1,$60FF,$FFFF,$FB16,$4E7B
	dc.w	$6000,$4E7B,$6001,$46C7,$50C1,$60FF,$FFFF,$FB04,$2248,$2448,$568A
	dc.w	$2208,$0801,0,$6600,$00C2,$2602,$4842,$40C7,$007C,$0700,$4E7A,$6000
	dc.w	$4E7B,0,$4E7B,1,$F589,$F58A,$F469,$F46A,$227C,$8000,0,$247C,$A000,0
	dc.w	$267C,0,0,$6018,$51FC,$51FC,$51FC,$51FC,$51FC,$4E7B,$9008,$0E90,0
	dc.w	$B084,$6624,$6002,$600E,$0E58,$2800,$4E7B,$A008,$0E50,$3800,$6002
	dc.w	$600E,$4E7B,$B008,$604C,$4E71,$4E71,$4E71,$4E71,$600E,$4840,$0E58
	dc.w	$0800,$4840,$4E7B,$A008,$6002,$600E,$0E50,$0800,$4E7B,$B008,$6016
	dcb.w	2,$4E71
	dc.w	$600E,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$4E71,$60A0,$4E7B,$6000
	dc.w	$4E7B,$6001,$46C7,$51C1,$60FF,$FFFF,$FA46,$4E7B,$6000,$4E7B,$6001
	dc.w	$46C7,$50C1,$60FF,$FFFF,$FA34,$2A02,$E08A,$2602,$4842,$40C7,$007C
	dc.w	$0700,$4E7A,$6000,$4E7B,0,$4E7B,1,$F589,$F58A,$F469,$F46A,$227C,$8000
	dc.w	0,$247C,$A000,0,$267C,0,0,$6014,$51FC,$51FC,$51FC,$4E7B,$9008,$0E90,0
	dc.w	$B084,$6624,$6002,$600E,$0E18,$2800,$0E58,$3800,$4E7B,$A008,$6002
	dc.w	$600E,$0E10,$5800,$4E7B,$B008,$6000,$FF88,$4E71,$600E,$E198,$0E18
	dc.w	$0800,$4840,$0E58,$0800,$6002,$600E,$E198,$4E7B,$A008,$0E10,$0800
	dc.w	$6004,$4E71,$600E,$4E7B,$B008,$6000,$FF4A,$4E71,$4E71,$4E71,$600E
	dcb.w	7,$4E71
	dc.w	$6090,$4E71,$4E71,$4E71
Install_Int_Emulation_End:
	dc.w	$4425,$4833,$FBCC,$3290

; --------------------------------------------------------------------------
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

_060_dmem_write:	MOVE.L	A6,-(SP)
	MOVEA.L	(4).W,A6
	JSR	(_LVOCopyMem,A6)
	MOVEA.L	(SP)+,A6
	MOVEQ	#0,D1
	RTS

_060_imem_read:
_060_dmem_read:
	MOVE.L	A6,-(SP)
	MOVEA.L	(4).W,A6
	JSR	(_LVOCopyMem,A6)
	MOVEA.L	(SP)+,A6
	MOVEQ	#0,D1
	RTS

_060_dmem_read_byte:
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	MOVEQ	#0,D1
	RTS

_060_dmem_read_word:
	MOVEQ	#0,D0
	MOVE.W	(A0),D0
	MOVEQ	#0,D1
	RTS

_060_dmem_read_long:
	MOVE.L	(A0),D0
	MOVEQ	#0,D1
	RTS

_060_dmem_write_byte:
	MOVE.B	D0,(A0)
	MOVEQ	#0,D1
	RTS

_060_dmem_write_word:
	MOVE.W	D0,(A0)
	MOVEQ	#0,D1
	RTS

_060_dmem_write_long:
	MOVE.L	D0,(A0)
	MOVEQ	#0,D1
	RTS

_060_imem_read_word:
	MOVE.W	(A0),D0
	MOVEQ	#0,D1
	RTS

_060_imem_read_long:
	MOVE.L	(A0),D0
	MOVEQ	#0,D1
	RTS

_060_real_trace3:	RTE

_060_real_access3:	RTE

;fiX Label expected
	NOP
	NOP
	NOP
Install_Mem_Library_End:
	dc.l	$3A34967C,$B28A2422

;fiX Bad code terminator
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
Install_Exec_Patches_End:
	dc.l	$4479F681,$174003D2

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

;fiX Label expected
	NOP
	NOP
	NOP
Install_Caches_End:	dc.l	$6A845C87,$B404DAB7

;fiX Bad code terminator
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

;fiX Label expected
	dc.w	0
RomTagEnd:
	dc.l	$4E710000
	dc.w	$4E71


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
