
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: 68060.library.asm,v 1.2 1996/06/09 18:14:28 schlote Exp schlote $
**
**
	include	68060.library.i

	SECTION	68060library_newrs000000,CODE
ProgStart:	MOVEQ	#-1,D0
	RTS

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


Install_FPU_Libraries:
	LEA	(_060FPLSP_TOP,PC),A0
	MOVE.L	A0,($0072,A6)
	LEA	(_060ILSP_TOP,PC),A0
	MOVE.L	A0,($0076,A6)
	RTS

_060FPLSP_TOP:	dc.w	$60FF,0,$238E,0,$60FF,0,$2420,0,$60FF,0,$24B6,0,$60FF,0,$1106,0,$60FF
	dc.w	0,$1198,0,$60FF,0,$122E,0,$60FF,0,$0F16,0,$60FF,0,$0FA8,0,$60FF,0
	dc.w	$103E,0,$60FF,0,$12AE,0,$60FF,0,$1340,0,$60FF,0,$13D6,0,$60FF,0,$05AE
	dc.w	0,$60FF,0,$0640,0,$60FF,0,$06D6,0,$60FF,0,$213E,0,$60FF,0,$21D0,0
	dc.w	$60FF,0,$2266,0,$60FF,0,$1616,0,$60FF,0,$16A8,0,$60FF,0,$173E,0,$60FF
	dc.w	0,$0AEE,0,$60FF,0,$0B80,0,$60FF,0,$0C16,0,$60FF,0,$24A6,0,$60FF,0
	dc.w	$2538,0,$60FF,0,$25CE,0,$60FF,0,$2666,0,$60FF,0,$26F8,0,$60FF,0,$278E
	dc.w	0,$60FF,0,$1D16,0,$60FF,0,$1DA8,0,$60FF,0,$1E3E,0,$60FF,0,$1ED6,0
	dc.w	$60FF,0,$1F68,0,$60FF,0,$1FFE,0,$60FF,0,$1B0E,0,$60FF,0,$1BA0,0,$60FF
	dc.w	0,$1C36,0,$60FF,0,$0886,0,$60FF,0,$0918,0,$60FF,0,$09AE,0,$60FF,0
	dc.w	$2BF0,0,$60FF,0,$2CA4,0,$60FF,0,$2D58,0,$60FF,0,$2998,0,$60FF,0,$2A4C
	dc.w	0,$60FF,0,$2B00,0,$60FF,0,$2E00,0,$60FF,0,$2EB4,0,$60FF,0,$2F68,0
	dc.w	$60FF,0,$029E,0,$60FF,0,$0330,0,$60FF,0,$03C6,0,$60FF,0,$2766,0,$60FF
	dc.w	0,$27FE,0,$60FF,0,$289A,0,$60FF,0,$061E,0,$60FF,0,$06B0,0,$60FF,0
	dc.w	$0746,0,$60FF,0,$12EE,0,$60FF,0,$1380,0,$60FF,0,$1416,0,$60FF,0,$0B76
	dc.w	0,$60FF,0,$0C08,0,$60FF,0,$0C9E,0,$60FF,0,$1846,0,$60FF,0,$18D8,0
	dc.w	$60FF,0,$196E,0,$60FF,0,$1656,0,$60FF,0,$16E8,0,$60FF,0,$177E,0,$60FF
	dc.w	0,$72FE,0,$60FF,0,$72FE,0,$60FF,0,$72FE,0,$60FF,0,$71BE,0,$60FF,0
	dc.w	$71D4,0,$60FF,0,$71EA,0,$60FF,0,$7284,0,$60FF,0,$729A,0,$60FF,0,$72B0
	dc.w	0,$60FF,0,$72FE,0,$60FF,0,$72FE,0,$60FF,0,$72FE,0,$60FF,0,$72FE,0
	dc.w	$60FF,0,$72FE,0,$60FF,0,$72FE,0,$60FF,0,$71F2,0,$60FF,0,$7208,0,$60FF
	dc.w	0,$721E,0,$60FF,0,$7286,0,$60FF,0,$7286,0,$60FF,0,$7286,0,$60FF,0
	dc.w	$7286,0,$60FF,0,$7286,0,$60FF,0,$7286,0,$60FF,0,$7160,0,$60FF,0,$7176
	dc.w	0,$60FF,0,$718C,0,$51FC,$51FC,$51FC,$51FC,$51FC,$51FC,$51FC,$51FC
	dcb.w	$0000003F,$51FC
	dcb.w	$0000002D,$51FC
	dc.w	$40C6,$2D38,$D3D6,$4634,$3D6F,$90AE,$B1E7,$5CC7,$4000,0,$C90F,$DAA2
	dc.w	$2168,$C235,0,0,$3FFF,0,$C90F,$DAA2,$2168,$C235,0,0,$3FE4,$5F30,$6DC9
	dc.w	$C883,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$6C76,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$4A01,$6608,$61FF,0,$2DDC,$6030,$0C01,1,$6608,$61FF,0,$7124
	dc.w	$6022,$0C01,2,$6608,$61FF,0,$6D22,$6014,$0C01,3,$6608,$61FF,0,$6F4C
	dc.w	$6006,$61FF,0,$2F8E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040
	dc.w	$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60
	dc.w	$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C
	dc.w	$41EE,$FF6C,$61FF,0,$6BDC,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64
	dc.w	$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$2D3E,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$7086,$6022,$0C01,2,$6608,$61FF,0,$6C84,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$6EAE,$6006,$61FF,0,$2EF0,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E
	dc.w	8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$6B38,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$2C9E,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$6FE6,$6022,$0C01,2,$6608,$61FF,0,$6BE4,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$6E0E,$6006,$61FF,0,$2E50,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$6A9E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$2C0E,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$6FC8,$6022,$0C01,2,$6608,$61FF,0,$6B4A,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$6D74,$6006,$61FF,0,$2DBC,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$6A04,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$2B70,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$6F2A,$6022,$0C01,2,$6608,$61FF,0,$6AAC,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$6CD6,$6006,$61FF,0,$2D1E,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$6960,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$2AD0,$6030,$0C01,1,$6608,$61FF,0,$6E8A,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$6A0C,$6014,$0C01,3,$6608,$61FF,0,$6C36,$6006,$61FF,0,$2C7E,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$68C6
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$4E68,$6030,$0C01,1,$6608,$61FF,0,$6D74,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$6D94,$6014,$0C01,3,$6608,$61FF,0,$6B9C,$6006,$61FF,0
	dc.w	$4F14,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$682C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$4DCA,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$6CD6,$6022,$0C01,2,$6608,$61FF,0,$6CF6,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$6AFE,$6006,$61FF,0,$4E76,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$6788,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$4D2A,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$6C36,$6022,$0C01,2,$6608,$61FF,0,$6C56,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$6A5E,$6006,$61FF,0,$4DD6,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$66EE,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$59B2,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$6B9C,$6022,$0C01,2,$6608,$61FF,0,$6BF2,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$69C4,$6006,$61FF,0,$5AD4,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$6654,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$5914,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$6AFE,$6022,$0C01,2,$6608,$61FF,0,$6B54,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$6926,$6006,$61FF,0,$5A36,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$65B0,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$5874,$6030,$0C01,1,$6608,$61FF,0,$6A5E,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$6AB4,$6014,$0C01,3,$6608,$61FF,0,$6886,$6006,$61FF,0,$5996,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$6516
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$46C4,$6030,$0C01,1,$6608,$61FF,0,$69C4,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$6A24,$6014,$0C01,3,$6608,$61FF,0,$67EC,$6006,$61FF,0
	dc.w	$4948,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$647C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$4626,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$6926,$6022,$0C01,2,$6608,$61FF,0,$6986,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$674E,$6006,$61FF,0,$48AA,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$63D8,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$4586,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$6886,$6022,$0C01,2,$6608,$61FF,0,$68E6,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$66AE,$6006,$61FF,0,$480A,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$633E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$49C4,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$67EC,$6022,$0C01,2,$6608,$61FF,0,$6854,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$6614,$6006,$61FF,0,$4AFA,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$62A4,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$4926,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$674E,$6022,$0C01,2,$6608,$61FF,0,$67B6,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$6576,$6006,$61FF,0,$4A5C,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$6200,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$4886,$6030,$0C01,1,$6608,$61FF,0,$66AE,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$6716,$6014,$0C01,3,$6608,$61FF,0,$64D6,$6006,$61FF,0,$49BC,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$6166
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$391C,$6030,$0C01,1,$6608,$61FF,0,$6614,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$66B8,$6014,$0C01,3,$6608,$61FF,0,$643C,$6006,$61FF,0
	dc.w	$3B28,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$60CC,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$387E,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$6576,$6022,$0C01,2,$6608,$61FF,0,$661A,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$639E,$6006,$61FF,0,$3A8A,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$6028,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$37DE,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$64D6,$6022,$0C01,2,$6608,$61FF,0,$657A,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$62FE,$6006,$61FF,0,$39EA,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5F8E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$3988,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$643C,$6022,$0C01,2,$6608,$61FF,0,$603A,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$6264,$6006,$61FF,0,$3A04,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5EF4,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$38EA,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$639E,$6022,$0C01,2,$6608,$61FF,0,$5F9C,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$61C6,$6006,$61FF,0,$3966,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$5E50,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$384A,$6030,$0C01,1,$6608,$61FF,0,$62FE,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$5EFC,$6014,$0C01,3,$6608,$61FF,0,$6126,$6006,$61FF,0,$38C6,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5DB6
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$51D4,$6030,$0C01,1,$6608,$61FF,0,$6264,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$5E62,$6014,$0C01,3,$6608,$61FF,0,$608C,$6006,$61FF,0
	dc.w	$5224,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$5D1C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$5136,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$61C6,$6022,$0C01,2,$6608,$61FF,0,$5DC4,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$5FEE,$6006,$61FF,0,$5186,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$5C78,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$5096,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$6126,$6022,$0C01,2,$6608,$61FF,0,$5D24,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$5F4E,$6006,$61FF,0,$50E6,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5BDE,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$2806,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$608C,$6022,$0C01,2,$6608,$61FF,0,$5C8A,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$5EB4,$6006,$61FF,0,$2938,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5B44,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$2768,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$5FEE,$6022,$0C01,2,$6608,$61FF,0,$5BEC,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$5E16,$6006,$61FF,0,$289A,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$5AA0,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$26C8,$6030,$0C01,1,$6608,$61FF,0,$5F4E,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$5B4C,$6014,$0C01,3,$6608,$61FF,0,$5D76,$6006,$61FF,0,$27FA,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5A06
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$39E4,$6030,$0C01,1,$6608,$61FF,0,$5F30,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$5F02,$6014,$0C01,3,$6608,$61FF,0,$5CDC,$6006,$61FF,0
	dc.w	$3B5E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$596C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$3946,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$5E92,$6022,$0C01,2,$6608,$61FF,0,$5E64,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$5C3E,$6006,$61FF,0,$3AC0,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$58C8,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$38A6,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$5DF2,$6022,$0C01,2,$6608,$61FF,0,$5DC4,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$5B9E,$6006,$61FF,0,$3A20,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$582E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$522E,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$5D58,$6022,$0C01,2,$6608,$61FF,0,$5D2A,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$5B04,$6006,$61FF,0,$52D6,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5794,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$5190,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$5CBA,$6022,$0C01,2,$6608,$61FF,0,$5C8C,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$5A66,$6006,$61FF,0,$5238,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$56F0,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$50F0,$6030,$0C01,1,$6608,$61FF,0,$5C1A,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$5BEC,$6014,$0C01,3,$6608,$61FF,0,$59C6,$6006,$61FF,0,$5198,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5656
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$514E,$6030,$0C01,1,$6608,$61FF,0,$5B80,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$5B52,$6014,$0C01,3,$6608,$61FF,0,$592C,$6006,$61FF,0
	dc.w	$524C,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$55BC,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$50B0,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$5AE2,$6022,$0C01,2,$6608,$61FF,0,$5AB4,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$588E,$6006,$61FF,0,$51AE,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$5518,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$5010,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$5A42,$6022,$0C01,2,$6608,$61FF,0,$5A14,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$57EE,$6006,$61FF,0,$510E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$547E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$4502,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$54C8,$6022,$0C01,2,$6608,$61FF,0,$5982,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$5754,$6006,$61FF,0,$4682,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$53E4,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$4464,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$542A,$6022,$0C01,2,$6608,$61FF,0,$58E4,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$56B6,$6006,$61FF,0,$45E4,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$5340,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$43C4,$6030,$0C01,1,$6608,$61FF,0,$538A,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$5844,$6014,$0C01,3,$6608,$61FF,0,$5616,$6006,$61FF,0,$4544,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$52A6
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$476C,$6030,$0C01,1,$6608,$61FF,0,$52F0,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$57AA,$6014,$0C01,3,$6608,$61FF,0,$557C,$6006,$61FF,0
	dc.w	$476A,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$520C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$46CE,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$5252,$6022,$0C01,2,$6608,$61FF,0,$570C,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$54DE,$6006,$61FF,0,$46CC,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$5168,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$462E,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$51B2,$6022,$0C01,2,$6608,$61FF,0,$566C,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$543E,$6006,$61FF,0,$462C,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$50CE,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$45E4,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$5118,$6022,$0C01,2,$6608,$61FF,0,$55D2,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$53A4,$6006,$61FF,0,$460C,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$5034,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$4546,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$507A,$6022,$0C01,2,$6608,$61FF,0,$5534,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$5306,$6006,$61FF,0,$456E,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$4F90,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$44A6,$6030,$0C01,1,$6608,$61FF,0,$4FDA,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$5494,$6014,$0C01,3,$6608,$61FF,0,$5266,$6006,$61FF,0,$44CE,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4EF6
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$33DA,$6030,$0C01,1,$6608,$61FF,0,$5420,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$53CA,$6014,$0C01,3,$6608,$61FF,0,$51CC,$6006,$61FF,0
	dc.w	$344C,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$4E5C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$333C,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$5382,$6022,$0C01,2,$6608,$61FF,0,$532C,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$512E,$6006,$61FF,0,$33AE,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$4DB8,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$329C,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$52E2,$6022,$0C01,2,$6608,$61FF,0,$528C,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$508E,$6006,$61FF,0,$330E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4D1E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$27CC,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$5284,$6022,$0C01,2,$6608,$61FF,0,$4DCA,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$4FF4,$6006,$61FF,0,$282A,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4C84,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$272E,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$51E6,$6022,$0C01,2,$6608,$61FF,0,$4D2C,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$4F56,$6006,$61FF,0,$278C,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$4BE0,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$268E,$6030,$0C01,1,$6608,$61FF,0,$5146,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$4C8C,$6014,$0C01,3,$6608,$61FF,0,$4EB6,$6006,$61FF,0,$26EC,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4B46
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$2FB0,$6030,$0C01,1,$6608,$61FF,0,$4FF4,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$4BF2,$6014,$0C01,3,$6608,$61FF,0,$4E1C,$6006,$61FF,0
	dc.w	$2F9A,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E
	dc.w	$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0
	dc.w	$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF6C,$41EE,$FF6C
	dc.w	$61FF,0,$4AAC,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$2F12,$6030,$0C01,1,$6608,$61FF
	dc.w	0,$4F56,$6022,$0C01,2,$6608,$61FF,0,$4B54,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$4D7E,$6006,$61FF,0,$2EFC,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$4A08,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$2E72,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$4EB6,$6022,$0C01,2,$6608,$61FF,0,$4AB4,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$4CDE,$6006,$61FF,0,$2E5C,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF6C,$41EE,$FF6C,$61FF,0,$496E,$1D40,$FF4E,$1200,$02AE,$00FF
	dc.w	$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0,$2E0C,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$4E1C,$6022,$0C01,2,$6608,$61FF,0,$4A1A,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$4C44,$6006,$61FF,0,$2E08,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C
	dc.w	$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$48D4,$1D40,$FF4E,$1200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$2D6E,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$4D7E,$6022,$0C01,2,$6608,$61FF,0,$497C,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$4BA6,$6006,$61FF,0,$2D6A,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE
	dc.w	$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE
	dc.w	$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0,$4830,$1D40,$FF4E
	dc.w	$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01,$6608,$61FF,0
	dc.w	$2CCE,$6030,$0C01,1,$6608,$61FF,0,$4CDE,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$48DC,$6014,$0C01,3,$6608,$61FF,0,$4B06,$6006,$61FF,0,$2CCA,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4796
	dc.w	$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$4A01
	dc.w	$6608,$61FF,0,$0AF4,$6030,$0C01,1,$6608,$61FF,0,$4D18,$6022,$0C01,2
	dc.w	$6608,$61FF,0,$4D38,$6014,$0C01,3,$6608,$61FF,0,$4D34,$6006,$61FF,0
	dc.w	$0D58,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F227,$E003,$F21F,$D040
	dc.w	$F21F,$D080,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E,$6800
	dc.w	$FF6C,$41EE,$FF6C,$61FF,0,$46F6,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$1D41,$FF4E,$4A01,$6608,$61FF,0,$0A50,$6030
	dc.w	$0C01,1,$6608,$61FF,0,$4C74,$6022,$0C01,2,$6608,$61FF,0,$4C94,$6014
	dc.w	$0C01,3,$6608,$61FF,0,$4C90,$6006,$61FF,0,$0CB4,$4CEE,$0303,$FF9C
	dc.w	$F22E,$9800,$FF60,$F227,$E003,$F21F,$D040,$F21F,$D080,$4E5E,$4E75
	dc.w	$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC
	dc.w	$F23C,$9000,0,0,$41EE,$FF6C,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF
	dc.w	0,$464C,$1D40,$FF4E,$1200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63
	dc.w	$4A01,$6608,$61FF,0,$09AA,$6030,$0C01,1,$6608,$61FF,0,$4BCE,$6022
	dc.w	$0C01,2,$6608,$61FF,0,$4BEE,$6014,$0C01,3,$6608,$61FF,0,$4BEA,$6006
	dc.w	$61FF,0,$0C0E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F227,$E003,$F21F
	dc.w	$D040,$F21F,$D080,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E
	dc.w	$6800,$FF78,$41EE,$FF78,$61FF,0,$45AC,$1D40,$FF4F,$F22E,$4400,12
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4592,$1D40,$FF4E,$2200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0
	dc.w	$4C46,$6030,$0C01,1,$6608,$61FF,0,$4C64,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$4C84,$6014,$0C01,3,$6608,$61FF,0,$4D16,$6006,$61FF,0,$4C14,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$5400,8,$F22E,$6800,$FF78,$41EE,$FF78,$61FF,0,$44F0
	dc.w	$1D40,$FF4F,$F22E,$5400,$0010,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0
	dc.w	$44D6,$1D40,$FF4E,$2200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63
	dc.w	$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0,$4B8A,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$4BA8,$6022,$0C01,2,$6608,$61FF,0,$4BC8,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$4C5A,$6006,$61FF,0,$4B58,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF78,$216E,8,0
	dc.w	$216E,12,4,$216E,$0010,8,$61FF,0,$442E,$1D40,$FF4F,$41EE,$FF6C,$216E
	dc.w	$0014,0,$216E,$0018,4,$216E,$001C,8,$61FF,0,$440E,$1D40,$FF4E,$2200
	dc.w	$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$41EE,$FF6C,$43EE,$FF78
	dc.w	$4A01,$6608,$61FF,0,$4AC2,$6030,$0C01,1,$6608,$61FF,0,$4AE0,$6022
	dc.w	$0C01,2,$6608,$61FF,0,$4B00,$6014,$0C01,3,$6608,$61FF,0,$4B92,$6006
	dc.w	$61FF,0,$4A90,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8
	dc.w	$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E
	dc.w	$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF78,$41EE
	dc.w	$FF78,$61FF,0,$436C,$1D40,$FF4F,$F22E,$4400,12,$F22E,$6800,$FF6C
	dc.w	$41EE,$FF6C,$61FF,0,$4352,$1D40,$FF4E,$2200,$02AE,$00FF,$00FF,$FF64
	dc.w	$4280,$102E,$FF63,$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0,$491C
	dc.w	$6030,$0C01,1,$6608,$61FF,0,$493A,$6022,$0C01,2,$6608,$61FF,0,$495A
	dc.w	$6014,$0C01,3,$6608,$61FF,0,$4AD6,$6006,$61FF,0,$48EA,$4CEE,$0303
	dc.w	$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40
	dc.w	$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0
	dc.w	$F22E,$5400,8,$F22E,$6800,$FF78,$41EE,$FF78,$61FF,0,$42B0,$1D40,$FF4F
	dc.w	$F22E,$5400,$0010,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4296,$1D40
	dc.w	$FF4E,$2200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63,$41EE,$FF6C
	dc.w	$43EE,$FF78,$4A01,$6608,$61FF,0,$4860,$6030,$0C01,1,$6608,$61FF,0
	dc.w	$487E,$6022,$0C01,2,$6608,$61FF,0,$489E,$6014,$0C01,3,$6608,$61FF,0
	dc.w	$4A1A,$6006,$61FF,0,$482E,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60,$F22E
	dc.w	$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E,$B800
	dc.w	$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$41EE,$FF78,$216E,8,0,$216E
	dc.w	12,4,$216E,$0010,8,$61FF,0,$41EE,$1D40,$FF4F,$41EE,$FF6C,$216E,$0014
	dc.w	0,$216E,$0018,4,$216E,$001C,8,$61FF,0,$41CE,$1D40,$FF4E,$2200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0
	dc.w	$4798,$6030,$0C01,1,$6608,$61FF,0,$47B6,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$47D6,$6014,$0C01,3,$6608,$61FF,0,$4952,$6006,$61FF,0,$4766,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$F22E,$4400,8,$F22E,$6800,$FF78,$41EE,$FF78,$61FF,0,$412C
	dc.w	$1D40,$FF4F,$F22E,$4400,12,$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0
	dc.w	$4112,$1D40,$FF4E,$2200,$02AE,$00FF,$00FF,$FF64,$4280,$102E,$FF63
	dc.w	$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0,$484A,$6030,$0C01,1,$6608
	dc.w	$61FF,0,$486A,$6022,$0C01,2,$6608,$61FF,0,$488A,$6014,$0C01,3,$6608
	dc.w	$61FF,0,$4896,$6006,$61FF,0,$4818,$4CEE,$0303,$FF9C,$F22E,$9800,$FF60
	dc.w	$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56,$FF40,$48EE,$0303,$FF9C,$F22E
	dc.w	$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C,$9000,0,0,$F22E,$5400,8,$F22E
	dc.w	$6800,$FF78,$41EE,$FF78,$61FF,0,$4070,$1D40,$FF4F,$F22E,$5400,$0010
	dc.w	$F22E,$6800,$FF6C,$41EE,$FF6C,$61FF,0,$4056,$1D40,$FF4E,$2200,$02AE
	dcb.w	2,$00FF
	dc.w	$FF64,$4280,$102E,$FF63,$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0
	dc.w	$478E,$6030,$0C01,1,$6608,$61FF,0,$47AE,$6022,$0C01,2,$6608,$61FF,0
	dc.w	$47CE,$6014,$0C01,3,$6608,$61FF,0,$47DA,$6006,$61FF,0,$475C,$4CEE
	dc.w	$0303,$FF9C,$F22E,$9800,$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$4E56
	dc.w	$FF40,$48EE,$0303,$FF9C,$F22E,$B800,$FF60,$F22E,$F0C0,$FFDC,$F23C
	dc.w	$9000,0,0,$41EE,$FF78,$216E,8,0,$216E,12,4,$216E,$0010,8,$61FF,0
	dc.w	$3FAE,$1D40,$FF4F,$41EE,$FF6C,$216E,$0014,0,$216E,$0018,4,$216E,$001C
	dc.w	8,$61FF,0,$3F8E,$1D40,$FF4E,$2200,$02AE,$00FF,$00FF,$FF64,$4280,$102E
	dc.w	$FF63,$41EE,$FF6C,$43EE,$FF78,$4A01,$6608,$61FF,0,$46C6,$6030,$0C01,1
	dc.w	$6608,$61FF,0,$46E6,$6022,$0C01,2,$6608,$61FF,0,$4706,$6014,$0C01,3
	dc.w	$6608,$61FF,0,$4712,$6006,$61FF,0,$4694,$4CEE,$0303,$FF9C,$F22E,$9800
	dc.w	$FF60,$F22E,$D040,$FFE8,$4E5E,$4E75,$BD6A,$AA77,$CCC9,$94F5,$3DE6
	dc.w	$1209,$7AAE,$8DA1,$BE5A,$E645,$2A11,$8AE4,$3EC7,$1DE3,$A534,$1531
	dc.w	$BF2A,$01A0,$1A01,$8B59,0,0,0,0,$3FF8,0,$8888,$8888,$8888,$59AF,0,0
	dc.w	$BFFC,0,$AAAA,$AAAA,$AAAA,$AA99,0,0,$3D2A,$C4D0,$D601,$1EE3,$BDA9
	dc.w	$396F,$9F45,$AC19,$3E21,$EED9,$0612,$C972,$BE92,$7E4F,$B79D,$9FCF
	dc.w	$3EFA,$01A0,$1A01,$D423,0,0,0,0,$BFF5,0,$B60B,$60B6,$0B61,$D438,0,0
	dc.w	$3FFA,0,$AAAA,$AAAA,$AAAA,$AB5E,$BF00,0,$2D7C,0,0,$FF5C,$6008,$2D7C,0
	dc.w	1,$FF5C,$F210,$4800,$F22E,$6800,$FF84,$2210,$3228,4,$0281,$7FFF,$FFFF
	dc.w	$0C81,$3FD7,$8000,$6C04,$6000,$0178,$0C81,$4004,$BC7E,$6D04,$6000
	dc.w	$0468,$F200,$0080,$F23A,$54A3,$D186,$43FB,$0170,0,$0866,$F22E,$6080
	dc.w	$FF58,$222E,$FF58,$E981,$D3C1,$F219,$4828,$F211,$4428,$222E,$FF58
	dc.w	$D2AE,$FF5C,$E299,$0C81,0,0,$6D00,$0088,$F227,$E00C,$F22E,$6800,$FF84
	dc.w	$F200,$0023,$F23A,$5580,$FED2,$F23A,$5500,$FED4,$F200,$0080,$F200
	dc.w	$04A3,$E299,$0281,$8000,0,$B3AE,$FF84,$F200,$05A3,$F200,$0523,$F23A
	dc.w	$55A2,$FEBA,$F23A,$5522,$FEBC,$F200,$05A3,$F200,$0523,$F23A,$55A2
	dc.w	$FEB6,$F23A,$4922,$FEC0,$F200,$0CA3,$F200,$0123,$F23A,$48A2,$FEC2
	dc.w	$F22E,$4823,$FF84,$F200,$08A2,$F200,$0423,$F21F,$D030,$F200,$9000
	dc.w	$F22E,$4822,$FF84,$60FF,0,$4006,$F227,$E00C,$F200,$0023,$F23A,$5500
	dc.w	$FEA2,$F23A,$5580,$FEA4,$F200,$0080,$F200,$04A3,$F22E,$6800,$FF84
	dc.w	$E299,$0281,$8000,0,$F200,$0523,$B3AE,$FF84,$0281,$8000,0,$F200,$05A3
	dc.w	$0081,$3F80,0,$2D41,$FF54,$F23A,$5522,$FE74,$F23A,$55A2,$FE76,$F200
	dc.w	$0523,$F200,$05A3,$F23A,$5522,$FE70,$F23A,$49A2,$FE7A,$F200,$0523
	dc.w	$F200,$0CA3,$F23A,$4922,$FE7C,$F23A,$44A2,$FE82,$F200,$0823,$F200
	dc.w	$0422,$F22E,$4823,$FF84,$F21F,$D030,$F200,$9000,$F22E,$4422,$FF54
	dc.w	$60FF,0,$3F6A,$0C81,$3FFF,$8000,$6EFF,0,$0300,$222E,$FF5C,$0C81,0,0
	dc.w	$6E14,$F200,$9000,$123C,3,$F22E,$4800,$FF84,$60FF,0,$3F36,$F23C,$4400
	dc.w	$3F80,0,$F200,$9000,$F23C,$4422,$8080,0,$60FF,0,$3F2C,$60FF,0,$3F64
	dc.w	$F23C,$4400,$3F80,0,$60FF,0,$3F18,$2D7C,0,4,$FF5C,$F210,$4800,$F22E
	dc.w	$6800,$FF84,$2210,$3228,4,$0281,$7FFF,$FFFF,$0C81,$3FD7,$8000,$6C04
	dc.w	$6000,$0240,$0C81,$4004,$BC7E,$6D04,$6000,$027A,$F200,$0080,$F23A
	dc.w	$54A3,$CF98,$43FB,$0170,0,$0678,$F22E,$6080,$FF58,$222E,$FF58,$E981
	dc.w	$D3C1,$F219,$4828,$F211,$4428,$222E,$FF58,$E299,$0C81,0,0,$6C00,$0106
	dc.w	$F227,$E004,$F22E,$6800,$FF84,$F200,$0023,$F23A,$5480,$FCE8,$F23A
	dc.w	$5500,$FD32,$F200,$00A3,$F200,$0123,$2F02,$2401,$E29A,$0282,$8000,0
	dc.w	$B382,$0282,$8000,0,$F23A,$54A2,$FCC8,$F23A,$5522,$FD12,$F200,$00A3
	dc.w	$B5AE,$FF84,$241F,$F200,$0123,$E299,$0281,$8000,0,$2D7C,$3F80,0,$FF54
	dc.w	$B3AE,$FF54,$F23A,$54A2,$FCA2,$F23A,$5522,$FCEC,$F200,$00A3,$F200
	dc.w	$0123,$F22E,$6800,$FF90,$F23A,$54A2,$FC90,$B3AE,$FF90,$F23A,$5522
	dc.w	$FCD6,$F200,$00A3,$F200,$0123,$F23A,$54A2,$FC80,$F23A,$5522,$FCCA
	dc.w	$F200,$00A3,$F200,$0123,$F23A,$48A2,$FC7C,$F23A,$4922,$FCC6,$F200
	dc.w	$00A3,$F200,$0123,$F23A,$48A2,$FC78,$F23A,$4922,$FCC2,$F200,$00A3
	dc.w	$F200,$0823,$F22E,$48A3,$FF84,$F23A,$4422,$FCBA,$F22E,$4823,$FF90
	dc.w	$F21F,$D020,$F200,$9000,$F22E,$48A2,$FF84,$61FF,0,$3E22,$F22E,$4422
	dc.w	$FF54,$60FF,0,$3D9E,$F227,$E004,$F22E,$6800,$FF84,$F200,$0023,$F23A
	dc.w	$5480,$FC34,$F23A,$5500,$FBDE,$F200,$00A3,$F22E,$6800,$FF90,$F200
	dc.w	$0123,$E299,$0281,$8000,0,$F23A,$54A2,$FC1A,$F23A,$5522,$FBC4,$B3AE
	dc.w	$FF84,$B3AE,$FF90,$F200,$00A3,$0081,$3F80,0,$2D41,$FF54,$F200,$0123
	dc.w	$F23A,$54A2,$FBFC,$F23A,$5522,$FBA6,$F200,$00A3,$F200,$0123,$F23A
	dc.w	$54A2,$FBF0,$F23A,$5522,$FB9A,$F200,$00A3,$F200,$0123,$F23A,$54A2
	dc.w	$FBE4,$F23A,$5522,$FB8E,$F200,$00A3,$F200,$0123,$F23A,$48A2,$FBE0
	dc.w	$F23A,$4922,$FB8A,$F200,$00A3,$F200,$0123,$F23A,$48A2,$FBDC,$F23A
	dc.w	$4922,$FB86,$F200,$00A3,$F200,$0823,$F23A,$44A2,$FBD4,$F22E,$4823
	dc.w	$FF84,$F22E,$48A3,$FF90,$F21F,$D020,$F200,$9000,$F22E,$44A2,$FF54
	dc.w	$61FF,0,$3D36,$F22E,$4822,$FF84,$60FF,0,$3CB2,$0C81,$3FFF,$8000,$6E00
	dc.w	$0048,$F23C,$4480,$3F80,0,$F200,$9000,$F23C,$44A8,$0080,0,$61FF,0
	dc.w	$3D06,$F200,$B000,$123C,3,$F22E,$4800,$FF84,$60FF,0,$3C72,$2F00,$F23C
	dc.w	$4480,$3F80,0,$61FF,0,$3CE2,$201F,$60FF,0,$3CA8,$F227,$E03C,$2F02
	dc.w	$F23C,$4480,0,0,$0C81,$7FFE,$FFFF,$6652,$3D7C,$7FFE,$FF84,$2D7C,$C90F
	dc.w	$DAA2,$FF88,$42AE,$FF8C,$3D7C,$7FDC,$FF90,$2D7C,$85A3,$08D3,$FF94
	dc.w	$42AE,$FF98,$F200,$003A,$F294,14,$002E,$0080,$FF84,$002E,$0080,$FF90
	dc.w	$F22E,$4822,$FF84,$F200,$0080,$F22E,$4822,$FF90,$F200,$00A8,$F22E
	dc.w	$48A2,$FF90,$F22E,$6800,$FF84,$322E,$FF84,$2241,$0281,0,$7FFF,$0481,0
	dc.w	$3FFF,$0C81,0,$001C,$6F0E,$0481,0,$001B,$1D7C,0,$FF58,$6008,$4281
	dc.w	$1D7C,1,$FF58,$243C,0,$3FFE,$9481,$2D7C,$A2F9,$836E,$FF88,$2D7C,$4E44
	dc.w	$152A,$FF8C,$3D42,$FF84,$F200,$0100,$F22E,$4923,$FF84,$2409,$4842
	dc.w	$0282,$8000,0,$0082,$5F00,0,$2D42,$FF54,$F22E,$4522,$FF54,$F22E,$4528
	dc.w	$FF54,$2401,$0682,0,$3FFF,$3D42,$FF84,$2D7C,$C90F,$DAA2,$FF88,$42AE
	dc.w	$FF8C,$0681,0,$3FDD,$3D41,$FF90,$2D7C,$85A3,$08D3,$FF94,$42AE,$FF98
	dc.w	$122E,$FF58,$F200,$0A00,$F22E,$4A23,$FF84,$F200,$0A80,$F22E,$4AA3
	dc.w	$FF90,$F200,$1180,$F200,$15A2,$F200,$0E28,$F200,$0C28,$F200,$1622
	dc.w	$F200,$0180,$F200,$10A8,$F200,$0422,$0C01,0,$6E00,14,$F200,$01A8
	dc.w	$F200,$0CA2,$6000,$FF0C,$F22E,$6100,$FF58,$241F,$F21F,$D03C,$222E
	dc.w	$FF5C,$0C81,0,4,$6D00,$FA4C,$6000,$FC36,$3EA0,$B759,$F50F,$8688,$BEF2
	dc.w	$BAA5,$A892,$4F04,$BF34,$6F59,$B39B,$A65F,0,0,0,0,$3FF6,0,$E073,$D3FC
	dc.w	$199C,$4A00,0,0,$3FF9,0,$D23C,$D684,$15D9,$5FA1,0,0,$BFFC,0,$8895
	dc.w	$A6C5,$FB42,$3BCA,0,0,$BFFD,0,$EEF5,$7E0D,$A84B,$C8CE,0,0,$3FFC,0
	dc.w	$A2F9,$836E,$4E44,$152A,0,0,$4001,0,$C90F,$DAA2,0,0,0,0,$3FDF,0,$85A3
	dc.w	$08D4,0,0,0,0,$C004,0,$C90F,$DAA2,$2168,$C235,$2180,0,$C004,0,$C2C7
	dc.w	$5BCD,$105D,$7C23,$A0D0,0,$C004,0,$BC7E,$DCF7,$FF52,$3611,$A1E8,0
	dc.w	$C004,0,$B636,$5E22,$EE46,$F000,$2148,0,$C004,0,$AFED,$DF4D,$DD3B
	dc.w	$A9EE,$A120,0,$C004,0,$A9A5,$6078,$CC30,$63DD,$21FC,0,$C004,0,$A35C
	dc.w	$E1A3,$BB25,$1DCB,$2110,0,$C004,0,$9D14,$62CE,$AA19,$D7B9,$A158,0
	dc.w	$C004,0,$96CB,$E3F9,$990E,$91A8,$21E0,0,$C004,0,$9083,$6524,$8803
	dc.w	$4B96,$20B0,0,$C004,0,$8A3A,$E64F,$76F8,$0584,$A188,0,$C004,0,$83F2
	dc.w	$677A,$65EC,$BF73,$21C4,0,$C003,0,$FB53,$D14A,$A9C2,$F2C2,$2000,0
	dc.w	$C003,0,$EEC2,$D3A0,$87AC,$669F,$2138,0,$C003,0,$E231,$D5F6,$6595
	dc.w	$DA7B,$A130,0,$C003,0,$D5A0,$D84C,$437F,$4E58,$9FC0,0,$C003,0,$C90F
	dc.w	$DAA2,$2168,$C235,$2100,0,$C003,0,$BC7E,$DCF7,$FF52,$3611,$A168,0
	dc.w	$C003,0,$AFED,$DF4D,$DD3B,$A9EE,$A0A0,0,$C003,0,$A35C,$E1A3,$BB25
	dc.w	$1DCB,$2090,0,$C003,0,$96CB,$E3F9,$990E,$91A8,$2160,0,$C003,0,$8A3A
	dc.w	$E64F,$76F8,$0584,$A108,0,$C002,0,$FB53,$D14A,$A9C2,$F2C2,$1F80,0
	dc.w	$C002,0,$E231,$D5F6,$6595,$DA7B,$A0B0,0,$C002,0,$C90F,$DAA2,$2168
	dc.w	$C235,$2080,0,$C002,0,$AFED,$DF4D,$DD3B,$A9EE,$A020,0,$C002,0,$96CB
	dc.w	$E3F9,$990E,$91A8,$20E0,0,$C001,0,$FB53,$D14A,$A9C2,$F2C2,$1F00,0
	dc.w	$C001,0,$C90F,$DAA2,$2168,$C235,$2000,0,$C001,0,$96CB,$E3F9,$990E
	dc.w	$91A8,$2060,0,$C000,0,$C90F,$DAA2,$2168,$C235,$1F80,0,$BFFF,0,$C90F
	dc.w	$DAA2,$2168,$C235,$1F00,0,0,0,0,0,0,0,0,0,$3FFF,0,$C90F,$DAA2,$2168
	dc.w	$C235,$9F00,0,$4000,0,$C90F,$DAA2,$2168,$C235,$9F80,0,$4001,0,$96CB
	dc.w	$E3F9,$990E,$91A8,$A060,0,$4001,0,$C90F,$DAA2,$2168,$C235,$A000,0
	dc.w	$4001,0,$FB53,$D14A,$A9C2,$F2C2,$9F00,0,$4002,0,$96CB,$E3F9,$990E
	dc.w	$91A8,$A0E0,0,$4002,0,$AFED,$DF4D,$DD3B,$A9EE,$2020,0,$4002,0,$C90F
	dc.w	$DAA2,$2168,$C235,$A080,0,$4002,0,$E231,$D5F6,$6595,$DA7B,$20B0,0
	dc.w	$4002,0,$FB53,$D14A,$A9C2,$F2C2,$9F80,0,$4003,0,$8A3A,$E64F,$76F8
	dc.w	$0584,$2108,0,$4003,0,$96CB,$E3F9,$990E,$91A8,$A160,0,$4003,0,$A35C
	dc.w	$E1A3,$BB25,$1DCB,$A090,0,$4003,0,$AFED,$DF4D,$DD3B,$A9EE,$20A0,0
	dc.w	$4003,0,$BC7E,$DCF7,$FF52,$3611,$2168,0,$4003,0,$C90F,$DAA2,$2168
	dc.w	$C235,$A100,0,$4003,0,$D5A0,$D84C,$437F,$4E58,$1FC0,0,$4003,0,$E231
	dc.w	$D5F6,$6595,$DA7B,$2130,0,$4003,0,$EEC2,$D3A0,$87AC,$669F,$A138,0
	dc.w	$4003,0,$FB53,$D14A,$A9C2,$F2C2,$A000,0,$4004,0,$83F2,$677A,$65EC
	dc.w	$BF73,$A1C4,0,$4004,0,$8A3A,$E64F,$76F8,$0584,$2188,0,$4004,0,$9083
	dc.w	$6524,$8803,$4B96,$A0B0,0,$4004,0,$96CB,$E3F9,$990E,$91A8,$A1E0,0
	dc.w	$4004,0,$9D14,$62CE,$AA19,$D7B9,$2158,0,$4004,0,$A35C,$E1A3,$BB25
	dc.w	$1DCB,$A110,0,$4004,0,$A9A5,$6078,$CC30,$63DD,$A1FC,0,$4004,0,$AFED
	dc.w	$DF4D,$DD3B,$A9EE,$2120,0,$4004,0,$B636,$5E22,$EE46,$F000,$A148,0
	dc.w	$4004,0,$BC7E,$DCF7,$FF52,$3611,$21E8,0,$4004,0,$C2C7,$5BCD,$105D
	dc.w	$7C23,$20D0,0,$4004,0,$C90F,$DAA2,$2168,$C235,$A180,0,$F210,$4800
	dc.w	$2210,$3228,4,$0281,$7FFF,$FFFF,$0C81,$3FD7,$8000,$6C04,$6000,$0134
	dc.w	$0C81,$4004,$BC7E,$6D04,$6000,$0144,$F200,$0080,$F23A,$54A3,$C6DC
	dc.w	$43FA,$FDBC,$F201,$6080,$E981,$D3C1,$F219,$4828,$F211,$4428,$EA99
	dc.w	$0281,$8000,0,$F227,$E00C,$0C81,0,0,$6D00,$0072,$F200,$0080,$F200
	dc.w	$04A3,$F23A,$5580,$FAF8,$F23A,$5500,$FAFA,$F200,$05A3,$F200,$0523
	dc.w	$F23A,$55A2,$FAF4,$F23A,$4922,$FAFE,$F200,$05A3,$F200,$0523,$F23A
	dc.w	$49A2,$FB00,$F23A,$4922,$FB0A,$F200,$05A3,$F200,$0523,$F23A,$49A2
	dc.w	$FB0C,$F200,$0123,$F200,$0CA3,$F200,$0822,$F23C,$44A2,$3F80,0,$F21F
	dc.w	$D030,$F200,$9000,$F200,$0420,$60FF,0,$357A,$F200,$0080,$F200,$0023
	dc.w	$F23A,$5580,$FA88,$F23A,$5500,$FA8A,$F200,$01A3,$F200,$0123,$F23A
	dc.w	$55A2,$FA84,$F23A,$4922,$FA8E,$F200,$01A3,$F200,$0123,$F23A,$49A2
	dc.w	$FA90,$F23A,$4922,$FA9A,$F200,$01A3,$F200,$0123,$F23A,$49A2,$FA9C
	dc.w	$F200,$0523,$F200,$0C23,$F200,$08A2,$F23C,$4422,$3F80,0,$F21F,$D030
	dc.w	$F227,$6880,$0A97,$8000,0,$F200,$9000,$F21F,$4820,$60FF,0,$3500,$0C81
	dc.w	$3FFF,$8000,$6E1C,$F227,$6800,$F200,$9000,$123C,3,$F21F,$4800,$60FF,0
	dc.w	$34DA,$60FF,0,$3522,$F227,$E03C,$2F02,$F23C,$4480,0,0,$0C81,$7FFE
	dc.w	$FFFF,$6652,$3D7C,$7FFE,$FF84,$2D7C,$C90F,$DAA2,$FF88,$42AE,$FF8C
	dc.w	$3D7C,$7FDC,$FF90,$2D7C,$85A3,$08D3,$FF94,$42AE,$FF98,$F200,$003A
	dc.w	$F294,14,$002E,$0080,$FF84,$002E,$0080,$FF90,$F22E,$4822,$FF84,$F200
	dc.w	$0080,$F22E,$4822,$FF90,$F200,$00A8,$F22E,$48A2,$FF90,$F22E,$6800
	dc.w	$FF84,$322E,$FF84,$2241,$0281,0,$7FFF,$0481,0,$3FFF,$0C81,0,$001C
	dc.w	$6F0E,$0481,0,$001B,$1D7C,0,$FF58,$6008,$4281,$1D7C,1,$FF58,$243C,0
	dc.w	$3FFE,$9481,$2D7C,$A2F9,$836E,$FF88,$2D7C,$4E44,$152A,$FF8C,$3D42
	dc.w	$FF84,$F200,$0100,$F22E,$4923,$FF84,$2409,$4842,$0282,$8000,0,$0082
	dc.w	$5F00,0,$2D42,$FF54,$F22E,$4522,$FF54,$F22E,$4528,$FF54,$2401,$0682,0
	dc.w	$3FFF,$3D42,$FF84,$2D7C,$C90F,$DAA2,$FF88,$42AE,$FF8C,$0681,0,$3FDD
	dc.w	$3D41,$FF90,$2D7C,$85A3,$08D3,$FF94,$42AE,$FF98,$122E,$FF58,$F200
	dc.w	$0A00,$F22E,$4A23,$FF84,$F200,$0A80,$F22E,$4AA3,$FF90,$F200,$1180
	dc.w	$F200,$15A2,$F200,$0E28,$F200,$0C28,$F200,$1622,$F200,$0180,$F200
	dc.w	$10A8,$F200,$0422,$0C01,0,$6E00,14,$F200,$01A8,$F200,$0CA2,$6000
	dc.w	$FF0C,$F22E,$6100,$FF54,$241F,$F21F,$D03C,$222E,$FF54,$E299,$6000
	dc.w	$FD72,$BFF6,$687E,$3149,$87D8,$4002,$AC69,$34A2,$6DB3,$BFC2,$476F
	dc.w	$4E1D,$A28E,$3FB3,$4444,$7F87,$6989,$BFB7,$44EE,$7FAF,$45DB,$3FBC
	dc.w	$71C6,$4694,$0220,$BFC2,$4924,$9218,$72F9,$3FC9,$9999,$9999,$8FA9
	dc.w	$BFD5,$5555,$5555,$5555,$BFB7,$0BF3,$9853,$9E6A,$3FBC,$7187,$962D
	dc.w	$1D7D,$BFC2,$4924,$8271,$07B8,$3FC9,$9999,$9996,$263E,$BFD5,$5555
	dc.w	$5555,$5536,$3FFF,0,$C90F,$DAA2,$2168,$C235,0,0,$BFFF,0,$C90F,$DAA2
	dc.w	$2168,$C235,0,0,1,0,$8000,0,0,0,0,0,$8001,0,$8000,0,0,0,0,0,$3FFB,0
	dc.w	$83D1,$52C5,$060B,$7A51,0,0,$3FFB,0,$8BC8,$5445,$6549,$8B8B,0,0,$3FFB
	dc.w	0,$93BE,$4060,$1762,$6B0D,0,0,$3FFB,0,$9BB3,$078D,$35AE,$C202,0,0
	dc.w	$3FFB,0,$A3A6,$9A52,$5DDC,$E7DE,0,0,$3FFB,0,$AB98,$E943,$6276,$5619,0
	dc.w	0,$3FFB,0,$B389,$E502,$F9C5,$9862,0,0,$3FFB,0,$BB79,$7E43,$6B09,$E6FB
	dcb.w	2,0
	dc.w	$3FFB,0,$C367,$A5C7,$39E5,$F446,0,0,$3FFB,0,$CB54,$4C61,$CFF7,$D5C6,0
	dc.w	0,$3FFB,0,$D33F,$62F8,$2488,$533E,0,0,$3FFB,0,$DB28,$DA81,$6240,$4C77
	dcb.w	2,0
	dc.w	$3FFB,0,$E310,$A407,$8AD3,$4F18,0,0,$3FFB,0,$EAF6,$B0A8,$188E,$E1EB,0
	dc.w	0,$3FFB,0,$F2DA,$F194,$9DBE,$79D5,0,0,$3FFB,0,$FABD,$5813,$61D4,$7E3E
	dcb.w	2,0
	dc.w	$3FFC,0,$8346,$AC21,$0959,$ECC4,0,0,$3FFC,0,$8B23,$2A08,$3042,$82D8,0
	dc.w	0,$3FFC,0,$92FB,$70B8,$D29A,$E2F9,0,0,$3FFC,0,$9ACF,$476F,$5CCD,$1CB4
	dcb.w	2,0
	dc.w	$3FFC,0,$A29E,$7630,$4954,$F23F,0,0,$3FFC,0,$AA68,$C5D0,$8AB8,$5230,0
	dc.w	0,$3FFC,0,$B22D,$FFFD,$9D53,$9F83,0,0,$3FFC,0,$B9ED,$EF45,$3E90,$0EA5
	dcb.w	2,0
	dc.w	$3FFC,0,$C1A8,$5F1C,$C75E,$3EA5,0,0,$3FFC,0,$C95D,$1BE8,$2813,$8DE6,0
	dc.w	0,$3FFC,0,$D10B,$F300,$840D,$2DE4,0,0,$3FFC,0,$D8B4,$B2BA,$6BC0,$5E7A
	dcb.w	2,0
	dc.w	$3FFC,0,$E057,$2A6B,$B423,$35F6,0,0,$3FFC,0,$E7F3,$2A70,$EA9C,$AA8F,0
	dc.w	0,$3FFC,0,$EF88,$8432,$64EC,$EFAA,0,0,$3FFC,0,$F717,$0A28,$ECC0,$6666
	dcb.w	2,0
	dc.w	$3FFD,0,$812F,$D288,$332D,$AD32,0,0,$3FFD,0,$88A8,$D1B1,$218E,$4D64,0
	dc.w	0,$3FFD,0,$9012,$AB3F,$23E4,$AEE8,0,0,$3FFD,0,$976C,$C3D4,$11E7,$F1B9
	dcb.w	2,0
	dc.w	$3FFD,0,$9EB6,$8949,$3889,$A227,0,0,$3FFD,0,$A5EF,$72C3,$4487,$361B,0
	dc.w	0,$3FFD,0,$AD17,$00BA,$F07A,$7227,0,0,$3FFD,0,$B42C,$BCFA,$FD37,$EFB7
	dcb.w	2,0
	dc.w	$3FFD,0,$BB30,$3A94,$0BA8,$0F89,0,0,$3FFD,0,$C221,$15C6,$FCAE,$BBAF,0
	dc.w	0,$3FFD,0,$C8FE,$F3E6,$8633,$1221,0,0,$3FFD,0,$CFC9,$8330,$B400,$0C70
	dcb.w	2,0
	dc.w	$3FFD,0,$D680,$7AA1,$102C,$5BF9,0,0,$3FFD,0,$DD23,$99BC,$3125,$2AA3,0
	dc.w	0,$3FFD,0,$E3B2,$A855,$6B8F,$C517,0,0,$3FFD,0,$EA2D,$764F,$6431,$5989
	dcb.w	2,0
	dc.w	$3FFD,0,$F3BF,$5BF8,$BAD1,$A21D,0,0,$3FFE,0,$801C,$E39E,$0D20,$5C9A,0
	dc.w	0,$3FFE,0,$8630,$A2DA,$DA1E,$D066,0,0,$3FFE,0,$8C1A,$D445,$F3E0,$9B8C
	dcb.w	2,0
	dc.w	$3FFE,0,$91DB,$8F16,$64F3,$50E2,0,0,$3FFE,0,$9773,$1420,$365E,$538C,0
	dc.w	0,$3FFE,0,$9CE1,$C8E6,$A0B8,$CDBA,0,0,$3FFE,0,$A228,$32DB,$CADA,$AE09
	dcb.w	2,0
	dc.w	$3FFE,0,$A746,$F2DD,$B760,$2294,0,0,$3FFE,0,$AC3E,$C0FB,$997D,$D6A2,0
	dc.w	0,$3FFE,0,$B110,$688A,$EBDC,$6F6A,0,0,$3FFE,0,$B5BC,$C490,$59EC,$C4B0
	dcb.w	2,0
	dc.w	$3FFE,0,$BA44,$BC7D,$D470,$782F,0,0,$3FFE,0,$BEA9,$4144,$FD04,$9AAC,0
	dc.w	0,$3FFE,0,$C2EB,$4ABB,$6616,$28B6,0,0,$3FFE,0,$C70B,$D54C,$E602,$EE14
	dcb.w	2,0
	dc.w	$3FFE,0,$CD00,$0549,$ADEC,$7159,0,0,$3FFE,0,$D484,$57D2,$D8EA,$4EA3,0
	dc.w	0,$3FFE,0,$DB94,$8DA7,$12DE,$CE3B,0,0,$3FFE,0,$E238,$55F9,$69E8,$096A
	dcb.w	2,0
	dc.w	$3FFE,0,$E877,$1129,$C435,$3259,0,0,$3FFE,0,$EE57,$C16E,$0D37,$9C0D,0
	dc.w	0,$3FFE,0,$F3E1,$0211,$A87C,$3779,0,0,$3FFE,0,$F919,$039D,$758B,$8D41
	dcb.w	2,0
	dc.w	$3FFE,0,$FE05,$8B8F,$6493,$5FB3,0,0,$3FFF,0,$8155,$FB49,$7B68,$5D04,0
	dc.w	0,$3FFF,0,$8388,$9E35,$49D1,$08E1,0,0,$3FFF,0,$859C,$FA76,$511D,$724B
	dcb.w	2,0
	dc.w	$3FFF,0,$8795,$2ECF,$FF81,$31E7,0,0,$3FFF,0,$8973,$2FD1,$9557,$641B,0
	dc.w	0,$3FFF,0,$8B38,$CAD1,$0193,$2A35,0,0,$3FFF,0,$8CE7,$A8D8,$301E,$E6B5
	dcb.w	2,0
	dc.w	$3FFF,0,$8F46,$A39E,$2EAE,$5281,0,0,$3FFF,0,$922D,$A7D7,$9188,$8487,0
	dc.w	0,$3FFF,0,$94D1,$9FCB,$DEDF,$5241,0,0,$3FFF,0,$973A,$B944,$19D2,$A08B
	dcb.w	2,0
	dc.w	$3FFF,0,$996F,$F00E,$08E1,$0B96,0,0,$3FFF,0,$9B77,$3F95,$1232,$1DA7,0
	dc.w	0,$3FFF,0,$9D55,$CC32,$0F93,$5624,0,0,$3FFF,0,$9F10,$0575,$006C,$C571
	dcb.w	2,0
	dc.w	$3FFF,0,$A0A9,$C290,$D97C,$C06C,0,0,$3FFF,0,$A226,$59EB,$EBC0,$630A,0
	dc.w	0,$3FFF,0,$A388,$B4AF,$F6EF,$0EC9,0,0,$3FFF,0,$A4D3,$5F10,$61D2,$92C4
	dcb.w	2,0
	dc.w	$3FFF,0,$A608,$95DC,$FBE3,$187E,0,0,$3FFF,0,$A72A,$51DC,$7367,$BEAC,0
	dc.w	0,$3FFF,0,$A83A,$5153,$0956,$168F,0,0,$3FFF,0,$A93A,$2007,$7539,$546E
	dcb.w	2,0
	dc.w	$3FFF,0,$AA9E,$7245,$023B,$2605,0,0,$3FFF,0,$AC4C,$84BA,$6FE4,$D58F,0
	dc.w	0,$3FFF,0,$ADCE,$4A4A,$606B,$9712,0,0,$3FFF,0,$AF2A,$2DCD,$8D26,$3C9C
	dcb.w	2,0
	dc.w	$3FFF,0,$B065,$6F81,$F222,$65C7,0,0,$3FFF,0,$B184,$6515,$0F71,$496A,0
	dc.w	0,$3FFF,0,$B28A,$AA15,$6F9A,$DA35,0,0,$3FFF,0,$B37B,$44FF,$3766,$B895
	dcb.w	2,0
	dc.w	$3FFF,0,$B458,$C3DC,$E963,$0433,0,0,$3FFF,0,$B525,$529D,$5622,$46BD,0
	dc.w	0,$3FFF,0,$B5E2,$CCA9,$5F9D,$88CC,0,0,$3FFF,0,$B692,$CADA,$7ACA,$1ADA
	dcb.w	2,0
	dc.w	$3FFF,0,$B736,$AEA7,$A692,$5838,0,0,$3FFF,0,$B7CF,$AB28,$7E9F,$7B36,0
	dc.w	0,$3FFF,0,$B85E,$CC66,$CB21,$9835,0,0,$3FFF,0,$B8E4,$FD5A,$20A5,$93DA
	dcb.w	2,0
	dc.w	$3FFF,0,$B99F,$41F6,$4AFF,$9BB5,0,0,$3FFF,0,$BA7F,$1E17,$842B,$BE7B,0
	dc.w	0,$3FFF,0,$BB47,$1285,$7637,$E17D,0,0,$3FFF,0,$BBFA,$BE8A,$4788,$DF6F
	dcb.w	2,0
	dc.w	$3FFF,0,$BC9D,$0FAD,$2B68,$9D79,0,0,$3FFF,0,$BD30,$6A39,$471E,$CD86,0
	dc.w	0,$3FFF,0,$BDB6,$C731,$856A,$F18A,0,0,$3FFF,0,$BE31,$CAC5,$02E8,$0D70
	dcb.w	2,0
	dc.w	$3FFF,0,$BEA2,$D55C,$E331,$94E2,0,0,$3FFF,0,$BF0B,$10B7,$C031,$28F0,0
	dc.w	0,$3FFF,0,$BF6B,$7A18,$DACB,$778D,0,0,$3FFF,0,$BFC4,$EA46,$63FA,$18F6
	dcb.w	2,0
	dc.w	$3FFF,0,$C018,$1BDE,$8B89,$A454,0,0,$3FFF,0,$C065,$B066,$CFBF,$6439,0
	dc.w	0,$3FFF,0,$C0AE,$345F,$5634,$0AE6,0,0,$3FFF,0,$C0F2,$2291,$9CB9,$E6A7
	dcb.w	2,0
	dc.w	$F210,$4800,$2210,$3228,4,$F22E,$6800,$FF84,$0281,$7FFF,$FFFF,$0C81
	dc.w	$3FFB,$8000,$6C04,$6000,$00D0,$0C81,$4002,$FFFF,$6F04,$6000,$014C
	dc.w	$02AE,$F800,0,$FF88,$00AE,$0400,0,$FF88,$2D7C,0,0,$FF8C,$F200,$0080
	dc.w	$F22E,$48A3,$FF84,$F22E,$4828,$FF84,$F23C,$44A2,$3F80,0,$F200,$0420
	dc.w	$2F02,$2401,$0281,0,$7800,$0282,$7FFF,0,$0482,$3FFB,0,$E282,$D282
	dc.w	$EE81,$43FA,$F780,$D3C1,$2D59,$FF90,$2D59,$FF94,$2D59,$FF98,$222E
	dc.w	$FF84,$0281,$8000,0,$83AE,$FF90,$241F,$F227,$E004,$F200,$0080,$F200
	dc.w	$04A3,$F23A,$5500,$F6A0,$F200,$0522,$F200,$0523,$F200,$00A3,$F23A
	dc.w	$5522,$F696,$F23A,$54A3,$F698,$F200,$08A3,$F200,$0422,$F21F,$D020
	dc.w	$F200,$9000,$F22E,$4822,$FF90,$60FF,0,$29D2,$0C81,$3FFF,$8000,$6E00
	dc.w	$008A,$0C81,$3FD7,$8000,$6D00,$006C,$F227,$E00C,$F200,$0023,$F200
	dc.w	$0080,$F200,$04A3,$F23A,$5500,$F65A,$F23A,$5580,$F65C,$F200,$0523
	dc.w	$F200,$05A3,$F23A,$5522,$F656,$F23A,$55A2,$F658,$F200,$0523,$F200
	dc.w	$0CA3,$F23A,$5522,$F652,$F23A,$54A2,$F654,$F200,$0123,$F22E,$4823
	dc.w	$FF84,$F200,$08A2,$F200,$0423,$F21F,$D030,$F200,$9000,$F22E,$4822
	dc.w	$FF84,$60FF,0,$2954,$F200,$9000,$123C,3,$F22E,$4800,$FF84,$60FF,0
	dc.w	$2938,$0C81,$4063,$8000,$6E00,$008E,$F227,$E00C,$F23C,$4480,$BF80,0
	dc.w	$F200,$00A0,$F200,$0400,$F200,$0023,$F22E,$6880,$FF84,$F200,$0080
	dc.w	$F200,$04A3,$F23A,$5580,$F5EC,$F23A,$5500,$F5EE,$F200,$05A3,$F200
	dc.w	$0523,$F23A,$55A2,$F5E8,$F23A,$5522,$F5EA,$F200,$0CA3,$F200,$0123
	dc.w	$F23A,$54A2,$F5E4,$F22E,$4823,$FF84,$F200,$08A2,$F200,$0423,$F22E
	dc.w	$4822,$FF84,$F21F,$D030,$F200,$9000,$4A10,$6A0C,$F23A,$4822,$F5D6
	dc.w	$60FF,0,$28C6,$F23A,$4822,$F5BA,$60FF,0,$28B2,$4A10,$6A16,$F23A,$4800
	dc.w	$F5BA,$F200,$9000,$F23A,$4822,$F5C0,$60FF,0,$28A0,$F23A,$4800,$F594
	dc.w	$F200,$9000,$F23A,$4822,$F5BA,$60FF,0,$2882,$60FF,0,$28BA,$F210,$4800
	dc.w	$2210,$3228,4,$0281,$7FFF,$FFFF,$0C81,$3FFF,$8000,$6C4E,$0C81,$3FD7
	dc.w	$8000,$6D00,$007C,$F23C,$4480,$3F80,0,$F200,$00A8,$F227,$E004,$F23C
	dc.w	$4500,$3F80,0,$F200,$0122,$F200,$08A3,$F21F,$D020,$F200,$0484,$F200
	dc.w	$0420,$F227,$E001,$41D7,$61FF,$FFFF,$FD66,$DFFC,0,12,$60FF,0,$280E
	dc.w	$F200,$0018,$F23C,$4438,$3F80,0,$F2D2,0,$265A,$F23A,$4800,$B8AE,$2210
	dc.w	$0281,$8000,0,$0081,$3F80,0,$2F01,$F200,$9000,$F21F,$4423,$60FF,0
	dc.w	$27D8,$F200,$9000,$123C,3,$F210,$4800,$60FF,0,$27BE,$60FF,0,$2806
	dc.w	$F210,$4800,$2210,$3228,4,$0281,$7FFF,$FFFF,$0C81,$3FFF,$8000,$6C44
	dc.w	$F23C,$4480,$3F80,0,$F200,$00A2,$F200,$001A,$F23C,$4422,$3F80,0,$F200
	dc.w	$0420,$F200,4,$2F00,$4280,$F227,$E001,$41D7,$61FF,$FFFF,$FCC4,$DFFC,0
	dc.w	12,$F21F,$9000,$F200,$0022,$60FF,0,$276C,$F200,$0018,$F23C,$4438
	dc.w	$3F80,0,$F2D2,0,$25B0,$4A10,$6A18,$F23A,$4800,$B7F0,$F200,$9000,$F23C
	dc.w	$4422,$0080,0,$60FF,0,$273E,$60FF,0,$2988,$F200,$9000,$F23A,$4800
	dc.w	$B7DE,$60FF,0,$2728,$3FDC,0,$82E3,$0865,$4361,$C4C6,0,0,$3FA5,$5555
	dc.w	$5555,$4CC1,$3FC5,$5555,$5555,$4A54,$3F81,$1111,$1117,$4385,$3FA5
	dcb.w	2,$5555
	dc.w	$4F5A,$3FC5,$5555,$5555,$5555,0,0,0,0,$3EC7,$1DE3,$A577,$4682,$3EFA
	dc.w	$01A0,$19D7,$CB68,$3F2A,$01A0,$1A01,$9DF3,$3F56,$C16C,$16C1,$70E2
	dc.w	$3F81,$1111,$1111,$1111,$3FA5,$5555,$5555,$5555,$3FFC,0,$AAAA,$AAAA
	dc.w	$AAAA,$AAAB,0,0,$48B0,0,0,0,$3730,0,0,0,$3FFF,0,$8000,0,0,0,0,0,$3FFF
	dc.w	0,$8164,$D1F3,$BC03,$0774,$9F84,$1A9B,$3FFF,0,$82CD,$8698,$AC2B,$A1D8
	dc.w	$9FC1,$D5B9,$3FFF,0,$843A,$28C3,$ACDE,$4048,$A072,$8369,$3FFF,0,$85AA
	dc.w	$C367,$CC48,$7B14,$1FC5,$C95C,$3FFF,0,$871F,$6196,$9E8D,$1010,$1EE8
	dc.w	$5C9F,$3FFF,0,$8898,$0E80,$92DA,$8528,$9FA2,$0729,$3FFF,0,$8A14,$D575
	dc.w	$496E,$FD9C,$A07B,$F9AF,$3FFF,0,$8B95,$C1E3,$EA8B,$D6E8,$A002,$0DCF
	dc.w	$3FFF,0,$8D1A,$DF5B,$7E5B,$A9E4,$205A,$63DA,$3FFF,0,$8EA4,$398B,$45CD
	dc.w	$53C0,$1EB7,$0051,$3FFF,0,$9031,$DC43,$1466,$B1DC,$1F6E,$B029,$3FFF,0
	dc.w	$91C3,$D373,$AB11,$C338,$A078,$1494,$3FFF,0,$935A,$2B2F,$13E6,$E92C
	dc.w	$9EB3,$19B0,$3FFF,0,$94F4,$EFA8,$FEF7,$0960,$2017,$457D,$3FFF,0,$9694
	dc.w	$2D37,$2018,$5A00,$1F11,$D537,$3FFF,0,$9837,$F051,$8DB8,$A970,$9FB9
	dc.w	$52DD,$3FFF,0,$99E0,$4593,$20B7,$FA64,$1FE4,$3087,$3FFF,0,$9B8D,$39B9
	dc.w	$D54E,$5538,$1FA2,$A818,$3FFF,0,$9D3E,$D9A7,$2CFF,$B750,$1FDE,$494D
	dc.w	$3FFF,0,$9EF5,$3260,$91A1,$11AC,$2050,$4890,$3FFF,0,$A0B0,$510F,$B971
	dc.w	$4FC4,$A073,$691C,$3FFF,0,$A270,$4303,$0C49,$6818,$1F9B,$7A05,$3FFF,0
	dc.w	$A435,$15AE,$09E6,$80A0,$A079,$7126,$3FFF,0,$A5FE,$D6A9,$B151,$38EC
	dc.w	$A071,$A140,$3FFF,0,$A7CD,$93B4,$E965,$3568,$204F,$62DA,$3FFF,0,$A9A1
	dc.w	$5AB4,$EA7C,$0EF8,$1F28,$3C4A,$3FFF,0,$AB7A,$39B5,$A93E,$D338,$9F9A
	dc.w	$7FDC,$3FFF,0,$AD58,$3EEA,$42A1,$4AC8,$A05B,$3FAC,$3FFF,0,$AF3B,$78AD
	dc.w	$690A,$4374,$1FDF,$2610,$3FFF,0,$B123,$F581,$D2AC,$2590,$9F70,$5F90
	dc.w	$3FFF,0,$B311,$C412,$A911,$2488,$201F,$678A,$3FFF,0,$B504,$F333,$F9DE
	dc.w	$6484,$1F32,$FB13,$3FFF,0,$B6FD,$91E3,$28D1,$7790,$2003,$8B30,$3FFF,0
	dc.w	$B8FB,$AF47,$62FB,$9EE8,$200D,$C3CC,$3FFF,0,$BAFF,$5AB2,$133E,$45FC
	dc.w	$9F8B,$2AE6,$3FFF,0,$BD08,$A39F,$580C,$36C0,$A02B,$BF70,$3FFF,0,$BF17
	dc.w	$99B6,$7A73,$1084,$A00B,$F518,$3FFF,0,$C12C,$4CCA,$6670,$9458,$A041
	dc.w	$DD41,$3FFF,0,$C346,$CCDA,$2497,$6408,$9FDF,$137B,$3FFF,0,$C567,$2A11
	dc.w	$5506,$DADC,$201F,$1568,$3FFF,0,$C78D,$74C8,$ABB9,$B15C,$1FC1,$3A2E
	dc.w	$3FFF,0,$C9B9,$BD86,$6E2F,$27A4,$A03F,$8F03,$3FFF,0,$CBEC,$14FE,$F272
	dc.w	$7C5C,$1FF4,$907D,$3FFF,0,$CE24,$8C15,$1F84,$80E4,$9E6E,$53E4,$3FFF,0
	dc.w	$D063,$33DA,$EF2B,$2594,$1FD6,$D45C,$3FFF,0,$D2A8,$1D91,$F12A,$E45C
	dc.w	$A076,$EDB9,$3FFF,0,$D4F3,$5AAB,$CFED,$FA20,$9FA6,$DE21,$3FFF,0,$D744
	dc.w	$FCCA,$D69D,$6AF4,$1EE6,$9A2F,$3FFF,0,$D99D,$15C2,$78AF,$D7B4,$207F
	dc.w	$439F,$3FFF,0,$DBFB,$B797,$DAF2,$3754,$201E,$C207,$3FFF,0,$DE60,$F482
	dc.w	$5E0E,$9124,$9E8B,$E175,$3FFF,0,$E0CC,$DEEC,$2A94,$E110,$2003,$2C4B
	dc.w	$3FFF,0,$E33F,$8972,$BE8A,$5A50,$2004,$DFF5,$3FFF,0,$E5B9,$06E7,$7C83
	dc.w	$48A8,$1E72,$F47A,$3FFF,0,$E839,$6A50,$3C4B,$DC68,$1F72,$2F22,$3FFF,0
	dc.w	$EAC0,$C6E7,$DD24,$3930,$A017,$E945,$3FFF,0,$ED4F,$301E,$D994,$2B84
	dc.w	$1F40,$1A5B,$3FFF,0,$EFE4,$B99B,$DCDA,$F5CC,$9FB9,$A9E3,$3FFF,0,$F281
	dc.w	$773C,$59FF,$B138,$2074,$4C05,$3FFF,0,$F525,$7D15,$2486,$CC2C,$1F77
	dc.w	$3A19,$3FFF,0,$F7D0,$DF73,$0AD1,$3BB8,$1FFE,$90D5,$3FFF,0,$FA83,$B2DB
	dc.w	$722A,$033C,$A041,$ED22,$3FFF,0,$FD3E,$0C0C,$F486,$C174,$1F85,$3F3A
	dc.w	$2210,$0281,$7FFF,0,$0C81,$3FBE,0,$6C06,$60FF,0,$0108,$3228,4,$0C81
	dc.w	$400C,$B167,$6D06,$60FF,0,$010C,$F210,$4800,$F200,$0080,$F23C,$4423
	dc.w	$42B8,$AA3B,$F227,$E00C,$2D7C,0,0,$FF58,$F201,$6000,$43FA,$FBB6,$F201
	dc.w	$4000,$2D41,$FF54,$0281,0,$003F,$E989,$D3C1,$222E,$FF54,$EC81,$0641
	dc.w	$3FFF,$3D7A,$FB06,$FF54,$F200,$0100,$F23C,$4423,$BC31,$7218,$F23A
	dc.w	$4923,$FAF2,$F200,$0422,$F200,$0822,$F200,$0080,$F200,$04A3,$F23C
	dc.w	$4500,$3AB6,$0B70,$F200,$0523,$F200,$0580,$F23C,$45A3,$3C08,$8895
	dc.w	$F23A,$5522,$FAD4,$F23A,$55A2,$FAD6,$F200,$0523,$3D41,$FF84,$2D7C
	dc.w	$8000,0,$FF88,$42AE,$FF8C,$F200,$05A3,$F23C,$4522,$3F00,0,$F200,$01A3
	dc.w	$F200,$0523,$F200,$0C22,$F219,$4880,$F200,$0822,$F200,$0423,$F21F
	dc.w	$D030,$F211,$4422,$F200,$0422,$222E,$FF58,$4A81,$6706,$F22E,$4823
	dc.w	$FF90,$F200,$9000,$123C,0,$F22E,$4823,$FF84,$60FF,0,$216E,$F210,$D080
	dc.w	$F200,$9000,$F23C,$4422,$3F80,0,$60FF,0,$2168,$0C81,$400C,$B27C,$6E66
	dc.w	$F210,$4800,$F200,$0080,$F23C,$4423,$42B8,$AA3B,$F227,$E00C,$2D7C,0,1
	dc.w	$FF58,$F201,$6000,$43FA,$FAA6,$F201,$4000,$2D41,$FF54,$0281,0,$003F
	dc.w	$E989,$D3C1,$222E,$FF54,$EC81,$2D41,$FF54,$E281,$93AE,$FF54,$0641
	dc.w	$3FFF,$3D41,$FF90,$2D7C,$8000,0,$FF94,$42AE,$FF98,$222E,$FF54,$0641
	dc.w	$3FFF,$6000,$FED2,$4A10,$6BFF,0,$1FBC,$60FF,0,$20AE,$2F10,$0297,$8000
	dc.w	0,$0097,$0080,0,$F23C,$4400,$3F80,0,$F200,$9000,$F21F,$4422,$60FF,0
	dc.w	$20C8,$2210,$0281,$7FFF,0,$0C81,$3FFD,0,$6C06,$60FF,0,$015E,$3228,4
	dc.w	$0C81,$4004,$C215,$6F06,$60FF,0,$026C,$F210,$4800,$F200,$0080,$F23C
	dc.w	$4423,$42B8,$AA3B,$F227,$E00C,$F201,$6000,$43FA,$F9EE,$F201,$4000
	dc.w	$2D41,$FF54,$0281,0,$003F,$E989,$D3C1,$222E,$FF54,$EC81,$2D41,$FF54
	dc.w	$F200,$0100,$F23C,$4423,$BC31,$7218,$F23A,$4923,$F930,$F200,$0422
	dc.w	$F200,$0822,$0641,$3FFF,$F200,$0080,$F200,$04A3,$F23C,$4500,$3950
	dc.w	$097B,$F200,$0523,$F200,$0580,$F23C,$45A3,$3AB6,$0B6A,$F23A,$5522
	dc.w	$F91E,$F23A,$55A2,$F920,$3D41,$FF84,$2D7C,$8000,0,$FF88,$42AE,$FF8C
	dc.w	$F200,$0523,$222E,$FF54,$4441,$F200,$05A3,$0641,$3FFF,$F23A,$5522
	dc.w	$F900,$F23C,$45A2,$3F00,0,$F200,$0523,$0041,$8000,$3D41,$FF90,$2D7C
	dc.w	$8000,0,$FF94,$42AE,$FF98,$F200,$0CA3,$F200,$0123,$F200,$0422,$F200
	dc.w	$0822,$F21F,$D030,$F211,$4823,$222E,$FF54,$0C81,0,$003F,$6F1A,$F229
	dc.w	$4480,12,$F22E,$48A2,$FF90,$F200,$0422,$F211,$4822,$60FF,0,$0034
	dc.w	$0C81,$FFFF,$FFFD,$6C16,$F229,$4422,12,$F211,$4822,$F22E,$4822,$FF90
	dc.w	$60FF,0,$0016,$F219,$4880,$F211,$4422,$F22E,$48A2,$FF90,$F200,$0422
	dc.w	$F200,$9000,$F22E,$4823,$FF84,$60FF,0,$1F50,$0C81,$3FBE,0,$6C6C,$0C81
	dc.w	$0033,0,$6D2C,$2D7C,$8001,0,$FF84,$2D7C,$8000,0,$FF88,$42AE,$FF8C
	dc.w	$F210,$4800,$F200,$9000,$123C,2,$F22E,$4822,$FF84,$60FF,0,$1F0C,$F210
	dc.w	$4800,$F23A,$5423,$F86C,$2D7C,$8001,0,$FF84,$2D7C,$8000,0,$FF88,$42AE
	dc.w	$FF8C,$F22E,$4822,$FF84,$F200,$9000,$123C,0,$F23A,$5423,$F84C,$60FF,0
	dc.w	$1ED4,$F210,$4800,$F200,$0023,$F227,$E00C,$F23C,$4480,$2F30,$CAA8
	dc.w	$F200,$00A3,$F23C,$4500,$310F,$8290,$F23C,$44A2,$32D7,$3220,$F200
	dc.w	$0123,$F200,$00A3,$F23C,$4522,$3493,$F281,$F23A,$54A2,$F7C0,$F200
	dc.w	$0123,$F200,$00A3,$F23A,$5522,$F7BA,$F23A,$54A2,$F7BC,$F200,$0123
	dc.w	$F200,$00A3,$F23A,$5522,$F7B6,$F23A,$54A2,$F7B8,$F200,$0123,$F200
	dc.w	$00A3,$F23A,$5522,$F7B2,$F23A,$48A2,$F7B4,$F200,$0123,$F200,$00A3
	dc.w	$F200,$0123,$F210,$48A3,$F23C,$4423,$3F00,0,$F200,$08A2,$F21F,$D030
	dc.w	$F200,$0422,$F200,$9000,$F210,$4822,$60FF,0,$1E30,$2210,$0C81,0,0
	dc.w	$6E00,$FBAC,$F23C,$4400,$BF80,0,$F200,$9000,$F23C,$4422,$0080,0,$60FF
	dc.w	0,$1E1A,$60FF,0,$1E4A,$3028,0,$0880,15,$0440,$3FFF,$F200,$5000,$6D02
	dc.w	$4E75,$1D7C,8,$FF64,$4E75,$61FF,0,$2342,$4440,$0440,$3FFF,$F200,$5000
	dc.w	$1D7C,8,$FF64,$4E75,$3028,0,$0040,$7FFF,$0880,14,$2D68,4,$FF88,$2D68
	dc.w	8,$FF8C,$3D40,$FF84,$F22E,$4800,$FF84,$6B02,$4E75,$1D7C,8,$FF64,$4E75
	dc.w	$61FF,0,$22FC,$60CA,$7FFB,0,$8000,0,0,0,0,0,$F210,$4800,$2210,$3228,4
	dc.w	$0281,$7FFF,$FFFF,$0C81,$400C,$B167,$6E42,$F200,$0018,$2F00,$4280
	dc.w	$F227,$E001,$41D7,$61FF,$FFFF,$FAD2,$DFFC,0,12,$F23C,$4423,$3F00,0
	dc.w	$201F,$F23C,$4480,$3E80,0,$F200,$00A0,$F200,$9000,$123C,2,$F200,$0422
	dc.w	$60FF,0,$1D28,$0C81,$400C,$B2B3,$6E3C,$F200,$0018,$F23A,$5428,$ADB6
	dc.w	$F23A,$5428,$ADB8,$2F00,$4280,$F227,$E001,$41D7,$61FF,$FFFF,$FA7C
	dc.w	$DFFC,0,12,$201F,$F200,$9000,$123C,0,$F23A,$4823,$FF5A,$60FF,0,$1CE4
	dc.w	$60FF,0,$1CB0,$F23C,$4400,$3F80,0,$F200,$9000,$F23C,$4422,$0080,0
	dc.w	$60FF,0,$1CD4,$F210,$4800,$2210,$3228,4,$2241,$0281,$7FFF,$FFFF,$0C81
	dc.w	$400C,$B167,$6E62,$F200,$0018,$48E7,$8040,$F227,$E001,$41D7,$4280
	dc.w	$61FF,$FFFF,$FBE0,$DFFC,0,12,$F23C,$9000,0,0,$4CDF,$0201,$F200,$0080
	dc.w	$F23C,$44A2,$3F80,0,$F227,$6800,$F200,$0420,$2209,$0281,$8000,0,$0081
	dc.w	$3F00,0,$F21F,$4822,$2F01,$F200,$9000,$123C,0,$F21F,$4423,$60FF,0
	dc.w	$1C48,$0C81,$400C,$B2B3,$6EFF,0,$1BC2,$F200,$0018,$F23A,$5428,$ACD2
	dc.w	$2F3C,0,0,$2F3C,$8000,0,$2209,$0281,$8000,0,$0081,$7FFB,0,$2F01,$F23A
	dc.w	$5428,$ACB8,$2F00,$4280,$F227,$E001,$41D7,$61FF,$FFFF,$F97C,$DFFC,0
	dc.w	12,$201F,$F200,$9000,$123C,0,$F21F,$4823,$60FF,0,$1BE6,$60FF,0,$1C2E
	dc.w	$F210,$4800,$F22E,$6800,$FF84,$2210,$3228,4,$2D41,$FF84,$0281,$7FFF
	dc.w	$FFFF,$0C81,$3FD7,$8000,$6D00,$0074,$0C81,$3FFF,$DDCE,$6E00,$006A
	dc.w	$222E,$FF84,$2D41,$FF5C,$0281,$7FFF,0,$0681,1,0,$2D41,$FF84,$02AE
	dc.w	$8000,0,$FF5C,$F22E,$4800,$FF84,$2F00,$4280,$F227,$E001,$41D7,$61FF
	dc.w	$FFFF,$FAC8,$DFFC,0,12,$201F,$F200,$0080,$F23C,$44A2,$4000,0,$222E
	dc.w	$FF5C,$F22E,$6880,$FF84,$B3AE,$FF84,$F200,$9000,$F22E,$4820,$FF84
	dc.w	$60FF,0,$1B52,$0C81,$3FFF,$8000,$6D00,$0088,$0C81,$4004,$8AA1,$6E00
	dc.w	$0092,$222E,$FF84,$2D41,$FF5C,$0281,$7FFF,0,$0681,1,0,$2D41,$FF84
	dc.w	$02AE,$8000,0,$FF5C,$222E,$FF5C,$F22E,$4800,$FF84,$2F00,$4280,$F227
	dc.w	$E001,$41D7,$61FF,$FFFF,$F878,$DFFC,0,12,$201F,$222E,$FF5C,$F23C
	dc.w	$4422,$3F80,0,$0A81,$C000,0,$F201,$4480,$F200,$00A0,$222E,$FF5C,$0081
	dc.w	$3F80,0,$F201,$4400,$F200,$9000,$123C,2,$F200,$0422,$60FF,0,$1AC2
	dc.w	$F200,$9000,$123C,3,$F22E,$4800,$FF84,$60FF,0,$1AA6,$222E,$FF84,$0281
	dc.w	$8000,0,$0081,$3F80,0,$F201,$4400,$0281,$8000,0,$0A81,$8080,0,$F200
	dc.w	$9000,$F201,$4422,$60FF,0,$1A80,$60FF,0,$1AC0,$3FFE,0,$B172,$17F7
	dc.w	$D1CF,$79AC,0,0,$3F80,0,0,0,$7F80,0,$BF80,0,$3FC2,$499A,$B5E4,$040B
	dc.w	$BFC5,$55B5,$848C,$B7DB,$3FC9,$9999,$987D,$8730,$BFCF,$FFFF,$FF6F
	dc.w	$7E97,$3FD5,$5555,$5555,$55A4,$BFE0,0,0,8,$3F17,$5496,$ADD7,$DAD6
	dc.w	$3F3C,$71C2,$FE80,$C7E0,$3F62,$4924,$928B,$CCFF,$3F89,$9999,$9999
	dc.w	$95EC,$3FB5,$5555,$5555,$5555,$4000,0,0,0,$3F99,0,$8000,0,0,0,0,0
	dc.w	$3FFE,0,$FE03,$F80F,$E03F,$80FE,0,0,$3FF7,0,$FF01,$5358,$833C,$47E2,0
	dc.w	0,$3FFE,0,$FA23,$2CF2,$5213,$8AC0,0,0,$3FF9,0,$BDC8,$D83E,$AD88,$D549
	dcb.w	2,0
	dc.w	$3FFE,0,$F660,$3D98,$0F66,$03DA,0,0,$3FFA,0,$9CF4,$3DCF,$F5EA,$FD48,0
	dc.w	0,$3FFE,0,$F2B9,$D648,$0F2B,$9D65,0,0,$3FFA,0,$DA16,$EB88,$CB8D,$F614
	dcb.w	2,0
	dc.w	$3FFE,0,$EF2E,$B71F,$C434,$5238,0,0,$3FFB,0,$8B29,$B775,$1BD7,$0743,0
	dc.w	0,$3FFE,0,$EBBD,$B2A5,$C161,$9C8C,0,0,$3FFB,0,$A8D8,$39F8,$30C1,$FB49
	dcb.w	2,0
	dc.w	$3FFE,0,$E865,$AC7B,$7603,$A197,0,0,$3FFB,0,$C61A,$2EB1,$8CD9,$07AD,0
	dc.w	0,$3FFE,0,$E525,$982A,$F70C,$880E,0,0,$3FFB,0,$E2F2,$A47A,$DE3A,$18AF
	dcb.w	2,0
	dc.w	$3FFE,0,$E1FC,$780E,$1FC7,$80E2,0,0,$3FFB,0,$FF64,$898E,$DF55,$D551,0
	dc.w	0,$3FFE,0,$DEE9,$5C4C,$A037,$BA57,0,0,$3FFC,0,$8DB9,$56A9,$7B3D,$0148
	dcb.w	2,0
	dc.w	$3FFE,0,$DBEB,$61EE,$D19C,$5958,0,0,$3FFC,0,$9B8F,$E100,$F47B,$A1DE,0
	dc.w	0,$3FFE,0,$D901,$B203,$6406,$C80E,0,0,$3FFC,0,$A937,$2F1D,$0DA1,$BD17
	dcb.w	2,0
	dc.w	$3FFE,0,$D62B,$80D6,$2B80,$D62C,0,0,$3FFC,0,$B6B0,$7F38,$CE90,$E46B,0
	dc.w	0,$3FFE,0,$D368,$0D36,$80D3,$680D,0,0,$3FFC,0,$C3FD,$0329,$0648,$8481
	dcb.w	2,0
	dc.w	$3FFE,0,$D0B6,$9FCB,$D258,$0D0B,0,0,$3FFC,0,$D11D,$E0FF,$15AB,$18CA,0
	dc.w	0,$3FFE,0,$CE16,$8A77,$2508,$0CE1,0,0,$3FFC,0,$DE14,$33A1,$6C66,$B150
	dcb.w	2,0
	dc.w	$3FFE,0,$CB87,$27C0,$65C3,$93E0,0,0,$3FFC,0,$EAE1,$0B5A,$7DDC,$8ADD,0
	dc.w	0,$3FFE,0,$C907,$DA4E,$8711,$46AD,0,0,$3FFC,0,$F785,$6E5E,$E2C9,$B291
	dcb.w	2,0
	dc.w	$3FFE,0,$C698,$0C69,$80C6,$980C,0,0,$3FFD,0,$8201,$2CA5,$A682,$06D7,0
	dc.w	0,$3FFE,0,$C437,$2F85,$5D82,$4CA6,0,0,$3FFD,0,$882C,$5FCD,$7256,$A8C5
	dcb.w	2,0
	dc.w	$3FFE,0,$C1E4,$BBD5,$95F6,$E947,0,0,$3FFD,0,$8E44,$C60B,$4CCF,$D7DE,0
	dc.w	0,$3FFE,0,$BFA0,$2FE8,$0BFA,$02FF,0,0,$3FFD,0,$944A,$D09E,$F435,$1AF6
	dcb.w	2,0
	dc.w	$3FFE,0,$BD69,$1047,$0766,$1AA3,0,0,$3FFD,0,$9A3E,$ECD4,$C3EA,$A6B2,0
	dc.w	0,$3FFE,0,$BB3E,$E721,$A54D,$880C,0,0,$3FFD,0,$A021,$8434,$353F,$1DE8
	dcb.w	2,0
	dc.w	$3FFE,0,$B921,$43FA,$36F5,$E02E,0,0,$3FFD,0,$A5F2,$FCAB,$BBC5,$06DA,0
	dc.w	0,$3FFE,0,$B70F,$BB5A,$19BE,$3659,0,0,$3FFD,0,$ABB3,$B8BA,$2AD3,$62A5
	dcb.w	2,0
	dc.w	$3FFE,0,$B509,$E68A,$9B94,$821F,0,0,$3FFD,0,$B164,$1795,$CE3C,$A97B,0
	dc.w	0,$3FFE,0,$B30F,$6352,$8917,$C80B,0,0,$3FFD,0,$B704,$7551,$5D0F,$1C61
	dcb.w	2,0
	dc.w	$3FFE,0,$B11F,$D3B8,$0B11,$FD3C,0,0,$3FFD,0,$BC95,$2AFE,$EA3D,$13E1,0
	dc.w	0,$3FFE,0,$AF3A,$DDC6,$80AF,$3ADE,0,0,$3FFD,0,$C216,$8ED0,$F458,$BA4A
	dcb.w	2,0
	dc.w	$3FFE,0,$AD60,$2B58,$0AD6,$02B6,0,0,$3FFD,0,$C788,$F439,$B316,$3BF1,0
	dc.w	0,$3FFE,0,$AB8F,$69E2,$8359,$CD11,0,0,$3FFD,0,$CCEC,$AC08,$BF04,$565D
	dcb.w	2,0
	dc.w	$3FFE,0,$A9C8,$4A47,$A07F,$5638,0,0,$3FFD,0,$D242,$0487,$2DD8,$5160,0
	dc.w	0,$3FFE,0,$A80A,$80A8,$0A80,$A80B,0,0,$3FFD,0,$D789,$4992,$3BC3,$588A
	dcb.w	2,0
	dc.w	$3FFE,0,$A655,$C439,$2D7B,$73A8,0,0,$3FFD,0,$DCC2,$C4B4,$9887,$DACC,0
	dc.w	0,$3FFE,0,$A4A9,$CF1D,$9683,$3751,0,0,$3FFD,0,$E1EE,$BD3E,$6D6A,$6B9E
	dcb.w	2,0
	dc.w	$3FFE,0,$A306,$5E3F,$AE7C,$D0E0,0,0,$3FFD,0,$E70D,$785C,$2F9F,$5BDC,0
	dc.w	0,$3FFE,0,$A16B,$312E,$A8FC,$377D,0,0,$3FFD,0,$EC1F,$392C,$5179,$F283
	dcb.w	2,0
	dc.w	$3FFE,0,$9FD8,$09FD,$809F,$D80A,0,0,$3FFD,0,$F124,$40D3,$E361,$30E6,0
	dc.w	0,$3FFE,0,$9E4C,$AD23,$DD5F,$3A20,0,0,$3FFD,0,$F61C,$CE92,$3466,$00BB
	dcb.w	2,0
	dc.w	$3FFE,0,$9CC8,$E160,$C3FB,$19B9,0,0,$3FFD,0,$FB09,$1FD3,$8145,$630A,0
	dc.w	0,$3FFE,0,$9B4C,$6F9E,$F03A,$3CAA,0,0,$3FFD,0,$FFE9,$7042,$BFA4,$C2AD
	dcb.w	2,0
	dc.w	$3FFE,0,$99D7,$22DA,$BDE5,$8F06,0,0,$3FFE,0,$825E,$FCED,$4936,$9330,0
	dc.w	0,$3FFE,0,$9868,$C809,$868C,$8098,0,0,$3FFE,0,$84C3,$7A7A,$B9A9,$05C9
	dcb.w	2,0
	dc.w	$3FFE,0,$9701,$2E02,$5C04,$B809,0,0,$3FFE,0,$8722,$4C2E,$8E64,$5FB7,0
	dc.w	0,$3FFE,0,$95A0,$2568,$095A,$0257,0,0,$3FFE,0,$897B,$8CAC,$9F7D,$E298
	dcb.w	2,0
	dc.w	$3FFE,0,$9445,$8094,$4580,$9446,0,0,$3FFE,0,$8BCF,$55DE,$C4CD,$05FE,0
	dc.w	0,$3FFE,0,$92F1,$1384,$0497,$889C,0,0,$3FFE,0,$8E1D,$C0FB,$89E1,$25E5
	dcb.w	2,0
	dc.w	$3FFE,0,$91A2,$B3C4,$D5E6,$F809,0,0,$3FFE,0,$9066,$E68C,$955B,$6C9B,0
	dc.w	0,$3FFE,0,$905A,$3863,$3E06,$C43B,0,0,$3FFE,0,$92AA,$DE74,$C7BE,$59E0
	dcb.w	2,0
	dc.w	$3FFE,0,$8F17,$79D9,$FDC3,$A219,0,0,$3FFE,0,$94E9,$BFF6,$1584,$5643,0
	dc.w	0,$3FFE,0,$8DDA,$5202,$3769,$4809,0,0,$3FFE,0,$9723,$A1B7,$2013,$4203
	dcb.w	2,0
	dc.w	$3FFE,0,$8CA2,$9C04,$6514,$E023,0,0,$3FFE,0,$9958,$99C8,$90EB,$8990,0
	dc.w	0,$3FFE,0,$8B70,$344A,$139B,$C75A,0,0,$3FFE,0,$9B88,$BDAA,$3A3D,$AE2F
	dcb.w	2,0
	dc.w	$3FFE,0,$8A42,$F870,$5669,$DB46,0,0,$3FFE,0,$9DB4,$224F,$FFE1,$157C,0
	dc.w	0,$3FFE,0,$891A,$C73A,$E981,$9B50,0,0,$3FFE,0,$9FDA,$DC26,$8B7A,$12DA
	dcb.w	2,0
	dc.w	$3FFE,0,$87F7,$8087,$F780,$87F8,0,0,$3FFE,0,$A1FC,$FF17,$CE73,$3BD4,0
	dc.w	0,$3FFE,0,$86D9,$0544,$7A34,$ACC6,0,0,$3FFE,0,$A41A,$9E8F,$5446,$FB9F
	dcb.w	2,0
	dc.w	$3FFE,0,$85BF,$3761,$2CEE,$3C9B,0,0,$3FFE,0,$A633,$CD7E,$6771,$CD8B,0
	dc.w	0,$3FFE,0,$84A9,$F9C8,$084A,$9F9D,0,0,$3FFE,0,$A848,$9E60,$0B43,$5A5E
	dcb.w	2,0
	dc.w	$3FFE,0,$8399,$3052,$3FBE,$3368,0,0,$3FFE,0,$AA59,$233C,$CCA4,$BD49,0
	dc.w	0,$3FFE,0,$828C,$BFBE,$B9A0,$20A3,0,0,$3FFE,0,$AC65,$6DAE,$6BCC,$4985
	dcb.w	2,0
	dc.w	$3FFE,0,$8184,$8DA8,$FAF0,$D277,0,0,$3FFE,0,$AE6D,$8EE3,$60BB,$2468,0
	dc.w	0,$3FFE,0,$8080,$8080,$8080,$8081,0,0,$3FFE,0,$B071,$97A2,$3C46,$C654
	dcb.w	2,0
	dc.w	$F210,$4800,$2D7C,0,0,$FF54,$2210,$3228,4,$2D50,$FF84,$2D68,4,$FF88
	dc.w	$2D68,8,$FF8C,$0C81,0,0,$6D00,$0182,$0C81,$3FFE,$F07D,$6D0A,$0C81
	dc.w	$3FFF,$8841,$6F00,$00E2,$E081,$E081,$0481,0,$3FFF,$D2AE,$FF54,$41FA
	dc.w	$F7B2,$F201,$4080,$2D7C,$3FFF,0,$FF84,$2D6E,$FF88,$FF94,$02AE,$FE00,0
	dc.w	$FF94,$00AE,$0100,0,$FF94,$222E,$FF94,$0281,$7E00,0,$E081,$E081,$E881
	dc.w	$D1C1,$F22E,$4800,$FF84,$2D7C,$3FFF,0,$FF90,$42AE,$FF98,$F22E,$4828
	dc.w	$FF90,$F227,$E00C,$F210,$4823,$F23A,$48A3,$F6C8,$F200,$0100,$F200
	dc.w	$0923,$F22E,$6880,$FF84,$F200,$0980,$F200,$0880,$F23A,$54A3,$F6CC
	dc.w	$F23A,$5523,$F6CE,$F23A,$54A2,$F6D0,$F23A,$5522,$F6D2,$F200,$0CA3
	dc.w	$F200,$0D23,$F23A,$54A2,$F6CC,$F23A,$5522,$F6CE,$F200,$0CA3,$D1FC,0
	dc.w	$0010,$F200,$0D23,$F200,$00A3,$F200,$0822,$F210,$48A2,$F21F,$D030
	dc.w	$F200,$0422,$F200,$9000,$F22E,$4822,$FF84,$60FF,0,$10CC,$F23C,$5838,1
	dc.w	$F2C1,0,$1318,$F200,$0080,$F23A,$44A8,$F64E,$F23A,$4422,$F648,$F200
	dc.w	$04A2,$F200,$00A0,$F227,$E00C,$F200,$0400,$F200,$0023,$F22E,$6880
	dc.w	$FF84,$F200,$0080,$F200,$04A3,$F23A,$5580,$F660,$F23A,$5500,$F662
	dc.w	$F200,$05A3,$F200,$0523,$F23A,$55A2,$F65C,$F23A,$5522,$F65E,$F200
	dc.w	$0CA3,$F200,$0123,$F23A,$54A2,$F658,$F22E,$4823,$FF84,$F200,$08A2
	dc.w	$F21F,$D030,$F200,$0423,$F200,$9000,$F22E,$4822,$FF84,$60FF,0,$103E
	dc.w	$60FF,0,$0E96,$2D7C,$FFFF,$FF9C,$FF54,$48E7,$3F00,$2610,$2828,4,$2A28
	dc.w	8,$4282,$4A84,$6634,$2805,$4285,$7420,$4286,$EDC4,$6000,$EDAC,$D486
	dc.w	$2D43,$FF84,$2D44,$FF88,$2D45,$FF8C,$4482,$2D42,$FF54,$F22E,$4800
	dc.w	$FF84,$4CDF,$00FC,$41EE,$FF84,$6000,$FE0C,$4286,$EDC4,$6000,$2406
	dc.w	$EDAC,$2E05,$EDAD,$4486,$0686,0,$0020,$ECAF,$8887,$2D43,$FF84,$2D44
	dc.w	$FF88,$2D45,$FF8C,$4482,$2D42,$FF54,$F22E,$4800,$FF84,$4CDF,$00FC
	dc.w	$41EE,$FF84,$6000,$FDCE,$F210,$4800,$F200,$0018,$F23A,$4838,$F5A4
	dc.w	$F292,$0014,$F200,$9000,$123C,3,$F210,$4800,$60FF,0,$0F7E,$F210,$4800
	dc.w	$2D7C,0,0,$FF54,$F200,$0080,$F23A,$4422,$F508,$F22E,$6800,$FF84,$3D6E
	dc.w	$FF88,$FF86,$222E,$FF84,$0C81,0,0,$6F00,$00DA,$0C81,$3FFE,$8000,$6D00
	dc.w	$FDA2,$0C81,$3FFF,$C000,$6E00,$FD98,$0C81,$3FFE,$F07D,$6D00,$001A
	dc.w	$0C81,$3FFF,$8841,$6E00,$0010,$F200,$04A2,$F23A,$4422,$F4BC,$6000
	dc.w	$FE76,$2D6E,$FF88,$FF94,$02AE,$FE00,0,$FF94,$00AE,$0100,0,$FF94,$0C81
	dc.w	$3FFF,$8000,$6C44,$F23A,$4400,$F4FC,$2D7C,$3FFF,0,$FF90,$42AE,$FF98
	dc.w	$F22E,$4828,$FF90,$222E,$FF94,$0281,$7E00,0,$E081,$E081,$E881,$F200
	dc.w	$04A2,$F227,$E00C,$F200,$0422,$41FA,$F4E2,$D1C1,$F23A,$4480,$F466
	dc.w	$6000,$FD76,$F23A,$4400,$F450,$2D7C,$3FFF,0,$FF90,$42AE,$FF98,$F22E
	dc.w	$4828,$FF90,$222E,$FF94,$0281,$7E00,0,$E081,$E081,$E881,$F200,$0422
	dc.w	$F227,$E00C,$41FA,$F4A2,$D1C1,$F23A,$4480,$F41E,$6000,$FD36,$0C81,0,0
	dc.w	$6D10,$F23A,$4400,$F414,$F200,$9000,$60FF,0,$0C4E,$F23A,$4400,$F3FC
	dc.w	$F200,$9000,$60FF,0,$0CB4,$60FF,0,$0E96,$2210,$3228,4,$0281,$7FFF
	dc.w	$FFFF,$0C81,$3FFF,$8000,$6C56,$F210,$4818,$F200,$0080,$F200,$049A
	dc.w	$F200,$0022,$F23C,$44A2,$3F80,0,$F200,$0420,$2210,$0281,$8000,0,$0081
	dc.w	$3F00,0,$2F01,$2F00,$4280,$F227,$E001,$41D7,$61FF,$FFFF,$FE5A,$DFFC,0
	dc.w	12,$201F,$F200,$9000,$123C,0,$F21F,$4423,$60FF,0,$0DDE,$F210,$4818
	dc.w	$F23C,$4438,$3F80,0,$F2D2,0,$0C32,$60FF,0,$0BB6,$60FF,0,$0E0E,$3FFD,0
	dc.w	$DE5B,$D8A9,$3728,$7195,0,0,$3FFF,0,$B8AA,$3B29,$5C17,$F0BC,0,0,$F23C
	dc.w	$5800,1,$F210,$4838,$F2C1,0,$0FF0,$2210,$6D00,$0090,$2F00,$4280,$61FF
	dc.w	$FFFF,$FBA2,$F21F,$9000,$F23A,$4823,$FFB8,$60FF,0,$0D78,$2210,$6D00
	dc.w	$0070,$2F00,$4280,$61FF,$FFFF,$FD34,$F21F,$9000,$F23A,$4823,$FF98
	dc.w	$60FF,0,$0D68,$2210,$6D00,$0050,$2228,8,$662E,$2228,4,$0281,$7FFF
	dc.w	$FFFF,$6622,$3210,$0281,0,$7FFF,$0481,0,$3FFF,$67FF,0,$0F84,$F200
	dc.w	$9000,$F201,$4000,$60FF,0,$0D1E,$2F00,$4280,$61FF,$FFFF,$FB2E,$F21F
	dc.w	$9000,$F23A,$4823,$FF54,$60FF,0,$0D04,$60FF,0,$0B5C,$2210,$6D00,$FFF6
	dc.w	$2F00,$4280,$61FF,$FFFF,$FCBA,$F21F,$9000,$F23A,$4823,$FF2E,$60FF,0
	dc.w	$0CEE,$406A,$934F,$0979,$A371,$3F73,$4413,$509F,$8000,$BFCD,0,$C021
	dc.w	$9DC1,$DA99,$4FD2,0,0,$4000,0,$935D,$8DDD,$AAA8,$AC17,0,0,$3FFE,0
	dc.w	$B172,$17F7,$D1CF,$79AC,0,0,$3F56,$C16D,$6F7B,$D0B2,$3F81,$1112,$302C
	dc.w	$712C,$3FA5,$5555,$5555,$4CC1,$3FC5,$5555,$5555,$4A54,$3FE0,0,0,0,0,0
	dcb.w	2,0
	dc.w	$3FFF,0,$8000,0,0,0,$3F73,$8000,$3FFF,0,$8164,$D1F3,$BC03,$0773,$3FBE
	dc.w	$F7CA,$3FFF,0,$82CD,$8698,$AC2B,$A1D7,$3FBD,$F8A9,$3FFF,0,$843A,$28C3
	dc.w	$ACDE,$4046,$3FBC,$D7C9,$3FFF,0,$85AA,$C367,$CC48,$7B15,$BFBD,$E8DA
	dc.w	$3FFF,0,$871F,$6196,$9E8D,$1010,$3FBD,$E85C,$3FFF,0,$8898,$0E80,$92DA
	dc.w	$8527,$3FBE,$BBF1,$3FFF,0,$8A14,$D575,$496E,$FD9A,$3FBB,$80CA,$3FFF,0
	dc.w	$8B95,$C1E3,$EA8B,$D6E7,$BFBA,$8373,$3FFF,0,$8D1A,$DF5B,$7E5B,$A9E6
	dc.w	$BFBE,$9670,$3FFF,0,$8EA4,$398B,$45CD,$53C0,$3FBD,$B700,$3FFF,0,$9031
	dc.w	$DC43,$1466,$B1DC,$3FBE,$EEB0,$3FFF,0,$91C3,$D373,$AB11,$C336,$3FBB
	dc.w	$FD6D,$3FFF,0,$935A,$2B2F,$13E6,$E92C,$BFBD,$B319,$3FFF,0,$94F4,$EFA8
	dc.w	$FEF7,$0961,$3FBD,$BA2B,$3FFF,0,$9694,$2D37,$2018,$5A00,$3FBE,$91D5
	dc.w	$3FFF,0,$9837,$F051,$8DB8,$A96F,$3FBE,$8D5A,$3FFF,0,$99E0,$4593,$20B7
	dc.w	$FA65,$BFBC,$DE7B,$3FFF,0,$9B8D,$39B9,$D54E,$5539,$BFBE,$BAAF,$3FFF,0
	dc.w	$9D3E,$D9A7,$2CFF,$B751,$BFBD,$86DA,$3FFF,0,$9EF5,$3260,$91A1,$11AE
	dc.w	$BFBE,$BEDD,$3FFF,0,$A0B0,$510F,$B971,$4FC2,$3FBC,$C96E,$3FFF,0,$A270
	dc.w	$4303,$0C49,$6819,$BFBE,$C90B,$3FFF,0,$A435,$15AE,$09E6,$809E,$3FBB
	dc.w	$D1DB,$3FFF,0,$A5FE,$D6A9,$B151,$38EA,$3FBC,$E5EB,$3FFF,0,$A7CD,$93B4
	dc.w	$E965,$356A,$BFBE,$C274,$3FFF,0,$A9A1,$5AB4,$EA7C,$0EF8,$3FBE,$A83C
	dc.w	$3FFF,0,$AB7A,$39B5,$A93E,$D337,$3FBE,$CB00,$3FFF,0,$AD58,$3EEA,$42A1
	dc.w	$4AC6,$3FBE,$9301,$3FFF,0,$AF3B,$78AD,$690A,$4375,$BFBD,$8367,$3FFF,0
	dc.w	$B123,$F581,$D2AC,$2590,$BFBE,$F05F,$3FFF,0,$B311,$C412,$A911,$2489
	dc.w	$3FBD,$FB3C,$3FFF,0,$B504,$F333,$F9DE,$6484,$3FBE,$B2FB,$3FFF,0,$B6FD
	dc.w	$91E3,$28D1,$7791,$3FBA,$E2CB,$3FFF,0,$B8FB,$AF47,$62FB,$9EE9,$3FBC
	dc.w	$DC3C,$3FFF,0,$BAFF,$5AB2,$133E,$45FB,$3FBE,$E9AA,$3FFF,0,$BD08,$A39F
	dc.w	$580C,$36BF,$BFBE,$AEFD,$3FFF,0,$BF17,$99B6,$7A73,$1083,$BFBC,$BF51
	dc.w	$3FFF,0,$C12C,$4CCA,$6670,$9456,$3FBE,$F88A,$3FFF,0,$C346,$CCDA,$2497
	dc.w	$6407,$3FBD,$83B2,$3FFF,0,$C567,$2A11,$5506,$DADD,$3FBD,$F8AB,$3FFF,0
	dc.w	$C78D,$74C8,$ABB9,$B15D,$BFBD,$FB17,$3FFF,0,$C9B9,$BD86,$6E2F,$27A3
	dc.w	$BFBE,$FE3C,$3FFF,0,$CBEC,$14FE,$F272,$7C5D,$BFBB,$B6F8,$3FFF,0,$CE24
	dc.w	$8C15,$1F84,$80E4,$BFBC,$EE53,$3FFF,0,$D063,$33DA,$EF2B,$2595,$BFBD
	dc.w	$A4AE,$3FFF,0,$D2A8,$1D91,$F12A,$E45A,$3FBC,$9124,$3FFF,0,$D4F3,$5AAB
	dc.w	$CFED,$FA1F,$3FBE,$B243,$3FFF,0,$D744,$FCCA,$D69D,$6AF4,$3FBD,$E69A
	dc.w	$3FFF,0,$D99D,$15C2,$78AF,$D7B6,$BFB8,$BC61,$3FFF,0,$DBFB,$B797,$DAF2
	dc.w	$3755,$3FBD,$F610,$3FFF,0,$DE60,$F482,$5E0E,$9124,$BFBD,$8BE1,$3FFF,0
	dc.w	$E0CC,$DEEC,$2A94,$E111,$3FBA,$CB12,$3FFF,0,$E33F,$8972,$BE8A,$5A51
	dc.w	$3FBB,$9BFE,$3FFF,0,$E5B9,$06E7,$7C83,$48A8,$3FBC,$F2F4,$3FFF,0,$E839
	dc.w	$6A50,$3C4B,$DC68,$3FBE,$F22F,$3FFF,0,$EAC0,$C6E7,$DD24,$392F,$BFBD
	dc.w	$BF4A,$3FFF,0,$ED4F,$301E,$D994,$2B84,$3FBE,$C01A,$3FFF,0,$EFE4,$B99B
	dc.w	$DCDA,$F5CB,$3FBE,$8CAC,$3FFF,0,$F281,$773C,$59FF,$B13A,$BFBC,$BB3F
	dc.w	$3FFF,0,$F525,$7D15,$2486,$CC2C,$3FBE,$F73A,$3FFF,0,$F7D0,$DF73,$0AD1
	dc.w	$3BB9,$BFB8,$B795,$3FFF,0,$FA83,$B2DB,$722A,$033A,$3FBE,$F84B,$3FFF,0
	dc.w	$FD3E,$0C0C,$F486,$C175,$BFBE,$F581,$F210,$D080,$2210,$3228,4,$F22E
	dc.w	$6800,$FF84,$0281,$7FFF,$FFFF,$0C81,$3FB9,$8000,$6C04,$6000,$0088
	dc.w	$0C81,$400D,$80C0,$6F04,$6000,$007C,$F200,$0080,$F23C,$44A3,$4280,0
	dc.w	$F22E,$6080,$FF54,$2F02,$43FA,$FBBC,$F22E,$4080,$FF54,$222E,$FF54
	dc.w	$2401,$0281,0,$003F,$E981,$D3C1,$EC82,$2202,$E281,$9481,$0682,0,$3FFF
	dc.w	$F227,$E00C,$F23C,$44A3,$3C80,0,$2D59,$FF84,$2D59,$FF88,$2D59,$FF8C
	dc.w	$3D59,$FF90,$F200,$0428,$3D59,$FF94,$426E,$FF96,$42AE,$FF98,$D36E
	dc.w	$FF84,$F23A,$4823,$FB22,$D36E,$FF90,$6000,$0100,$0C81,$3FFF,$8000
	dc.w	$6E12,$F200,$9000,$F23C,$4422,$3F80,0,$60FF,0,$07B4,$222E,$FF84,$0C81
	dcb.w	2,0
	dc.w	$6D06,$60FF,0,$0764,$60FF,0,$0666,$F200,$9000,$F23C,$4400,$3F80,0
	dc.w	$2210,$0081,$0080,1,$F201,$4422,$60FF,0,$077E,$F210,$D080,$2210,$3228
	dc.w	4,$F22E,$6800,$FF84,$0281,$7FFF,$FFFF,$0C81,$3FB9,$8000,$6C04,$6000
	dc.w	$FF90,$0C81,$400B,$9B07,$6F04,$6000,$FF84,$F200,$0080,$F23A,$54A3
	dc.w	$FA62,$F22E,$6080,$FF54,$2F02,$43FA,$FAC6,$F22E,$4080,$FF54,$222E
	dc.w	$FF54,$2401,$0281,0,$003F,$E981,$D3C1,$EC82,$2202,$E281,$9481,$0682,0
	dc.w	$3FFF,$F227,$E00C,$F200,$0500,$F23A,$54A3,$FA2C,$2D59,$FF84,$F23A
	dc.w	$4923,$FA2A,$2D59,$FF88,$2D59,$FF8C,$F200,$0428,$3D59,$FF90,$F200
	dc.w	$0828,$3D59,$FF94,$426E,$FF96,$42AE,$FF98,$F23A,$4823,$FA14,$D36E
	dc.w	$FF84,$D36E,$FF90,$F200,$0080,$F200,$04A3,$F23A,$5500,$FA1E,$F23A
	dc.w	$5580,$FA20,$F200,$0523,$F200,$05A3,$F23A,$5522,$FA1A,$F23A,$55A2
	dc.w	$FA1C,$F200,$0523,$F200,$05A3,$F23A,$5522,$FA16,$F200,$01A3,$F200
	dc.w	$0523,$F200,$0C22,$F200,$0822,$F21F,$D030,$F22E,$4823,$FF84,$F22E
	dc.w	$4822,$FF90,$F22E,$4822,$FF84,$F200,$9000,$3D42,$FF84,$241F,$2D7C
	dc.w	$8000,0,$FF88,$42AE,$FF8C,$123C,0,$F22E,$4823,$FF84,$60FF,0,$063E
	dc.w	$F200,$9000,$F23C,$4400,$3F80,0,$2210,$0081,$0080,1,$F201,$4422,$60FF
	dc.w	0,$0630,$2F00,$3229,0,$5BEE,$FF54,$0281,0,$7FFF,$3028,0,$0240,$7FFF
	dc.w	$0C40,$3FFF,$6D00,$00C0,$0C40,$400C,$6E00,$00A4,$F228,$4803,0,$F200
	dc.w	$6000,$F23C,$8800,0,0,$4A29,4,$6B5E,$2F00,$3D69,0,$FF84,$2D69,4,$FF88
	dc.w	$2D69,8,$FF8C,$41EE,$FF84,$61FF,0,$0B2A,$4480,$D09F,$F22E,$D080,$FF84
	dc.w	$0C40,$C001,$6C36,$F21F,$9000,$223C,$8000,0,$0480,$FFFF,$C001,$4480
	dc.w	$0C00,$0020,$6C0A,$E0A9,$42A7,$2F01,$42A7,$6028,$0400,$0020,$E0A9
	dc.w	$2F01,$42A7,$42A7,$601A,$F229,$D080,0,$F21F,$9000,$0640,$3FFF,$4840
	dc.w	$42A7,$2F3C,$8000,0,$2F00,$F200,$B000,$123C,0,$F21F,$4823,$60FF,0
	dc.w	$054C,$201F,$C149,$4A29,0,$6BFF,0,$041C,$60FF,0,$0464,$4A29,4,$6A16
	dc.w	$201F,$F200,$9000,$123C,3,$F229,$4800,0,$60FF,0,$051C,$201F,$2049
	dc.w	$60FF,0,$0586,1,0,$8000,0,0,0,0,0,$422E,$FF65,$2F00,$422E,$FF5C,$600C
	dc.w	$422E,$FF65,$2F00,$1D7C,1,$FF5C,$48E7,$3F00,$3628,0,$3D43,$FF58,$0283
	dc.w	0,$7FFF,$2828,4,$2A28,8,$4A83,$663C,$263C,0,$3FFE,$4A84,$6616,$2805
	dc.w	$4285,$0483,0,$0020,$4286,$EDC4,$6000,$EDAC,$9686,$6022,$4286,$EDC4
	dc.w	$6000,$9686,$EDAC,$2E05,$EDAD,$4486,$0686,0,$0020,$ECAF,$8887,$6006
	dc.w	$0683,0,$3FFE,$3029,0,$3D40,$FF5A,$322E,$FF58,$B181,$0281,0,$8000
	dc.w	$3D41,$FF5E,$0280,0,$7FFF,$2229,4,$2429,8,$4A80,$663C,$203C,0,$3FFE
	dc.w	$4A81,$6616,$2202,$4282,$0480,0,$0020,$4286,$EDC1,$6000,$EDA9,$9086
	dc.w	$6022,$4286,$EDC1,$6000,$9086,$EDA9,$2E02,$EDAA,$4486,$0686,0,$0020
	dc.w	$ECAF,$8287,$6006,$0680,0,$3FFE,$2D43,$FF54,$2F00,$9083,$4286,$4283
	dc.w	$227C,0,0,$4A80,$6C06,$201F,$6000,$006A,$588F,$4A86,$6E0E,$B284,$6608
	dc.w	$B485,$6604,$6000,$0136,$6508,$9485,$9384,$4286,$5283,$4A80,$670E
	dc.w	$D683,$D482,$E391,$55C6,$5289,$5380,$60D4,$202E,$FF54,$4A81,$6616
	dc.w	$2202,$4282,$0480,0,$0020,$4286,$EDC1,$6000,$EDA9,$9086,$601C,$4286
	dc.w	$EDC1,$6000,$6B14,$9086,$EDA9,$2E02,$EDAA,$4486,$0686,0,$0020,$ECAF
	dc.w	$8287,$0C80,0,$41FE,$6C2A,$3D40,$FF90,$2D41,$FF94,$2D42,$FF98,$2C2E
	dc.w	$FF54,$3D46,$FF84,$2D44,$FF88,$2D45,$FF8C,$F22E,$4800,$FF90,$1D7C,1
	dc.w	$FF5D,$6036,$2D41,$FF94,$2D42,$FF98,$0480,0,$3FFE,$3D40,$FF90,$2C2E
	dc.w	$FF54,$0486,0,$3FFE,$2D46,$FF54,$F22E,$4800,$FF90,$3D46,$FF84,$2D44
	dc.w	$FF88,$2D45,$FF8C,$422E,$FF5D,$4A2E,$FF5C,$6722,$2C2E,$FF54,$5386
	dc.w	$B086,$6D18,$6E0E,$B284,$6608,$B485,$6604,$6000,$007A,$6508,$F22E
	dc.w	$4828,$FF84,$5283,$3C2E,$FF5A,$6C04,$F200,$001A,$4286,$3C2E,$FF5E
	dc.w	$7E08,$EEAE,$0283,0,$007F,$8686,$1D43,$FF65,$4CDF,$00FC,$201F,$F200
	dc.w	$9000,$4A2E,$FF5D,$6710,$123C,0,$F23A,$4823,$FDC0,$60FF,0,$02CA,$123C
	dc.w	3,$F200,0,$60FF,0,$02BC,$5283,$0C80,0,8,$6C04,$E1AB,$6002,$4283,$F23C
	dc.w	$4400,0,0,$422E,$FF5D,$6000,$FF94,$2C03,$0286,0,1,$4A86,$6700,$FF86
	dc.w	$5283,$3C2E,$FF5A,$0A86,0,$8000,$3D46,$FF5A,$6000,$FF72,$3028,0,$0240
	dc.w	$7FFF,$0C40,$7FFF,$6738,$0828,7,4,$6706,$103C,0,$4E75,$4A40,$6618
	dc.w	$4AA8,4,$660C,$4AA8,8,$6606,$103C,1,$4E75,$103C,4,$4E75,$61FF,0,$07F6
	dc.w	$4E75,$103C,6,$4E75,$4AA8,8,$6612,$2028,4,$0280,$7FFF,$FFFF,$6606
	dc.w	$103C,2,$4E75,$103C,3,$4E75,$7FFF,0,$FFFF,$FFFF,$FFFF,$FFFF,$4A28,0
	dc.w	$6A38,$00AE,$0A00,$0410,$FF64,$082E,2,$FF62,$660A,$F23C,$4400,$FF80,0
	dc.w	$4E75,$F22E,$D080,$FFDC,$F22E,$9000,$FF60,$F23C,$4480,$BF80,0,$F23C
	dc.w	$44A0,0,0,$4E75,$00AE,$0200,$0410,$FF64,$082E,2,$FF62,$660A,$F23C
	dc.w	$4400,$7F80,0,$4E75,$F22E,$D080,$FFDC,$F22E,$9000,$FF60,$F23C,$4480
	dc.w	$3F80,0,$F23C,$44A0,0,0,$4E75,$00AE,$0100,$2080,$FF64,$082E,5,$FF62
	dc.w	$6608,$F23A,$D080,$FF6A,$4E75,$F22E,$D080,$FFDC,$F22E,$9000,$FF60
	dc.w	$F227,$E004,$F23C,$4500,$7F80,0,$F23C,$4523,0,0,$F21F,$D020,$4E75
	dc.w	$7FFE,0,$FFFF,$FFFF,$FFFF,$FFFF,$FFFE,0,$FFFF,$FFFF,$FFFF,$FFFF,0,0
	dc.w	$8000,0,0,0,$8000,0,$8000,0,0,0,$4A28,0,$6A26,$00AE,$0800,$0A28,$FF64
	dc.w	$F22E,$9000,$FF60,$F23A,$D080,$FFDC,$F23A,$4823,$FFCA,$F200,$A800
	dc.w	$E198,$1D40,$FF64,$4E75,$006E,$0A28,$FF66,$F22E,$9000,$FF60,$F23A
	dc.w	$D080,$FFAC,$F200,$0023,$F200,$A800,$E198,$1D40,$FF64,$4E75,$00AE,0
	dc.w	$1048,$FF64,$1200,$0201,$00C0,$6700,$005A,$3D68,0,$FF84,$2D68,4,$FF88
	dc.w	$2D68,8,$FF8C,$41EE,$FF84,$48E7,$C080,$61FF,0,$0618,$4CDF,$0103,$0C01
	dc.w	$0040,$6610,$4AA8,8,$6618,$4A28,7,$6612,$6000,$0020,$2228,8,$0281,0
	dc.w	$07FF,$6700,$0012,$00AE,0,$0200,$FF64,$6006,$006E,$1248,$FF66,$4A28,0
	dc.w	$6A22,$F22E,$9000,$FF60,$F23A,$D080,$FF14,$F23A,$4823,$FF02,$F200
	dc.w	$A800,$E198,0,0,$1D40,$FF64,$4E75,$F22E,$9000,$FF60,$F23A,$D080,$FEE6
	dc.w	$F23A,$4823,$FEE0,$F200,$A800,$E198,$1D40,$FF64,$4E75,$006E,$1248
	dc.w	$FF66,$F22E,$9000,$FF60,$F23A,$D080,$FEC2,$F23A,$4823,$FEBC,$F200
	dc.w	$A800,$E198,$1D40,$FF64,$4E75,$F200,$A800,$81AE,$FF64,$6020,$F200
	dc.w	$A800,$81AE,$FF64,$F294,14,$F281,$0032,$006E,$0208,$FF66,$6008,$00AE
	dc.w	$0800,$0208,$FF64,$082E,1,$FF62,$6602,$4E75,$F22E,$9000,$FF60,$F23C
	dc.w	$4480,$3F80,0,$F23A,$48A2,$FE80,$4E75,$1D7C,4,$FF64,$006E,$0208,$FF66
	dc.w	$4E75,$F22E,$9000,$FF60,$F228,$4800,0,$F200,$A800,$0080,0,$0A28,$81AE
	dc.w	$FF64,$4E75,$F22E,$9000,$FF60,$F228,$4800,0,$F200,$A800,$81AE,$FF64
	dcb.w	2,$4E75
	dc.w	$F229,$4800,0,$4A29,0,$6B08,$1D7C,1,$FF64,$4E75,$1D7C,9,$FF64,$4E75
	dc.w	$F228,$4800,0,$4A28,0,$6B08,$1D7C,1,$FF64,$4E75,$1D7C,9,$FF64,$4E75
	dc.w	$F227,$B000,$F23C,$9000,0,0,$F22F,$4400,8,$F21F,$9000,$F22F,$4422,8
	dc.w	$4E75,$F227,$B000,$F23C,$9000,0,0,$F22F,$5400,8,$F21F,$9000,$F22F
	dc.w	$5422,12,$4E75,$F22F,$D080,4,$F22F,$4822,$0010,$4E75,$F227,$B000
	dc.w	$F23C,$9000,0,0,$F22F,$4400,8,$F21F,$9000,$F22F,$4428,8,$4E75,$F227
	dc.w	$B000,$F23C,$9000,0,0,$F22F,$5400,8,$F21F,$9000,$F22F,$5428,12,$4E75
	dc.w	$F22F,$D080,4,$F22F,$4828,$0010,$4E75,$F227,$B000,$F23C,$9000,0,0
	dc.w	$F22F,$4400,8,$F21F,$9000,$F22F,$4423,8,$4E75,$F227,$B000,$F23C,$9000
	dcb.w	2,0
	dc.w	$F22F,$5400,8,$F21F,$9000,$F22F,$5423,12,$4E75,$F22F,$D080,4,$F22F
	dc.w	$4823,$0010,$4E75,$F227,$B000,$F23C,$9000,0,0,$F22F,$4400,8,$F21F
	dc.w	$9000,$F22F,$4420,8,$4E75,$F227,$B000,$F23C,$9000,0,0,$F22F,$5400,8
	dc.w	$F21F,$9000,$F22F,$5420,12,$4E75,$F22F,$D080,4,$F22F,$4820,$0010
	dc.w	$4E75,$F22F,$4418,4,$4E75,$F22F,$5418,4,$4E75,$F22F,$4818,4,$4E75
	dc.w	$F22F,$441A,4,$4E75,$F22F,$541A,4,$4E75,$F22F,$481A,4,$4E75,$F22F
	dc.w	$4404,4,$4E75,$F22F,$5404,4,$4E75,$F22F,$4804,4,$4E75,$F22F,$4401,4
	dc.w	$4E75,$F22F,$5401,4,$4E75,$F22F,$4801,4,$4E75,$F22F,$4403,4,$4E75
	dc.w	$F22F,$5403,4,$4E75,$F22F,$4803,4,$4E75,$4A28,0,$6B10,$F23C,$4400,0,0
	dc.w	$1D7C,4,$FF64,$4E75,$F23C,$4400,$8000,0,$1D7C,12,$FF64,$4E75,$4A29,0
	dc.w	$6BEA,$60D8,$4A28,0,$6B10,$F23C,$4400,$7F80,0,$1D7C,2,$FF64,$4E75
	dc.w	$F23C,$4400,$FF80,0,$1D7C,10,$FF64,$4E75,$4A29,0,$6BEA,$60D8,$4A28,0
	dc.w	$6BA4,$60D0,$4A28,0,$6B00,$FBA2,$60C6,$4A28,0,$6B16,$60BE,$4A28,0
	dc.w	$6B0E,$F23C,$4400,$3F80,0,$422E,$FF64,$4E75,$F23C,$4400,$BF80,0,$1D7C
	dc.w	8,$FF64,$4E75,$3FFF,0,$C90F,$DAA2,$2168,$C235,$BFFF,0,$C90F,$DAA2
	dc.w	$2168,$C235,$4A28,0,$6B0E,$F200,$9000,$F23A,$4800,$FFDA,$6000,$FCF2
	dc.w	$F200,$9000,$F23A,$4800,$FFD8,$6000,$FCEC,$F23C,$4480,$3F80,0,$4A28,0
	dc.w	$6A10,$F23C,$4400,$8000,0,$1D7C,12,$FF64,$4E75,$F23C,$4400,0,0,$1D7C
	dc.w	4,$FF64,$4E75,$F23A,$4880,$FA84,$6000,$FB02,$F228,$4880,0,$6000,$FD30
	dc.w	$122E,$FF4F,$67FF,$FFFF,$F782,$0C01,1,$6700,$0078,$0C01,2,$67FF,$FFFF
	dc.w	$FADE,$0C01,4,$67FF,$FFFF,$F766,$60FF,$FFFF,$FCEA,$122E,$FF4F,$67FF
	dc.w	$FFFF,$FAC4,$0C01,1,$67FF,$FFFF,$FABA,$0C01,2,$67FF,$FFFF,$FAB0,$0C01
	dc.w	4,$67FF,$FFFF,$FAA6,$60FF,$FFFF,$FCBC,$122E,$FF4F,$67FF,0,$0044,$0C01
	dc.w	1,$67FF,0,$001E,$0C01,2,$67FF,$FFFF,$FA82,$0C01,4,$67FF,0,$0026,$60FF
	dc.w	$FFFF,$FC8E,$1228,0,$1029,0,$B101,$0201,$0080,$1D41,$FF65,$4A00,$6A00
	dc.w	$FE52,$6000,$FE5E,$422E,$FF65,$2F00,$1228,0,$1029,0,$B101,$0201,$0080
	dc.w	$1D41,$FF65,$0C2E,4,$FF4F,$660C,$41E9,0,$201F,$60FF,$FFFF,$FC2E,$F21F
	dc.w	$9000,$F229,$4800,0,$4A29,0,$6B02,$4E75,$1D7C,8,$FF64,$4E75,$122E
	dc.w	$FF4F,$67FF,$FFFF,$F6A4,$0C01,1,$6700,$FF8E,$0C01,2,$67FF,$FFFF,$F9F4
	dc.w	$0C01,4,$67FF,$FFFF,$F688,$60FF,$FFFF,$FC00,$122E,$FF4F,$67FF,$FFFF
	dc.w	$F9DA,$0C01,1,$67FF,$FFFF,$F9D0,$0C01,2,$67FF,$FFFF,$F9C6,$0C01,4
	dc.w	$67FF,$FFFF,$F9BC,$60FF,$FFFF,$FBD2,$122E,$FF4F,$6700,$FF5A,$0C01,1
	dc.w	$6700,$FF36,$0C01,2,$67FF,$FFFF,$F99C,$0C01,4,$67FF,$FFFF,$FF40,$60FF
	dc.w	$FFFF,$FBA8,$122E,$FF4F,$67FF,$FFFF,$F500,$0C01,1,$67FF,$FFFF,$FD92
	dc.w	$0C01,2,$67FF,$FFFF,$FDB6,$0C01,4,$67FF,$FFFF,$F4E2,$60FF,$FFFF,$FB7A
	dc.w	$122E,$FF4F,$67FF,$FFFF,$F4D2,$0C01,1,$67FF,$FFFF,$FD64,$0C01,2,$67FF
	dc.w	$FFFF,$FD88,$0C01,4,$67FF,$FFFF,$F4B4,$60FF,$FFFF,$FB4C,$122E,$FF4F
	dc.w	$67FF,$FFFF,$F926,$0C01,3,$67FF,$FFFF,$FB38,$60FF,$FFFF,$F916,$122E
	dc.w	$FF4F,$0C01,3,$67FF,$FFFF,$FB24,$60FF,$FFFF,$FB3A,$2F02,$2F03,$2028,4
	dc.w	$2228,8,$EDC0,$2000,$671A,$E5A8,$E9C1,$3022,$8083,$E5A9,$2140,4,$2141
	dc.w	8,$2002,$261F,$241F,$4E75,$EDC1,$2000,$E5A9,$0682,0,$0020,$2141,4
	dc.w	$42A8,8,$2002,$261F,$241F,$4E75,$EDE8,0,4,$660E,$EDE8,0,8,$6700,$0074
	dc.w	$0640,$0020,$4281,$3228,0,$0241,$7FFF,$B041,$6E1C,$9240,$3028,0,$0240
	dc.w	$8000,$8240,$3141,0,$61FF,$FFFF,$FF82,$103C,0,$4E75,$0C01,$0020,$6E20
	dc.w	$E9E8,$0840,4,$2140,4,$2028,8,$E3A8,$2140,8,$0268,$8000,0,$103C,4
	dc.w	$4E75,$0441,$0020,$2028,8,$E3A8,$2140,4,$42A8,8,$0268,$8000,0,$103C,4
	dc.w	$4E75,$0268,$8000,0,$103C,1,$4E75,$51FC

_060ILSP_TOP:	dc.w	$60FF,0,$01FE,0,$60FF,0,$0208,0,$60FF,0,$0490,0,$60FF,0,$0408,0,$60FF
	dc.w	0,$051E,0,$60FF,0,$053C,0,$60FF,0,$055A,0,$60FF,0,$0574,0,$60FF,0
	dc.w	$0594,0,$60FF,0,$05B4,0,$51FC,$51FC,$51FC,$51FC,$51FC,$51FC,$51FC
	dcb.w	$0000003F,$51FC
	dcb.w	$0000003F,$51FC
	dcb.w	$0000003F,$51FC
	dcb.w	$00000014,$51FC
	dc.w	$4E56,$FFF0,$48E7,$3F00,$42EE,$FFF0,$50EE,$FFFF,$6010,$4E56,$FFF0
	dc.w	$48E7,$3F00,$42EE,$FFF0,$51EE,$FFFF,$2E2E,8,$6700,$00AE,$2A2E,12
	dc.w	$2C2E,$0010,$4A2E,$FFFF,$671A,$4A87,$5DEE,$FFFE,$6A02,$4487,$4A85
	dc.w	$5DEE,$FFFD,$6A08,$44FC,0,$4086,$4085,$4A85,$6616,$4A86,$6700,$0046
	dc.w	$BE86,$6306,$CB46,$6000,$0012,$4C47,$6005,$600A,$BE85,$634C,$61FF,0
	dc.w	$0086,$4A2E,$FFFF,$6724,$4A2E,$FFFD,$6702,$4485,$102E,$FFFE,$B12E
	dc.w	$FFFD,$670C,$0C86,$8000,0,$6226,$4486,$6006,$0806,$001F,$661C,$026E
	dc.w	$0010,$FFF0,$44EE,$FFF0,$4A86,$48F6,$0060,$0161,$0014,$4CDF,$00FC
	dc.w	$4E5E,$4E75,$2A2E,12,$2C2E,$0010,$026E,$001C,$FFF0,$006E,2,$FFF0
	dc.w	$44EE,$FFF0,$60D6,$2DAE,12,$0161,$0014,$2DAE,$0010,$0162,$0014,4
	dc.w	$44EE,$FFF0,$4CDF,$00FC,$4E5E,$80FC,0,$4E75,$0C87,0,$FFFF,$621E,$4281
	dc.w	$4845,$4846,$3A06,$8AC7,$3205,$4846,$3A06,$8AC7,$4841,$3205,$4245
	dc.w	$4845,$2C01,$4E75,$42AE,$FFF8,$422E,$FFFC,$4281,$0807,$001F,$660E
	dc.w	$52AE,$FFF8,$E38F,$E38E,$E395,$6000,$FFEE,$2607,$2405,$4842,$4843
	dc.w	$B443,$6606,$323C,$FFFF,$600A,$2205,$82C3,$0281,0,$FFFF,$2F06,$4246
	dc.w	$4846,$2607,$2401,$C4C7,$4843,$C6C1,$2805,$9883,$4844,$3004,$3806
	dc.w	$4A40,$6600,10,$B484,$6304,$5381,$60DE,$2F05,$2C01,$4846,$2A07,$61FF
	dc.w	0,$006A,$2405,$2606,$2A1F,$2C1F,$9C83,$9B82,$64FF,0,$001A,$5381,$4282
	dc.w	$2607,$4843,$4243,$DC83,$DB82,$2607,$4243,$4843,$DA83,$4A2E,$FFFC
	dc.w	$6616,$3D41,$FFF4,$4281,$4845,$4846,$3A06,$4246,$50EE,$FFFC,$6000
	dc.w	$FF6C,$3D41,$FFF6,$3C05,$4846,$4845,$2E2E,$FFF8,$670A,$5387,$E28D
	dc.w	$E296,$51CF,$FFFA,$2A06,$2C2E,$FFF4,$4E75,$2406,$2606,$2805,$4843
	dc.w	$4844,$CCC5,$CAC3,$C4C4,$C6C4,$4284,$4846,$DC45,$D744,$DC42,$D744
	dc.w	$4846,$4245,$4242,$4845,$4842,$DA82,$DA83,$4E75,$4E56,$FFFC,$48E7
	dc.w	$3800,$42EE,$FFFC,$202E,8,$6700,$005A,$222E,12,$6700,$0052,$2400
	dc.w	$2600,$2801,$4843,$4844,$C0C1,$C2C3,$C4C4,$C6C4,$4284,$4840,$D041
	dc.w	$D784,$D042,$D784,$4840,$4241,$4242,$4841,$4842,$D282,$D283,$382E
	dc.w	$FFFC,$0204,$0010,$4A81,$6A04,4,8,$44C4,$C340,$48F6,3,$0161,$0010
	dc.w	$4CDF,$001C,$4E5E,$4E75,$4280,$4281,$382E,$FFFC,$0204,$0010,4,4,$44C4
	dc.w	$60DA,$4E56,$FFFC,$48E7,$3C00,$42EE,$FFFC,$202E,8,$67DA,$222E,12
	dc.w	$67D4,$4205,$4A80,$6C06,$4480,5,1,$4A81,$6C06,$4481,$0A05,1,$2400
	dc.w	$2600,$2801,$4843,$4844,$C0C1,$C2C3,$C4C4,$C6C4,$4284,$4840,$D041
	dc.w	$D784,$D042,$D784,$4840,$4241,$4242,$4841,$4842,$D282,$D283,$4A05
	dc.w	$6708,$4680,$4681,$5280,$D384,$382E,$FFFC,$0204,$0010,$4A81,$6A04,4,8
	dc.w	$44C4,$C340,$48F6,3,$0161,$0010,$4CDF,$003C,$4E5E,$4E75,$4280,$4281
	dc.w	$382E,$FFFC,$0204,$0010,4,4,$44C4,$60DA,$4E56,$FFFC,$48E7,$3800,$42EE
	dc.w	$FFFC,$242E,8,$1036,$0161,12,$1236,$0162,12,1,$49C0,$49C1,$6000,$00B8
	dc.w	$4E56,$FFFC,$48E7,$3800,$42EE,$FFFC,$242E,8,$3036,$0161,12,$3236
	dc.w	$0162,12,2,$48C0,$48C1,$6000,$0092,$4E56,$FFFC,$48E7,$3800,$42EE
	dc.w	$FFFC,$242E,8,$2036,$0161,12,$2236,$0162,12,4,$6000,$0070,$4E56,$FFFC
	dc.w	$48E7,$3800,$42EE,$FFFC,$242E,8,$1036,$0161,12,$1236,$0162,12,1,$49C0
	dc.w	$49C1,$49C2,$6000,$0048,$4E56,$FFFC,$48E7,$3800,$42EE,$FFFC,$242E,8
	dc.w	$3036,$0161,12,$3236,$0162,12,2,$48C0,$48C1,$48C2,$6000,$0020,$4E56
	dc.w	$FFFC,$48E7,$3800,$42EE,$FFFC,$242E,8,$2036,$0161,12,$2236,$0162,12,4
	dc.w	$9480,$42C3,$0203,4,$9280,$B282,$42C4,$8604,$0203,5,$382E,$FFFC,$0204
	dc.w	$001A,$8803,$44C4,$4CDF,$001C,$4E5E,$4E75,0,0,0,0,0,0,$4E71,$4E71
	dc.w	$4E71
Install_FPU_Libraries_End:
	dc.w	$C776,$855E,$0DBB,$AA5C

; --------------------------------------------------------------------------
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
