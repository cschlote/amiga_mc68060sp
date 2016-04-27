head	1.1;
access;
symbols;
locks
	schlote:1.1; strict;
comment	@;; @;


1.1
date	97.04.21.20.35.14;	author schlote;	state Exp;
branches;
next	;


desc
@This is the internal core. Left out for modification !
@


1.1
log
@WorkingVersion
@
text
@**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_ovfl(): 060FPSP entry point for FP Overflow exception.
*
*	This handler should be the first code executed upon taking the
*	FP Overflow exception in an operating system.
*
* XREF **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	set_tag_x() - determine optype of src/dst operands
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	unnorm_fix() - change UNNORM operands to NORM or ZERO
*	load_fpn2() - load dst operand from FP regfile
*	fout() - emulate an opclass 3 instruction
*	tbl_unsupp - add of table of emulation routines for opclass 0,2
*	_fpsp_done() - "callout" for 060FPSP exit (all work done!)
*	_real_ovfl() - "callout" for Overflow exception enabled code
*	_real_inex() - "callout" for Inexact exception enabled code
*	_real_trace() - "callout" for Trace exception code
*
* INPUT ***************************************************************
*	- The system stack contains the FP Ovfl exception stack frame
*	- The fsave frame contains the source operand
*
* OUTPUT **************************************************************
*	Overflow Exception enabled:
*	- The system stack is unchanged
*	- The fsave frame contains the adjusted src op for opclass 0,2
*	Overflow Exception disabled:
*	- The system stack is unchanged
*	- The "exception present" flag in the fsave frame is cleared
*
* ALGORITHM ***********************************************************
*
*        On the 060, if an FP overflow is present as the result of any
* instruction, the 060 will take an overflow exception whether the
* exception is enabled or disabled in the FPCR. For the disabled case,
* This handler emulates the instruction to determine what the correct
* default result should be for the operation. This default result is
* then stored in either the FP regfile, data regfile, or memory.
* Finally, the handler exits through the "callout" _fpsp_done() 
* denoting that no exceptional conditions exist within the machine.
* 	If the exception is enabled, then this handler must create the
* exceptional operand and plave it in the fsave state frame, and store
* the default result (only if the instruction is opclass 3). For 
* exceptions enabled, this handler must exit through the "callout" 
* _real_ovfl() so that the operating system enabled overflow handler
* can handle this case.	
*	Two other conditions exist. First, if overflow was disabled 
* but the inexact exception was enabled, this handler must exit 
* through the "callout" _real_inex() regardless of whether the result
* was inexact.
*	Also, in the case of an opclass three instruction where 
* overflow was disabled and the trace exception was enabled, this
* handler must exit through the "callout" _real_trace().
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_ovfl
_fpsp_ovfl:

*$*	sub.l	#24,sp	* make room for src/dst

	link	a6,#EXC_SIZEOF	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction

	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------*****

	btst	#$5,EXC_LV+EXC_CMDREG(a6)	* is instr an fmove out?
	bne.w	fovfl_out


	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

* since, I believe, only NORMs and DENORMs can come through here,
* maybe we can avoid the subroutine call.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	set_tag_x	* tag the operand type
	move.b	d0,EXC_LV+STAG(a6)	* maybe NORM,DENORM

* bit five of the fp extension word separates the monadic and dyadic operations 
* that can pass through fpsp_ovfl(). remember that fcmp, ftst, and fsincos
* will never take this exception.
	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is operation monadic or dyadic?
	beq.b	fovfl_extract	* monadic

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg
	bsr.l	load_fpn2	* load dst into EXC_LV+FP_DST

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	cmpi.b	#UNNORM	,d0	* is operand an UNNORM?
	bne.b	fovfl_op2_done	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO
fovfl_op2_done:
	move.b	d0,EXC_LV+DTAG(a6)	* save dst optype tag

fovfl_extract:

*$*	move.l	EXC_LV+FP_SRC_EX(a6),TRAP_SRCOP_EX(a6)
*$*	move.l	EXC_LV+FP_SRC_HI(a6),TRAP_SRCOP_HI(a6)
*$*	move.l	EXC_LV+FP_SRC_LO(a6),TRAP_SRCOP_LO(a6)
*$*	move.l	EXC_LV+FP_DST_EX(a6),TRAP_DSTOP_EX(a6)
*$*	move.l	EXC_LV+FP_DST_HI(a6),TRAP_DSTOP_HI(a6)
*$*	move.l	EXC_LV+FP_DST_LO(a6),TRAP_DSTOP_LO(a6)

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec/mode

	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.w	#$007f,d1	* extract extension

	andi.l	#$00ff01ff,EXC_LV+USER_FPSR(a6) * zero all but accured field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

* maybe we can make these entry points ONLY the OVFL entry points of each routine.
	move.l	(tbl_unsupp.l,pc,d1.w*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

* the operation has been emulated. the result is in fp0.
* the EXOP, if an exception occurred, is in fp1.
* we must save the default result regardless of whether
* traps are enabled or disabled.
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0
	bsr.l	store_fpreg

* the exceptional possibilities we have left ourselves with are ONLY overflow
* and inexact. and, the inexact is such that overflow occurred and was disabled
* but inexact was enabled.
	btst	#ovfl_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.b	fovfl_ovfl_on

	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.b	fovfl_inex_on

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6
*$*	add.l	#24,sp
	bra.l	_fpsp_done

* overflow is enabled AND overflow, of course, occurred. so, we have the EXOP
* in fp1. now, simply jump to _real_ovfl()!
fovfl_ovfl_on:
	fmovem.x	fp1,EXC_LV+FP_SRC(a6)	* save EXOP (fp1) to stack

	move.w	#$e005,2+EXC_LV+FP_SRC(a6) 	* save exc status

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* do this after fmovm,other f<op>s!

	unlk	a6

	bra.l	_real_ovfl

* overflow occurred but is disabled. meanwhile, inexact is enabled. therefore,
* we must jump to real_inex().
fovfl_inex_on:

	fmovem.x	fp1,EXC_LV+FP_SRC(a6) 	* save EXOP (fp1) to stack

	move.b	#$c4,1+EXC_LV+EXC_VOFF(a6)	* vector offset = $c4
	move.w	#$e001,2+EXC_LV+FP_SRC(a6) 	* save exc status

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* do this after fmovm,other f<op>s!

	unlk	a6

	bra.l	_real_inex

**********
fovfl_out:


*$*	move.l	EXC_LV+FP_SRC_EX(a6),TRAP_SRCOP_EX(a6)
*$*	move.l	EXC_LV+FP_SRC_HI(a6),TRAP_SRCOP_HI(a6)
*$*	move.l	EXC_LV+FP_SRC_LO(a6),TRAP_SRCOP_LO(a6)

* the src operand is definitely a NORM(!), so tag it as such
	move.b	#NORM,EXC_LV+STAG(a6)	* set src optype tag

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec/mode

	and.l	#$ffff00ff,EXC_LV+USER_FPSR(a6) * zero all but accured field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src operand

	bsr.l	fout

	btst	#ovfl_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.w	fovfl_ovfl_on

	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.w	fovfl_inex_on

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6
*$*	add.l	#24,sp

	btst	#$7,(sp)	* is trace on?
	beq.l	_fpsp_done	* no

	fmove.l	fpiar,$8(sp)	* "Current PC" is in FPIAR	
	move.w	#$2024,$6(sp)	* stk fmt = $2; voff = $024
	bra.l	_real_trace

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_unfl(): 060FPSP entry point for FP Underflow exception.
*
*	This handler should be the first code executed upon taking the
*	FP Underflow exception in an operating system.
*
* xdef **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	set_tag_x() - determine optype of src/dst operands
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	unnorm_fix() - change UNNORM operands to NORM or ZERO
*	load_fpn2() - load dst operand from FP regfile
*	fout() - emulate an opclass 3 instruction
*	tbl_unsupp - add of table of emulation routines for opclass 0,2
*	_fpsp_done() - "callout" for 060FPSP exit (all work done!)
*	_real_ovfl() - "callout" for Overflow exception enabled code
*	_real_inex() - "callout" for Inexact exception enabled code
*	_real_trace() - "callout" for Trace exception code
*
* INPUT ***************************************************************
*	- The system stack contains the FP Unfl exception stack frame
*	- The fsave frame contains the source operand
*
* OUTPUT **************************************************************
*	Underflow Exception enabled:
*	- The system stack is unchanged
*	- The fsave frame contains the adjusted src op for opclass 0,2
*	Underflow Exception disabled:
*	- The system stack is unchanged
*	- The "exception present" flag in the fsave frame is cleared
*
* ALGORITHM ***********************************************************
*	On the 060, if an FP underflow is present as the result of any
* instruction, the 060 will take an underflow exception whether the 
* exception is enabled or disabled in the FPCR. For the disabled case, 
* This handler emulates the instruction to determine what the correct
* default result should be for the operation. This default result is
* then stored in either the FP regfile, data regfile, or memory. 
* Finally, the handler exits through the "callout" _fpsp_done() 
* denoting that no exceptional conditions exist within the machine.
* 	If the exception is enabled, then this handler must create the
* exceptional operand and plave it in the fsave state frame, and store
* the default result (only if the instruction is opclass 3). For
* exceptions enabled, this handler must exit through the "callout" 
* _real_unfl() so that the operating system enabled overflow handler
* can handle this case.	
*	Two other conditions exist. First, if underflow was disabled 
* but the inexact exception was enabled and the result was inexact, 
* this handler must exit through the "callout" _real_inex().
* was inexact.	
*	Also, in the case of an opclass three instruction where 
* underflow was disabled and the trace exception was enabled, this
* handler must exit through the "callout" _real_trace().
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_unfl
_fpsp_unfl:

*$*	sub.l	#24,sp	* make room for src/dst

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------*****

	btst	#$5,EXC_LV+EXC_CMDREG(a6)	* is instr an fmove out?
	bne.w	funfl_out


	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	set_tag_x	* tag the operand type
	move.b	d0,EXC_LV+STAG(a6)	* maybe NORM,DENORM

* bit five of the fp ext word separates the monadic and dyadic operations
* that can pass through fpsp_unfl(). remember that fcmp, and ftst
* will never take this exception.
	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is op monadic or dyadic?
	beq.b	funfl_extract	* monadic

* now, what's left that's not dyadic is fsincos. we can distinguish it 
* from all dyadics by the '011$xx pattern
	btst	#$4,1+EXC_LV+EXC_CMDREG(a6)	* is op an fsincos?
	bne.b	funfl_extract	* yes

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg
	bsr.l	load_fpn2	* load dst into EXC_LV+FP_DST

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	cmpi.b	#UNNORM	,d0	* is operand an UNNORM?
	bne.b	funfl_op2_done	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO
funfl_op2_done:
	move.b	d0,EXC_LV+DTAG(a6)	* save dst optype tag

funfl_extract:

*$*	move.l	EXC_LV+FP_SRC_EX(a6),TRAP_SRCOP_EX(a6)
*$*	move.l	EXC_LV+FP_SRC_HI(a6),TRAP_SRCOP_HI(a6)
*$*	move.l	EXC_LV+FP_SRC_LO(a6),TRAP_SRCOP_LO(a6)
*$*	move.l	EXC_LV+FP_DST_EX(a6),TRAP_DSTOP_EX(a6)
*$*	move.l	EXC_LV+FP_DST_HI(a6),TRAP_DSTOP_HI(a6)
*$*	move.l	EXC_LV+FP_DST_LO(a6),TRAP_DSTOP_LO(a6)

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec/mode

	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.w	#$007f,d1	* extract extension

	andi.l	#$00ff01ff,EXC_LV+USER_FPSR(a6)

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

* maybe we can make these entry points ONLY the OVFL entry points of each routine.
	move.l	(tbl_unsupp.l,pc,d1.w*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0
	bsr.l	store_fpreg

* The `060 FPU multiplier hardware is such that if the result of a
* multiply operation is the smallest possible normalized number
* ($00000000_80000000_00000000), then the machine will take an
* underflow exception. Since this is incorrect, we need to check
* if our emulation, after re-doing the operation, decided that
* no underflow was called for. We do these checks only in
* funfl_{unfl,inex}_on() because w/ both exceptions disabled, this
* special case will simply exit gracefully with the correct result.

* the exceptional possibilities we have left ourselves with are ONLY overflow
* and inexact. and, the inexact is such that overflow occurred and was disabled
* but inexact was enabled.
	btst	#unfl_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.b	funfl_unfl_on

funfl_chkinex:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.b	funfl_inex_on

funfl_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6
*$*	add.l	#24,sp
	bra.l	_fpsp_done

* overflow is enabled AND overflow, of course, occurred. so, we have the EXOP
* in fp1 (don't forget to save fp0). what to do now?
* well, we simply have to get to go to _real_unfl()!
funfl_unfl_on:

* The `060 FPU multiplier hardware is such that if the result of a
* multiply operation is the smallest possible normalized number
* ($00000000_80000000_00000000), then the machine will take an
* underflow exception. Since this is incorrect, we check here to see
* if our emulation, after re-doing the operation, decided that
* no underflow was called for.
	btst	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6)
	beq.w	funfl_chkinex

funfl_unfl_on2:
	fmovem.x	fp1,EXC_LV+FP_SRC(a6)	* save EXOP (fp1) to stack

	move.w	#$e003,2+EXC_LV+FP_SRC(a6) 	* save exc status

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* do this after fmovm,other f<op>s!

	unlk	a6

	bra.l	_real_unfl

* undeflow occurred but is disabled. meanwhile, inexact is enabled. therefore,
* we must jump to real_inex().
funfl_inex_on:

* The `060 FPU multiplier hardware is such that if the result of a
* multiply operation is the smallest possible normalized number
* ($00000000_80000000_00000000), then the machine will take an
* underflow exception. 
* But, whether bogus or not, if inexact is enabled AND it occurred,
* then we have to branch to real_inex.

	btst	#inex2_bit,EXC_LV+FPSR_EXCEPT(a6)
	beq.w	funfl_exit

funfl_inex_on2:

	fmovem.x	fp1,EXC_LV+FP_SRC(a6) 	* save EXOP to stack

	move.b	#$c4,1+EXC_LV+EXC_VOFF(a6)	* vector offset = $c4
	move.w	#$e001,2+EXC_LV+FP_SRC(a6) 	* save exc status

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* do this after fmovm,other f<op>s!

	unlk	a6

	bra.l	_real_inex

*********
funfl_out:


*$*	move.l	EXC_LV+FP_SRC_EX(a6),TRAP_SRCOP_EX(a6)
*$*	move.l	EXC_LV+FP_SRC_HI(a6),TRAP_SRCOP_HI(a6)
*$*	move.l	EXC_LV+FP_SRC_LO(a6),TRAP_SRCOP_LO(a6)

* the src operand is definitely a NORM(!), so tag it as such
	move.b	#NORM,EXC_LV+STAG(a6)	* set src optype tag

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec/mode

	and.l	#$ffff00ff,EXC_LV+USER_FPSR(a6) * zero all but accured field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src operand

	bsr.l	fout

	btst	#unfl_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.w	funfl_unfl_on2

	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6)
	bne.w	funfl_inex_on2

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6
*$*	add.l	#24,sp

	btst	#$7,(sp)	* is trace on?
	beq.l	_fpsp_done	* no

	fmove.l	fpiar,$8(sp)	* "Current PC" is in FPIAR
	move.w	#$2024,$6(sp)	* stk fmt = $2; voff = $024
	bra.l	_real_trace












**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_unsupp(): 060FPSP entry point for FP "Unimplemented
*	        Data Type" exception.
*
*	This handler should be the first code executed upon taking the
*	FP Unimplemented Data Type exception in an operating system.
*
* xdef **
*	_imem_read_{word,dc.l}() - read instruction word/longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	set_tag_x() - determine optype of src/dst operands
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	unnorm_fix() - change UNNORM operands to NORM or ZERO
*	load_fpn2() - load dst operand from FP regfile
*	load_fpn1() - load src operand from FP regfile
*	fout() - emulate an opclass 3 instruction
*	tbl_unsupp - add of table of emulation routines for opclass 0,2
*	_real_inex() - "callout" to operating system inexact handler
*	_fpsp_done() - "callout" for exit; work all done
*	_real_trace() - "callout" for Trace enabled exception
*	funimp_skew() - adjust fsave src ops to "incorrect" value
*	_real_snan() - "callout" for SNAN exception
*	_real_operr() - "callout" for OPERR exception
*	_real_ovfl() - "callout" for OVFL exception
*	_real_unfl() - "callout" for UNFL exception
*	get_packed() - fetch packed operand from memory
*		
* INPUT ***************************************************************
*	- The system stack contains the "Unimp Data Type" stk frame
*	- The fsave frame contains the ssrc op (for UNNORM/DENORM)
* 		
* OUTPUT **************************************************************
*	If Inexact exception (opclass 3):
*	- The system stack is changed to an Inexact exception stk frame
*	If SNAN exception (opclass 3):	
*	- The system stack is changed to an SNAN exception stk frame
*	If OPERR exception (opclass 3):	
*	- The system stack is changed to an OPERR exception stk frame
*	If OVFL exception (opclass 3):	
*	- The system stack is changed to an OVFL exception stk frame
*	If UNFL exception (opclass 3):	
*	- The system stack is changed to an UNFL exception stack frame
*	If Trace exception enabled:	
*	- The system stack is changed to a Trace exception stack frame
*	Else: (normal case)
*	- Correct result has been stored as appropriate
*		
* ALGORITHM ***********************************************************
*	Two main instruction types can enter here: (1) DENORM or UNNORM
* unimplemented data types. These can be either opclass 0,2 or 3 
* instructions, and (2) PACKED unimplemented data format instructions
* also of opclasses 0,2, or 3.	
*	For UNNORM/DENORM opclass 0 and 2, the handler fetches the src
* operand from the fsave state frame and the dst operand (if dyadic)
* from the FP register file. The instruction is then emulated by 
* choosing an emulation routine from a table of routines indexed by
* instruction type. Once the instruction has been emulated and result
* saved, then we check to see if any enabled exceptions resulted from
* instruction emulation. If none, then we exit through the "callout"
* _fpsp_done(). If there is an enabled FP exception, then we insert
* this exception into the FPU in the fsave state frame and then exit
* through _fpsp_done().	
*	PACKED opclass 0 and 2 is similar in how the instruction is
* emulated and exceptions handled. The differences occur in how the
* handler loads the packed op (by calling get_packed() routine) and
* by the fact that a Trace exception could be pending for PACKED ops.
* If a Trace exception is pending, then the current exception stack
* frame is changed to a Trace exception stack frame and an exit is
* made through _real_trace().	
*	For UNNORM/DENORM opclass 3, the actual move out to memory is
* performed by calling the routine fout(). If no exception should occur
* as the result of emulation, then an exit either occurs through
* _fpsp_done() or through _real_trace() if a Trace exception is pending
* (a Trace stack frame must be created here, too). If an FP exception
* should occur, then we must create an exception stack frame of that
* type and jump to either _real_snan(), _real_operr(), _real_inex(),
* _real_unfl(), or _real_ovfl() as appropriate. PACKED opclass 3 
* emulation is performed in a similar manner.
*		
**-------------------------------------------------------------------------------------------------

*
* (1) DENORM and UNNORM (unimplemented) data types:
*
*	post-instruction
*	*****************
*	*      EA
*	 pre-instruction	*
* 	*****************	*****************
*	* $0 *  $0dc  *	* $3 *  $0dc  *
*	*****************	*****************
*	*     Next	*	*     Next
*	*      PC	*	*      PC
*	*****************	*****************
*	*      SR	*	*      SR
*	*****************	*****************
*
* (2) PACKED format (unsupported) opclasses two and three:
*	*****************
*	*      EA
*	*
*	*****************
*	* $2 *  $0dc
*	*****************
*	*     Next
*	*      PC
*	*****************
*	*      SR
*	*****************
*
	xdef	_fpsp_unsupp
_fpsp_unsupp:

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* save fp state

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor mode?
	bne.b	fu_s
fu_u:
	move.l	usp,a0	* fetch user stack pointer
	move.l	a0,EXC_LV+EXC_A7(a6)	* save on stack
	bra.b	fu_cont
* if the exception is an opclass zero or two unimplemented data type
* exception, then the a7' calculated here is wrong since it doesn't
* stack an ea. however, we don't need an a7' for this case anyways.
fu_s:
	lea	$4+EXC_LV+EXC_EA(a6),a0	* load old a7'
	move.l	a0,EXC_LV+EXC_A7(a6)	* save on stack

fu_cont:

* the FPIAR holds the "current PC" of the faulting instruction
* the FPIAR should be set correctly for ALL exceptions passing through
* this point.
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)	* store OPWORD and EXTWORD

****************************

	clr.b	EXC_LV+SPCOND_FLG(a6)	* clear special condition flag

* Separate opclass three (fpn-to-mem) ops since they have a different
* stack frame and protocol.
	btst	#$5,EXC_LV+EXC_CMDREG(a6)	* is it an fmove out?
	bne.w	fu_out	* yes

* Separate packed opclass two instructions.
	bfextu	EXC_LV+EXC_CMDREG(a6){0:6},d0
	cmpi.b	#$13     ,d0
	beq.w	fu_in_pack


* I'm not sure at this point what FPSR bits are valid for this instruction.
* so, since the emulation routines re-create them anyways, zero exception field
	andi.l	#$00ff00ff,EXC_LV+USER_FPSR(a6) * zero exception field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

* Opclass two w/ memory-to-fpn operation will have an incorrect extended
* precision format if the src format was single or double and the 
* source data type was an INF, NAN, DENORM, or UNNORM
	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to input
	bsr.l	fix_skewed_ops

* we don't know whether the src operand or the dst operand (or both) is the
* UNNORM or DENORM. call the function that tags the operand type. if the
* input is an UNNORM, then convert it to a NORM, DENORM, or ZERO.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	set_tag_x	* tag the operand type
	cmpi.b	#UNNORM	,d0	* is operand an UNNORM?
	bne.b	fu_op2	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO

fu_op2:
	move.b	d0,EXC_LV+STAG(a6)	* save src optype tag

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg

* bit five of the fp extension word separates the monadic and dyadic operations 
* at this point
	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is operation monadic or dyadic?
	beq.b	fu_extract	* monadic
	cmpi.b	#$3a,1+EXC_LV+EXC_CMDREG(a6)	* is operation an ftst?
	beq.b	fu_extract	* yes, so it's monadic, too

	bsr.l	load_fpn2	* load dst into EXC_LV+FP_DST

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	cmpi.b	#UNNORM	,d0	* is operand an UNNORM?
	bne.b	fu_op2_done	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO
fu_op2_done:
	move.b	d0,EXC_LV+DTAG(a6)	* save dst optype tag

fu_extract:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* fetch rnd mode/prec

	bfextu	1+EXC_LV+EXC_CMDREG(a6){1:7},d1 * extract extension

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

	move.l	(tbl_unsupp.l,pc,d1.l*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

*
* Exceptions in order of precedence:
* 	BSUN	: none
*	SNAN	: all dyadic ops
*	OPERR	: fsqrt(-NORM)
*	OVFL	: all except ftst,fcmp
*	UNFL	: all except ftst,fcmp
*	DZ	: fdiv
* 	INEX2	: all except ftst,fcmp
*	INEX1	: none (packed doesn't go through here)
*

* we determine the highest priority exception(if any) set by the
* emulation routine that has also been enabled by the user.
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions set
	bne.b	fu_in_ena	* some are enabled

fu_in_cont:
* fcmp and ftst do not store any result.
	move.b	1+EXC_LV+EXC_CMDREG(a6),d0	* fetch extension
	andi.b	#$38,d0	* extract bits 3-5
	cmpi.b	#$38,d0	* is instr fcmp or ftst?
	beq.b	fu_in_exit	* yes

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg
	bsr.l	store_fpreg	* store the result

fu_in_exit:

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	bra.l	_fpsp_done

fu_in_ena:
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enabled
	bfffo	d0{24:8},d0	* find highest priority exception
	bne.b	fu_in_exc	* there is at least one set

*
* No exceptions occurred that were also enabled. Now:
*
*   	if (OVFL ## ovfl_disabled ## inexact_enabled) {
*	    branch to _real_inex() (even if the result was exact!);
*     	} else {
*	    save the result in the proper fp reg (unless the op is fcmp or ftst);
*	    return;
*     	}
*
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * was overflow set?
	beq.b	fu_in_cont	* no
	
fu_in_ovflchk:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6) * was inexact enabled?
	beq.b	fu_in_cont	* no
	bra.w	fu_in_EXC_LV+EXC_ovfl	* go insert overflow frame

*
* An exception occurred and that exception was enabled:
*
*	shift enabled exception field into lo byte of d0;
*	if (((INEX2 || INEX1) ## inex_enabled ## OVFL ## ovfl_disabled) ||
*	    ((INEX2 || INEX1) ## inex_enabled ## UNFL ## unfl_disabled)) {
*	/*
*	 * this is the case where we must call _real_inex() now or else
*	 * there will be no other way to pass it the exceptional operand
*	 */
*	call _real_inex();
*	} else {
*	restore exc state (SNAN||OPERR||OVFL||UNFL||DZ||INEX) into the FPU;
*	}
*	    	
fu_in_exc:
	subi.l	#24,d0	* fix offset to be 0-8
	cmpi.b	#$6,d0	* is exception INEX? (6)
	bne.b	fu_in_EXC_LV+EXC_exit	* no

* the enabled exception was inexact
	btst	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did disabled underflow occur?
	bne.w	fu_in_EXC_LV+EXC_unfl	* yes
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did disabled overflow occur?
	bne.w	fu_in_EXC_LV+EXC_ovfl	* yes

* here, we insert the correct fsave status value into the fsave frame for the
* corresponding exception. the operand in the fsave frame should be the original 
* src operand.
fu_in_EXC_LV+EXC_exit:
	move.l	d0,-(sp)	* save d0
	bsr.l	funimp_skew	* skew sgl or dbl inputs
	move.l	(sp)+,d0	* restore d0

	move.w	((tbl_except).b,pc,d0.w*2),2+EXC_LV+FP_SRC(a6) * create exc status

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* restore src op

	unlk	a6

	bra.l	_fpsp_done

tbl_except:
	dc.w	$e000,$e006,$e004,$e005
	dc.w	$e003,$e002,$e001,$e001

fu_in_EXC_LV+EXC_unfl:
	move.w	#$4,d0
	bra.b	fu_in_EXC_LV+EXC_exit
fu_in_EXC_LV+EXC_ovfl:
	move.w	#$03,d0
	bra.b	fu_in_EXC_LV+EXC_exit

* If the input operand to this operation was opclass two and a single
* or double precision denorm, inf, or nan, the operand needs to be
* "corrected" in order to have the proper equivalent extended precision
* number.
	xdef	fix_skewed_ops
fix_skewed_ops:
	bfextu	EXC_LV+EXC_CMDREG(a6){0:6},d0 * extract opclass,src fmt
	cmpi.b	#$11,d0	* is class = 2 # fmt = sgl?
	beq.b	fso_sgl	* yes
	cmpi.b	#$15,d0	* is class = 2 # fmt = dbl?
	beq.b	fso_dbl	* yes
	rts		* no

fso_sgl:
	move.w	LOCAL_EX(a0),d0	* fetch src exponent
	andi.w	#$7fff,d0	* strip sign
	cmpi.w	#$3f80,d0	* is |exp| == $3f80?
	beq.b	fso_sgl_dnrm_zero	* yes
	cmpi.w	#$407f,d0	* no; is |exp| == $407f?
	beq.b	fso_infnan	* yes
	rts		* no

fso_sgl_dnrm_zero:
	andi.l	#$7fffffff,LOCAL_HI(a0) * clear j-bit
	beq.b	fso_zero	* it's a skewed zero
fso_sgl_dnrm:
* here, we count on norm not to alter a0...
	bsr.l	norm	* normalize mantissa
	neg.w	d0	* -shft amt
	addi.w	#$3f81,d0	* adjust new exponent
	andi.w	#$8000,LOCAL_EX(a0) 	* clear old exponent
	or.w	d0,LOCAL_EX(a0)	* insert new exponent
	rts

fso_zero:
	andi.w	#$8000,LOCAL_EX(a0)	* clear bogus exponent
	rts

fso_infnan:
	andi.b	#$7f,LOCAL_HI(a0) 	* clear j-bit
	ori.w	#$7fff,LOCAL_EX(a0)	* make exponent = $7fff
	rts

fso_dbl:
	move.w	LOCAL_EX(a0),d0	* fetch src exponent
	andi.w	#$7fff,d0	* strip sign
	ICMP.w	d0,#$3c00	* is |exp| == $3c00?
	beq.b	fso_dbl_dnrm_zero	* yes
	ICMP.w	d0,#$43ff	* no; is |exp| == $43ff?
	beq.b	fso_infnan	* yes
	rts		* no

fso_dbl_dnrm_zero:
	andi.l	#$7fffffff,LOCAL_HI(a0) * clear j-bit
	bne.b	fso_dbl_dnrm	* it's a skewed denorm
	tst.l	LOCAL_LO(a0)	* is it a zero?
	beq.b	fso_zero	* yes
fso_dbl_dnrm:
* here, we count on norm not to alter a0...
	bsr.l	norm	* normalize mantissa
	neg.w	d0	* -shft amt
	addi.w	#$3c01,d0	* adjust new exponent
	andi.w	#$8000,LOCAL_EX(a0) 	* clear old exponent
	or.w	d0,LOCAL_EX(a0)	* insert new exponent
	rts

***

* fmove out took an unimplemented data type exception.
* the src operand is in EXC_LV+FP_SRC. Call _fout() to write out the result and
* to determine which exceptions, if any, to take.
fu_out:

* Separate packed move outs from the UNNORM and DENORM move outs.
	bfextu	EXC_LV+EXC_CMDREG(a6){3:3},d0
	ICMP.b	d0,#$3
	beq.w	fu_out_pack
	ICMP.b	d0,#$7
	beq.w	fu_out_pack


* I'm not sure at this point what FPSR bits are valid for this instruction.
* so, since the emulation routines re-create them anyways, zero exception field.
* fmove out doesn't affect ccodes.
	and.l	#$ffff00ff,EXC_LV+USER_FPSR(a6) * zero exception field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

* the src can ONLY be a DENORM or an UNNORM! so, don't make any big subroutine
* call here. just figure out what it is...
	move.w	EXC_LV+FP_SRC_EX(a6),d0	* get exponent
	andi.w	#$7fff,d0	* strip sign
	beq.b	fu_out_denorm	* it's a DENORM

	lea	EXC_LV+FP_SRC(a6),a0
	bsr.l	unnorm_fix	* yes; fix it

	move.b	d0,EXC_LV+STAG(a6)

	bra.b	fu_out_cont
fu_out_denorm:
	move.b	#DENORM,EXC_LV+STAG(a6)
fu_out_cont:

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* fetch rnd mode/prec

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src operand

	move.l	(a6),EXC_LV+EXC_A6(a6)	* in case a6 changes
	bsr.l	fout	* call fmove out routine

* Exceptions in order of precedence:
* 	BSUN	: none
*	SNAN	: none
*	OPERR	: fmove.{b,w,l} out of large UNNORM
*	OVFL	: fmove.{s,d}
*	UNFL	: fmove.{s,d,x}
*	DZ	: none
* 	INEX2	: all
*	INEX1	: none (packed doesn't travel through here)

* determine the highest priority exception(if any) set by the
* emulation routine that has also been enabled by the user.
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions enabled
	bne.w	fu_out_ena	* some are enabled

fu_out_done:

	move.l	EXC_LV+EXC_A6(a6),(a6)	* in case a6 changed

* on extended precision opclass three instructions using pre-decrement or
* post-increment addressing mode, the address register is not updated. is the
* address register was the stack pointer used from user mode, then let's update
* it here. if it was used from supervisor mode, then we have to handle this
* as a special case.
	btst	#$5,EXC_LV+EXC_SR(a6)
	bne.b	fu_out_done_s

	move.l	EXC_LV+EXC_A7(a6),a0	* restore a7
	move.l	a0,usp

fu_out_done_cont:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	btst	#$7,(sp)	* is trace on?
	bne.b	fu_out_trace	* yes

	bra.l	_fpsp_done

* is the ea mode pre-decrement of the stack pointer from supervisor mode?
* ("fmove.x fpm,-(a7)") if so, 
fu_out_done_s:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	bne.b	fu_out_done_cont

* the extended precision result is still in fp0. but, we need to save it
* somewhere on the stack until we can copy it to its final resting place.
* here, we're counting on the top of the stack to be the old place-holders
* for fp0/fp1 which have already been restored. that way, we can write
* over those destinations with the shifted stack frame.

	fmovem.x	fp0,EXC_LV+FP_SRC(a6)	* put answer on stack

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)

* now, copy the result to the proper place on the stack
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_EX(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$0(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_HI(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_LO(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$8(sp)

	add.l	#LOCAL_SIZE-$8,sp

	btst	#$7,(sp)
	bne.b	fu_out_trace

	bra.l	_fpsp_done

fu_out_ena:
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enabled
	bfffo	d0{24:8},d0	* find highest priority exception
	bne.b	fu_out_exc	* there is at least one set

* no exceptions were set. 
* if a disabled overflow occurred and inexact was enabled but the result
* was exact, then a branch to _real_inex() is made.
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * was overflow set?
	beq.w	fu_out_done	* no

fu_out_ovflchk:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6) * was inexact enabled?
	beq.w	fu_out_done	* no
	bra.w	fu_inex	* yes

*
* The fp move out that took the "Unimplemented Data Type" exception was
* being traced. Since the stack frames are similar, get the "current" PC
* from FPIAR and put it in the trace stack frame then jump to _real_trace().
*
*	  UNSUPP FRAME	   TRACE FRAME
* 	*****************	*****************
*	*      EA	*	*    Current
*	*	*	*      PC
*	*****************	*****************
*	* $3 *  $0dc	*	* $2 *  $024
*	*****************	*****************
*	*     Next	*	*     Next
*	*      PC	*	*      PC
*	*****************	*****************
*	*      SR	*	*      SR
*	*****************	*****************
*
fu_out_trace:
	move.w	#$2024,$6(sp)
	fmove.l	fpiar,$8(sp)
	bra.l	_real_trace

* an exception occurred and that exception was enabled. 	
fu_out_exc:
	subi.l	#24,d0	* fix offset to be 0-8

* we don't mess with the existing fsave frame. just re-insert it and
* jump to the "_real_{}()" handler...
	move.w	((tbl_fu_out).b,pc,d0.w*2),d0
	jmp	((tbl_fu_out).b,pc,d0.w*1)

	illegal
	dc.w	8
tbl_fu_out:
	dc.w	tbl_fu_out	- tbl_fu_out	* BSUN can't happen
	dc.w	tbl_fu_out 	- tbl_fu_out	* SNAN can't happen
	dc.w	fu_operr	- tbl_fu_out	* OPERR
	dc.w	fu_ovfl 	- tbl_fu_out	* OVFL
	dc.w	fu_unfl 	- tbl_fu_out	* UNFL
	dc.w	tbl_fu_out	- tbl_fu_out	* DZ can't happen
	dc.w	fu_inex 	- tbl_fu_out	* INEX2
	dc.w	tbl_fu_out	- tbl_fu_out	* INEX1 won't make it here

* for snan,operr,ovfl,unfl, src op is still in EXC_LV+FP_SRC so just 
* frestore it.
fu_snan:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30d8,EXC_LV+EXC_VOFF(a6)	* vector offset = $d8
	move.w	#$e006,2+EXC_LV+FP_SRC(a6)

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6


	bra.l	_real_snan

fu_operr:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30d0,EXC_LV+EXC_VOFF(a6)	* vector offset = $d0
	move.w	#$e004,2+EXC_LV+FP_SRC(a6)

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6


	bra.l	_real_operr

fu_ovfl:
	fmovem.x	fp1,EXC_LV+FP_SRC(a6)	* save EXOP to the stack

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30d4,EXC_LV+EXC_VOFF(a6)	* vector offset = $d4
	move.w	#$e005,2+EXC_LV+FP_SRC(a6)

	frestore	EXC_LV+FP_SRC(a6)	* restore EXOP

	unlk	a6

	bra.l	_real_ovfl

* underflow can happen for extended precision. extended precision opclass
* three instruction exceptions don't update the stack pointer. so, if the
* exception occurred from user mode, then simply update a7 and exit normally.
* if the exception occurred from supervisor mode, check if 
fu_unfl:
	move.l	EXC_LV+EXC_A6(a6),(a6)	* restore a6

	btst	#$5,EXC_LV+EXC_SR(a6)
	bne.w	fu_unfl_s

	move.l	EXC_LV+EXC_A7(a6),a0	* restore a7 whether we need
	move.l	a0,usp	* to or not...
	
fu_unfl_cont:
	fmovem.x	fp1,EXC_LV+FP_SRC(a6)	* save EXOP to the stack

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30cc,EXC_LV+EXC_VOFF(a6)	* vector offset = $cc
	move.w	#$e003,2+EXC_LV+FP_SRC(a6)

	frestore	EXC_LV+FP_SRC(a6)	* restore EXOP

	unlk	a6

	bra.l	_real_unfl

fu_unfl_s:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg * was the <ea> mode -(sp)?
	bne.b	fu_unfl_cont

* the extended precision result is still in fp0. but, we need to save it
* somewhere on the stack until we can copy it to its final resting place
* (where the exc frame is currently). make sure it's not at the top of the
* frame or it will get overwritten when the exc stack frame is shifted "down".
	fmovem.x	fp0,EXC_LV+FP_SRC(a6)	* put answer on stack
	fmovem.x	fp1,EXC_LV+FP_DST(a6)	* put EXOP on stack

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30cc,EXC_LV+EXC_VOFF(a6)	* vector offset = $cc
	move.w	#$e003,2+EXC_LV+FP_DST(a6)

	frestore	EXC_LV+FP_DST(a6)	* restore EXOP

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_EA(sp),LOCAL_SIZE-EXC_LV+EXC_EA-$c(sp)

* now, copy the result to the proper place on the stack
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_EX(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$0(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_HI(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SRC_LO(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$8(sp)

	add.l	#LOCAL_SIZE-$8,sp

	bra.l	_real_unfl

* fmove in and out enter here.
fu_inex:
	fmovem.x	fp1,EXC_LV+FP_SRC(a6)	* save EXOP to the stack

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30c4,EXC_LV+EXC_VOFF(a6)	* vector offset = $c4
	move.w	#$e001,2+EXC_LV+FP_SRC(a6)

	frestore	EXC_LV+FP_SRC(a6)	* restore EXOP

	unlk	a6


	bra.l	_real_inex

**-------------------------------------------------------------------------------------------------
**-------------------------------------------------------------------------------------------------
fu_in_pack:


* I'm not sure at this point what FPSR bits are valid for this instruction.
* so, since the emulation routines re-create them anyways, zero exception field
	andi.l	#$0ff00ff,EXC_LV+USER_FPSR(a6) * zero exception field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	bsr.l	get_packed	* fetch packed src operand

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src
	bsr.l	set_tag_x	* set src optype tag

	move.b	d0,EXC_LV+STAG(a6)	* save src optype tag

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg

* bit five of the fp extension word separates the monadic and dyadic operations 
* at this point
	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is operation monadic or dyadic?
	beq.b	fu_extract_p	* monadic
	ICMP.b	1+EXC_LV+EXC_CMDREG(a6),#$3a	* is operation an ftst?
	beq.b	fu_extract_p	* yes, so it's monadic, too

	bsr.l	load_fpn2	* load dst into EXC_LV+FP_DST

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	ICMP.b	d0,#UNNORM	* is operand an UNNORM?
	bne.b	fu_op2_done_p	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO
fu_op2_done_p:
	move.b	d0,EXC_LV+DTAG(a6)	* save dst optype tag

fu_extract_p:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* fetch rnd mode/prec

	bfextu	1+EXC_LV+EXC_CMDREG(a6){1:7},d1 * extract extension

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

	move.l	(tbl_unsupp.l,pc,d1.l*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

*
* Exceptions in order of precedence:
* 	BSUN	: none
*	SNAN	: all dyadic ops
*	OPERR	: fsqrt(-NORM)
*	OVFL	: all except ftst,fcmp
*	UNFL	: all except ftst,fcmp
*	DZ	: fdiv
* 	INEX2	: all except ftst,fcmp
*	INEX1	: all
*

* we determine the highest priority exception(if any) set by the
* emulation routine that has also been enabled by the user.
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions enabled
	bne.w	fu_in_ena_p	* some are enabled

fu_in_cont_p:
* fcmp and ftst do not store any result.
	move.b	1+EXC_LV+EXC_CMDREG(a6),d0	* fetch extension
	andi.b	#$38,d0	* extract bits 3-5
	ICMP.b	d0,#$38	* is instr fcmp or ftst?
	beq.b	fu_in_exit_p	* yes

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg
	bsr.l	store_fpreg	* store the result

fu_in_exit_p:

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor?
	bne.w	fu_in_exit_s_p	* supervisor

	move.l	EXC_LV+EXC_A7(a6),a0	* update user a7
	move.l	a0,usp

fu_in_exit_cont_p:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6	* unravel stack frame

	btst	#$7,(sp)	* is trace on?
	bne.w	fu_trace_p	* yes

	bra.l	_fpsp_done	* exit to os

* the exception occurred in supervisor mode. check to see if the
* addressing mode was (a7)+. if so, we'll need to shift the
* stack frame "up".
fu_in_exit_s_p:
	btst	#mia7_bit,EXC_LV+SPCOND_FLG(a6) * was ea mode (a7)+
	beq.b	fu_in_exit_cont_p	* no

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6	* unravel stack frame

* shift the stack frame "up". we don't really care about the <ea> field.
	move.l	$4(sp),$10(sp)
	move.l	$0(sp),$c(sp)
	add.l	#$c,sp

	btst	#$7,(sp)	* is trace on?
	bne.w	fu_trace_p	* yes

	bra.l	_fpsp_done	* exit to os

fu_in_ena_p:
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enabled # set
	bfffo	d0{24:8},d0	* find highest priority exception
	bne.b	fu_in_EXC_LV+EXC_p	* at least one was set

*
* No exceptions occurred that were also enabled. Now:
*
*   	if (OVFL ## ovfl_disabled ## inexact_enabled) {
*	    branch to _real_inex() (even if the result was exact!);
*     	} else {
*	    save the result in the proper fp reg (unless the op is fcmp or ftst);
*	    return;
*     	}
*
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * was overflow set?
	beq.w	fu_in_cont_p	* no

fu_in_ovflchk_p:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6) * was inexact enabled?
	beq.w	fu_in_cont_p	* no
	bra.w	fu_in_EXC_LV+EXC_ovfl_p	* do _real_inex() now

*
* An exception occurred and that exception was enabled:
*
*	shift enabled exception field into lo byte of d0;
*	if (((INEX2 || INEX1) ## inex_enabled ## OVFL ## ovfl_disabled) ||
*	    ((INEX2 || INEX1) ## inex_enabled ## UNFL ## unfl_disabled)) {
*	/*
*	 * this is the case where we must call _real_inex() now or else
*	 * there will be no other way to pass it the exceptional operand
*	 */
*	call _real_inex();
*	} else {
*	restore exc state (SNAN||OPERR||OVFL||UNFL||DZ||INEX) into the FPU;
*	}
*	    	
fu_in_EXC_LV+EXC_p:
	subi.l	#24,d0	* fix offset to be 0-8
	ICMP.b	d0,#$6	* is exception INEX? (6 or 7)
	blt.b	fu_in_EXC_LV+EXC_exit_p	* no

* the enabled exception was inexact
	btst	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did disabled underflow occur?
	bne.w	fu_in_EXC_LV+EXC_unfl_p	* yes
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did disabled overflow occur?
	bne.w	fu_in_EXC_LV+EXC_ovfl_p	* yes

* here, we insert the correct fsave status value into the fsave frame for the
* corresponding exception. the operand in the fsave frame should be the original 
* src operand.
* as a reminder for future predicted pain and agony, we are passing in fsave the
* "non-skewed" operand for cases of sgl and dbl src INFs,NANs, and DENORMs.
* this is INCORRECT for enabled SNAN which would give to the user the skewed SNAN!!!
fu_in_EXC_LV+EXC_exit_p:
	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor?
	bne.w	fu_in_EXC_LV+EXC_exit_s_p	* supervisor

	move.l	EXC_LV+EXC_A7(a6),a0	* update user a7
	move.l	a0,usp

fu_in_EXC_LV+EXC_exit_cont_p:
	move.w	((tbl_except_p).b,pc,d0.w*2),2+EXC_LV+FP_SRC(a6)

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* restore src op

	unlk	a6

	btst	#$7,(sp)	* is trace enabled?
	bne.w	fu_trace_p	* yes

	bra.l	_fpsp_done

tbl_except_p:
	dc.w	$e000,$e006,$e004,$e005
	dc.w	$e003,$e002,$e001,$e001

fu_in_EXC_LV+EXC_ovfl_p:
	move.w	#$3,d0
	bra.w	fu_in_EXC_LV+EXC_exit_p

fu_in_EXC_LV+EXC_unfl_p:
	move.w	#$4,d0
	bra.w	fu_in_EXC_LV+EXC_exit_p

fu_in_EXC_LV+EXC_exit_s_p:
	btst	#mia7_bit,EXC_LV+SPCOND_FLG(a6)
	beq.b	fu_in_EXC_LV+EXC_exit_cont_p

	move.w	((tbl_except_p).b,pc,d0.w*2),2+EXC_LV+FP_SRC(a6)

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* restore src op

	unlk	a6	* unravel stack frame

* shift stack frame "up". who cares about <ea> field.
	move.l	$4(sp),$10(sp)
	move.l	$0(sp),$c(sp)
	add.l	#$c,sp

	btst	#$7,(sp)	* is trace on?
	bne.b	fu_trace_p	* yes

	bra.l	_fpsp_done	* exit to os
	
*
* The opclass two PACKED instruction that took an "Unimplemented Data Type" 
* exception was being traced. Make the "current" PC the FPIAR and put it in the 
* trace stack frame then jump to _real_trace().
*		
*	  UNSUPP FRAME	   TRACE FRAME
*	*****************	*****************
*	*      EA	*	*    Current
*	*	*	*      PC
*	*****************	*****************
*	* $2 *	$0dc	* 	* $2 *  $024
*	*****************	*****************
*	*     Next	*	*     Next
*	*      PC	*      	*      PC
*	*****************	*****************
*	*      SR	*	*      SR
*	*****************	*****************
fu_trace_p:
	move.w	#$2024,$6(sp)
	fmove.l	fpiar,$8(sp)

	bra.l	_real_trace

*********************************************************
*********************************************************
fu_out_pack:


* I'm not sure at this point what FPSR bits are valid for this instruction.
* so, since the emulation routines re-create them anyways, zero exception field.
* fmove out doesn't affect ccodes.
	and.l	#$ffff00ff,EXC_LV+USER_FPSR(a6) * zero exception field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0
	bsr.l	load_fpn1

* unlike other opclass 3, unimplemented data type exceptions, packed must be
* able to detect all operand types.
	lea	EXC_LV+FP_SRC(a6),a0
	bsr.l	set_tag_x	* tag the operand type
	ICMP.b	d0,#UNNORM	* is operand an UNNORM?
	bne.b	fu_op2_p	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO

fu_op2_p:
	move.b	d0,EXC_LV+STAG(a6)	* save src optype tag

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* fetch rnd mode/prec

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src operand

	move.l	(a6),EXC_LV+EXC_A6(a6)	* in case a6 changes
	bsr.l	fout	* call fmove out routine

* Exceptions in order of precedence:
* 	BSUN	: no
*	SNAN	: yes
*	OPERR	: if ((k_factor > +17) || (dec. exp exceeds 3 digits))
*	OVFL	: no
*	UNFL	: no
*	DZ	: no
* 	INEX2	: yes
*	INEX1	: no

* determine the highest priority exception(if any) set by the
* emulation routine that has also been enabled by the user.
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions enabled
	bne.w	fu_out_ena_p	* some are enabled

fu_out_exit_p:
	move.l	EXC_LV+EXC_A6(a6),(a6)	* restore a6

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor?
	bne.b	fu_out_exit_s_p	* supervisor

	move.l	EXC_LV+EXC_A7(a6),a0	* update user a7
	move.l	a0,usp

fu_out_exit_cont_p:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6	* unravel stack frame

	btst	#$7,(sp)	* is trace on?
	bne.w	fu_trace_p	* yes

	bra.l	_fpsp_done	* exit to os

* the exception occurred in supervisor mode. check to see if the
* addressing mode was -(a7). if so, we'll need to shift the
* stack frame "down".
fu_out_exit_s_p:
	btst	#mda7_bit,EXC_LV+SPCOND_FLG(a6) * was ea mode -(a7)
	beq.b	fu_out_exit_cont_p	* no

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)

* now, copy the result to the proper place on the stack
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_EX(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$0(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_HI(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_LO(sp),LOCAL_SIZE-EXC_LV+EXC_SR+$8(sp)

	add.l	#LOCAL_SIZE-$8,sp

	btst	#$7,(sp)
	bne.w	fu_trace_p

	bra.l	_fpsp_done

fu_out_ena_p:
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enabled
	bfffo	d0{24:8},d0	* find highest priority exception
	beq.w	fu_out_exit_p

	move.l	EXC_LV+EXC_A6(a6),(a6)	* restore a6

* an exception occurred and that exception was enabled. 	
* the only exception possible on packed move out are INEX, OPERR, and SNAN.
fu_out_EXC_LV+EXC_p:
	ICMP.b	d0,#$1a
	bgt.w	fu_inex_p2
	beq.w	fu_operr_p

fu_snan_p:
	btst	#$5,EXC_LV+EXC_SR(a6)
	bne.b	fu_snan_s_p

	move.l	EXC_LV+EXC_A7(a6),a0
	move.l	a0,usp
	bra.w	fu_snan

fu_snan_s_p:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	bne.w	fu_snan

* the instruction was "fmove.p fpn,-(a7)" from supervisor mode.
* the strategy is to move the exception frame "down" 12 bytes. then, we
* can store the default result where the exception frame was.
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30d8,EXC_LV+EXC_VOFF(a6)	* vector offset = $d0
	move.w	#$e006,2+EXC_LV+FP_SRC(a6) 	* set fsave status

	frestore	EXC_LV+FP_SRC(a6)	* restore src operand

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_EA(sp),LOCAL_SIZE-EXC_LV+EXC_EA-$c(sp)

* now, we copy the default result to it's proper location
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_EX(sp),LOCAL_SIZE-$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_HI(sp),LOCAL_SIZE-$8(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_LO(sp),LOCAL_SIZE-$c(sp)

	add.l	#LOCAL_SIZE-$8,sp


	bra.l	_real_snan

fu_operr_p:
	btst	#$5,EXC_LV+EXC_SR(a6)
	bne.w	fu_operr_p_s

	move.l	EXC_LV+EXC_A7(a6),a0
	move.l	a0,usp
	bra.w	fu_operr

fu_operr_p_s:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	bne.w	fu_operr

* the instruction was "fmove.p fpn,-(a7)" from supervisor mode.
* the strategy is to move the exception frame "down" 12 bytes. then, we
* can store the default result where the exception frame was.
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30d0,EXC_LV+EXC_VOFF(a6)	* vector offset = $d0
	move.w	#$e004,2+EXC_LV+FP_SRC(a6) 	* set fsave status

	frestore	EXC_LV+FP_SRC(a6)	* restore src operand

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_EA(sp),LOCAL_SIZE-EXC_LV+EXC_EA-$c(sp)

* now, we copy the default result to it's proper location
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_EX(sp),LOCAL_SIZE-$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_HI(sp),LOCAL_SIZE-$8(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_LO(sp),LOCAL_SIZE-$c(sp)

	add.l	#LOCAL_SIZE-$8,sp


	bra.l	_real_operr

fu_inex_p2:
	btst	#$5,EXC_LV+EXC_SR(a6)
	bne.w	fu_inex_s_p2

	move.l	EXC_LV+EXC_A7(a6),a0
	move.l	a0,usp
	bra.w	fu_inex

fu_inex_s_p2:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	bne.w	fu_inex

* the instruction was "fmove.p fpn,-(a7)" from supervisor mode.
* the strategy is to move the exception frame "down" 12 bytes. then, we
* can store the default result where the exception frame was.
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0/fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	move.w	#$30c4,EXC_LV+EXC_VOFF(a6) 	* vector offset = $c4
	move.w	#$e001,2+EXC_LV+FP_SRC(a6) 	* set fsave status

	frestore	EXC_LV+FP_SRC(a6)	* restore src operand

	move.l	(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-2+EXC_LV+EXC_PC(sp),LOCAL_SIZE-2+EXC_LV+EXC_PC-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_EA(sp),LOCAL_SIZE-EXC_LV+EXC_EA-$c(sp)

* now, we copy the default result to it's proper location
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_EX(sp),LOCAL_SIZE-$4(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_HI(sp),LOCAL_SIZE-$8(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_DST_LO(sp),LOCAL_SIZE-$c(sp)

	add.l	#LOCAL_SIZE-$8,sp


	bra.l	_real_inex

**-------------------------------------------------------------------------------------------------

*
* if we're stuffing a source operand back into an fsave frame then we
* have to make sure that for single or double source operands that the
* format stuffed is as weird as the hardware usually makes it.
*
	xdef	funimp_skew
funimp_skew:
	bfextu	EXC_LV+EXC_EXTWORD(a6){3:3},d0 * extract src specifier
	ICMP.b	d0,#$1	* was src sgl?
	beq.b	funimp_skew_sgl	* yes
	ICMP.b	d0,#$5	* was src dbl?
	beq.b	funimp_skew_dbl	* yes
	rts

funimp_skew_sgl:
	move.w	EXC_LV+FP_SRC_EX(a6),d0	* fetch DENORM exponent
	andi.w	#$7fff,d0	* strip sign
	beq.b	funimp_skew_sgl_not
	ICMP.w	d0,#$3f80
	bgt.b	funimp_skew_sgl_not	
	neg.w	d0	* make exponent negative
	addi.w	#$3f81,d0	* find amt to shift
	move.l	EXC_LV+FP_SRC_HI(a6),d1	* fetch DENORM hi(man)
	lsr.l	d0,d1	* shift it
	bset	#31,d1	* set j-bit
	move.l	d1,EXC_LV+FP_SRC_HI(a6)	* insert new hi(man)
	andi.w	#$8000,EXC_LV+FP_SRC_EX(a6)	* clear old exponent
	ori.w	#$3f80,EXC_LV+FP_SRC_EX(a6)	* insert new "skewed" exponent
funimp_skew_sgl_not:
	rts

funimp_skew_dbl:
	move.w	EXC_LV+FP_SRC_EX(a6),d0	* fetch DENORM exponent
	andi.w	#$7fff,d0	* strip sign
	beq.b	funimp_skew_dbl_not
	ICMP.w	d0,#$3c00
	bgt.b	funimp_skew_dbl_not	

	tst.b	EXC_LV+FP_SRC_EX(a6)	* make "internal format"
	smi.b	$2+EXC_LV+FP_SRC(a6)
	move.w	d0,EXC_LV+FP_SRC_EX(a6)	* insert exponent with cleared sign
	clr.l	d0	* clear g,r,s
	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src op
	move.w	#$3c01,d1	* pass denorm threshold
	bsr.l	dnrm_lp	* denorm it
	move.w	#$3c00,d0	* new exponent
	tst.b	$2+EXC_LV+FP_SRC(a6)	* is sign set?
	beq.b	fss_dbl_denorm_done	* no
	bset	#15,d0	* set sign
fss_dbl_denorm_done:
	bset	#$7,EXC_LV+FP_SRC_HI(a6)	* set j-bit
	move.w	d0,EXC_LV+FP_SRC_EX(a6)	* insert new exponent
funimp_skew_dbl_not:
	rts

**-------------------------------------------------------------------------------------------------
	xdef	_mem_write2
_mem_write2:
	btst	#$5,EXC_LV+EXC_SR(a6)
	beq.l	_dmem_write
	move.l	$0(a0),EXC_LV+FP_DST_EX(a6)
	move.l	$4(a0),EXC_LV+FP_DST_HI(a6)
	move.l	$8(a0),EXC_LV+FP_DST_LO(a6)
	clr.l	d1
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_effadd(): 060FPSP entry point for FP "Unimplemented
*	     	effective address" exception.
*		
*	This handler should be the first code executed upon taking the
*	FP Unimplemented Effective Address exception in an operating
*	system.	
*		
* xdef **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	set_tag_x() - determine optype of src/dst operands
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	unnorm_fix() - change UNNORM operands to NORM or ZERO
*	load_fpn2() - load dst operand from FP regfile
*	tbl_unsupp - add of table of emulation routines for opclass 0,2
*	decbin() - convert packed data to FP binary data
*	_real_fpu_disabled() - "callout" for "FPU disabled" exception
*	_real_access() - "callout" for access error exception
*	_mem_read() - read extended immediate operand from memory
*	_fpsp_done() - "callout" for exit; work all done
*	_real_trace() - "callout" for Trace enabled exception
*	fmovm_dynamic() - emulate dynamic fmovm instruction
*	fmovm_ctrl() - emulate fmovm control instruction
*		
* INPUT ***************************************************************
*	- The system stack contains the "Unimplemented <ea>" stk frame
* 		
* OUTPUT **************************************************************
*	If access error:	
*	- The system stack is changed to an access error stack frame
*	If FPU disabled:	
*	- The system stack is changed to an FPU disabled stack frame
*	If Trace exception enabled:	
*	- The system stack is changed to a Trace exception stack frame
*	Else: (normal case)	
*	- None (correct result has been stored as appropriate)
*		
* ALGORITHM ***********************************************************
*	This exception handles 3 types of operations:
* (1) FP Instructions using extended precision or packed immediate
*     addressing mode.	
* (2) The "fmovem.x" instruction w/ dynamic register specification.
* (3) The "fmovem.l" instruction w/ 2 or 3 control registers.
*		
*	For immediate data operations, the data is read in w/ a
* _mem_read() "callout", converted to FP binary (if packed), and used
* as the source operand to the instruction specified by the instruction
* word. If no FP exception should be reported ads a result of the 
* emulation, then the result is stored to the destination register and
* the handler exits through _fpsp_done(). If an enabled exc has been
* signalled as a result of emulation, then an fsave state frame
* corresponding to the FP exception type must be entered into the 060
* FPU before exiting. In either the enabled or disabled cases, we 
* must also check if a Trace exception is pending, in which case, we
* must create a Trace exception stack frame from the current exception
* stack frame. If no Trace is pending, we simply exit through
* _fpsp_done().	
*	For "fmovem.x", call the routine fmovm_dynamic() which will 
* decode and emulate the instruction. No FP exceptions can be pending
* as a result of this operation emulation. A Trace exception can be
* pending, though, which means the current stack frame must be changed
* to a Trace stack frame and an exit made through _real_trace().
* For the case of "fmovem.x Dn,-(a7)", where the offending instruction
* was executed from supervisor mode, this handler must store the FP
* register file values to the system stack by itself since
* fmovm_dynamic() can't handle this. A normal exit is made through
* fpsp_done().	
*	For "fmovem.l", fmovm_ctrl() is used to emulate the instruction.
* Again, a Trace exception may be pending and an exit made through
* _real_trace(). Else, a normal exit is made through _fpsp_done().
*		
*	Before any of the above is attempted, it must be checked to
* see if the FPU is disabled. Since the "Unimp <ea>" exception is taken
* before the "FPU disabled" exception, but the "FPU disabled" exception
* has higher priority, we check the disabled bit in the PCR. If set,
* then we must create an 8 word "FPU disabled" exception stack frame
* from the current 4 word exception stack frame. This includes 
* reproducing the effective address of the instruction to put on the 
* new stack frame.	
*		
* 	In the process of all emulation work, if a _mem_read()
* "callout" returns a failing result indicating an access error, then
* we must create an access error stack frame from the current stack
* frame. This information includes a faulting address and a fault-
* status-longword. These are created within this handler.
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_effadd
_fpsp_effadd:

* This exception type takes priority over the "Line F Emulator"
* exception. Therefore, the FPU could be disabled when entering here.
* So, we must check to see if it's disabled and handle that case separately.
	move.l	d0,-(sp)	* save d0
	movec	pcr,d0	* load proc cr
	btst	#$1,d0	* is FPU disabled?
	bne.w	iea_disabled	* yes
	move.l	(sp)+,d0	* restore d0

	link	a6,#LOCAL_SIZE	* init stack frame

	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* PC of instruction that took the exception is the PC in the frame
	move.l	EXC_LV+EXC_PC(a6),EXC_LV+EXC_EXTWPTR(a6)

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)	* store OPWORD and EXTWORD

**-------------------------------------------------------------------------------------------------

	tst.w	d0	* is operation fmovem?
	bmi.w	iea_fmovm	* yes

*
* here, we will have:
* 	fabs	fdabs	fsabs	facos	fmod
*	fadd	fdadd	fsadd	fasin	frem
* 	fcmp	fatan	fscale
*	fdiv	fddiv	fsdiv	fatanh	fsin
*	fint	fcos	fsincos
*	fintrz	fcosh	fsinh
*	fmove	fdmove	fsmove	fetox	ftan
* 	fmul	fdmul	fsmul	fetoxm1	ftanh
*	fneg	fdneg	fsneg	fgetexp	ftentox
*	fsgldiv	fgetman	ftwotox
* 	fsglmul	flog10
* 	fsqrt	flog2
*	fsub	fdsub	fssub	flogn
*	ftst	flognp1
* which can all use f<op>.{x,p}
* so, now it's immediate data extended precision AND PACKED FORMAT!
*
iea_op:
	andi.l	#$00ff00ff,EXC_LV+USER_FPSR(a6)

	btst	#$a,d0	* is src fmt x or p?
	bne.b	iea_op_pack	* packed


	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* pass: ptr to *<data>
	lea	EXC_LV+FP_SRC(a6),a1	* pass: ptr to super addr
	move.l	#$c,d0	* pass: 12 bytes
	bsr.l	_imem_read	* read extended immediate

	tst.l	d1	* did ifetch fail?
	bne.w	iea_iacc	* yes

	bra.b	iea_op_setsrc

iea_op_pack:

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* pass: ptr to *<data>
	lea	EXC_LV+FP_SRC(a6),a1	* pass: ptr to super dst
	move.l	#$c,d0	* pass: 12 bytes
	bsr.l	_imem_read	* read packed operand

	tst.l	d1	* did ifetch fail?
	bne.w	iea_iacc	* yes

* The packed operand is an INF or a NAN if the exponent field is all ones.
	bfextu	EXC_LV+FP_SRC(a6){1:15},d0	* get exp
	ICMP.w	d0,#$7fff	* INF or NAN?
	beq.b	iea_op_setsrc	* operand is an INF or NAN

* The packed operand is a zero if the mantissa is all zero, else it's
* a normal packed op.
	move.b	3+EXC_LV+FP_SRC(a6),d0	* get byte 4
	andi.b	#$0f,d0	* clear all but last nybble
	bne.b	iea_op_gp_not_spec	* not a zero
	tst.l	EXC_LV+FP_SRC_HI(a6)	* is lw 2 zero?
	bne.b	iea_op_gp_not_spec	* not a zero
	tst.l	EXC_LV+FP_SRC_LO(a6)	* is lw 3 zero?
	beq.b	iea_op_setsrc	* operand is a ZERO
iea_op_gp_not_spec:
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to packed op
	bsr.l	decbin	* convert to extended
	fmovem.x	fp0,EXC_LV+FP_SRC(a6)	* make this the srcop

iea_op_setsrc:
	addi.l	#$c,EXC_LV+EXC_EXTWPTR(a6)	* update extension word pointer

* EXC_LV+FP_SRC now holds the src operand.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	set_tag_x	* tag the operand type
	move.b	d0,EXC_LV+STAG(a6)	* could be ANYTHING!!!
	ICMP.b	d0,#UNNORM	* is operand an UNNORM?
	bne.b	iea_op_getdst	* no
	bsr.l	unnorm_fix	* yes; convert to NORM/DENORM/ZERO
	move.b	d0,EXC_LV+STAG(a6)	* set new optype tag
iea_op_getdst:
	clr.b	EXC_LV+STORE_FLG(a6)	* clear "store result" boolean

	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is operation monadic or dyadic?
	beq.b	iea_op_extract	* monadic
	btst	#$4,1+EXC_LV+EXC_CMDREG(a6)	* is operation fsincos,ftst,fcmp?
	bne.b	iea_op_spec	* yes

iea_op_loaddst:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * fetch dst regno
	bsr.l	load_fpn2	* load dst operand

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	move.b	d0,EXC_LV+DTAG(a6)	* could be ANYTHING!!!
	ICMP.b	d0,#UNNORM	* is operand an UNNORM?
	bne.b	iea_op_extract	* no
	bsr.l	unnorm_fix	* yes; convert to NORM/DENORM/ZERO
	move.b	d0,EXC_LV+DTAG(a6)	* set new optype tag
	bra.b	iea_op_extract

* the operation is fsincos, ftst, or fcmp. only fcmp is dyadic
iea_op_spec:
	btst	#$3,1+EXC_LV+EXC_CMDREG(a6)	* is operation fsincos?
	beq.b	iea_op_extract	* yes
* now, we're left with ftst and fcmp. so, first let's tag them so that they don't
* store a result. then, only fcmp will branch back and pick up a dst operand.
	st	EXC_LV+STORE_FLG(a6)	* don't store a final result
	btst	#$1,1+EXC_LV+EXC_CMDREG(a6)	* is operation fcmp?
	beq.b	iea_op_loaddst	* yes	
	
iea_op_extract:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass: rnd mode,prec

	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.w	#$007f,d1	* extract extension

	fmove.l	#$0,fpcr
	fmove.l	#$0,fpsr

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

	move.l	(tbl_unsupp.l,pc,d1.w*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

*
* Exceptions in order of precedence:
*	BSUN	: none
*	SNAN	: all operations
*	OPERR	: all reg-reg or mem-reg operations that can normally operr
*	OVFL	: same as OPERR
*	UNFL	: same as OPERR
*	DZ	: same as OPERR
*	INEX2	: same as OPERR
*	INEX1	: all packed immediate operations
*

* we determine the highest priority exception(if any) set by the
* emulation routine that has also been enabled by the user.
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions enabled
	bne.b	iea_op_ena	* some are enabled

* now, we save the result, unless, of course, the operation was ftst or fcmp.
* these don't save results.
iea_op_save:
	tst.b	EXC_LV+STORE_FLG(a6)	* does this op store a result?
	bne.b	iea_op_exit1	* exit with no frestore

iea_op_store:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * fetch dst regno
	bsr.l	store_fpreg	* store the result

iea_op_exit1:
	move.l	EXC_LV+EXC_PC(a6),EXC_LV+USER_FPIAR(a6) * set FPIAR to "Current PC"
	move.l	EXC_LV+EXC_EXTWPTR(a6),EXC_LV+EXC_PC(a6) * set "Next PC" in exc frame

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6	* unravel the frame

	btst	#$7,(sp)	* is trace on?
	bne.w	iea_op_trace	* yes

	bra.l	_fpsp_done	* exit to os

iea_op_ena:
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enable and set
	bfffo	d0{24:8},d0	* find highest priority exception
	bne.b	iea_op_exc	* at least one was set

* no exception occurred. now, did a disabled, exact overflow occur with inexact
* enabled? if so, then we have to stuff an overflow frame into the FPU.
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did overflow occur?
	beq.b	iea_op_save

iea_op_ovfl:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6) * is inexact enabled?
	beq.b	iea_op_store	* no
	bra.b	iea_op_EXC_LV+EXC_ovfl	* yes
	
* an enabled exception occurred. we have to insert the exception type back into
* the machine.
iea_op_exc:
	subi.l	#24,d0	* fix offset to be 0-8
	ICMP.b	d0,#$6	* is exception INEX?
	bne.b	iea_op_EXC_LV+EXC_force	* no

* the enabled exception was inexact. so, if it occurs with an overflow
* or underflow that was disabled, then we have to force an overflow or
* underflow frame.
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did overflow occur?
	bne.b	iea_op_EXC_LV+EXC_ovfl	* yes
	btst	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did underflow occur?
	bne.b	iea_op_EXC_LV+EXC_unfl	* yes

iea_op_EXC_LV+EXC_force:
	move.w	((tbl_iea_except).b,pc,d0.w*2),2+EXC_LV+FP_SRC(a6)
	bra.b	iea_op_exit2	* exit with frestore

tbl_iea_except:
	dc.w	$e002, $e006, $e004, $e005
	dc.w	$e003, $e002, $e001, $e001

iea_op_EXC_LV+EXC_ovfl:
	move.w	#$e005,2+EXC_LV+FP_SRC(a6)
	bra.b	iea_op_exit2

iea_op_EXC_LV+EXC_unfl:
	move.w	#$e003,2+EXC_LV+FP_SRC(a6)

iea_op_exit2:
	move.l	EXC_LV+EXC_PC(a6),EXC_LV+USER_FPIAR(a6) * set FPIAR to "Current PC"
	move.l	EXC_LV+EXC_EXTWPTR(a6),EXC_LV+EXC_PC(a6) * set "Next PC" in exc frame

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore 	EXC_LV+FP_SRC(a6)	* restore exceptional state

	unlk	a6	* unravel the frame

	btst	#$7,(sp)	* is trace on?
	bne.b	iea_op_trace	* yes

	bra.l	_fpsp_done	* exit to os
	
*
* The opclass two instruction that took an "Unimplemented Effective Address"
* exception was being traced. Make the "current" PC the FPIAR and put it in
* the trace stack frame then jump to _real_trace().
*
*	 UNIMP EA FRAME	   TRACE FRAME
*	*****************	*****************
*	* $0 *  $0f0	*	*    Current
*	*****************	*      PC
*	*    Current	*	*****************
*	*      PC	*	* $2 *  $024
*	*****************	*****************
*	*      SR	*	*     Next
*	*****************	*      PC
*		*****************
*		*      SR
*		*****************
iea_op_trace:
	move.l	(sp),-(sp)	* shift stack frame "down"
	move.w	$8(sp),$4(sp)
	move.w	#$2024,$6(sp)	* stk fmt = $2; voff = $024
	fmove.l	fpiar,$8(sp)	* "Current PC" is in FPIAR

	bra.l	_real_trace

**-------------------------------------------------------------------------------------------------
iea_fmovm:
	btst	#14,d0	* ctrl or data reg
	beq.w	iea_fmovm_ctrl

iea_fmovm_data:

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor mode
	bne.b	iea_fmovm_data_s

iea_fmovm_data_u:
	move.l	usp,a0
	move.l	a0,EXC_LV+EXC_A7(a6)	* store current a7	
	bsr.l	fmovm_dynamic	* do dynamic fmovm
	move.l	EXC_LV+EXC_A7(a6),a0	* load possibly new a7
	move.l	a0,usp	* update usp
	bra.w	iea_fmovm_exit

iea_fmovm_data_s:
	clr.b	EXC_LV+SPCOND_FLG(a6)
	lea	$2+EXC_LV+EXC_VOFF(a6),a0
	move.l	a0,EXC_LV+EXC_A7(a6)
	bsr.l	fmovm_dynamic	* do dynamic fmovm

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	beq.w	iea_fmovm_data_predec
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mia7_flg
	bne.w	iea_fmovm_exit

* right now, d0 = the size.
* the data has been fetched from the supervisor stack, but we have not
* incremented the stack pointer by the appropriate number of bytes.
* do it here.
iea_fmovm_data_postinc:
	btst	#$7,EXC_LV+EXC_SR(a6)
	bne.b	iea_fmovm_data_pi_trace

	move.w	EXC_LV+EXC_SR(a6),(EXC_LV+EXC_SR,a6,d0)
	move.l	EXC_LV+EXC_EXTWPTR(a6),(EXC_LV+EXC_PC,a6,d0)
	move.w	#$00f0,(EXC_LV+EXC_VOFF,a6,d0)

	lea	(EXC_LV+EXC_SR,a6,d0),a0
	move.l	a0,EXC_LV+EXC_SR(a6)
	
	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	unlk	a6
	move.l	(sp)+,sp
	bra.l	_fpsp_done

iea_fmovm_data_pi_trace:
	move.w	EXC_LV+EXC_SR(a6),(EXC_LV+EXC_SR-$4,a6,d0)
	move.l	EXC_LV+EXC_EXTWPTR(a6),(EXC_LV+EXC_PC-$4,a6,d0)
	move.w	#$2024,(EXC_LV+EXC_VOFF-$4,a6,d0)
	move.l	EXC_LV+EXC_PC(a6),(EXC_LV+EXC_VOFF+$2-$4,a6,d0)

	lea	(EXC_LV+EXC_SR-$4,a6,d0),a0
	move.l	a0,EXC_LV+EXC_SR(a6)
	
	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	unlk	a6
	move.l	(sp)+,sp
	bra.l	_real_trace
	
* right now, d1 = size and d0 = the strg.
iea_fmovm_data_predec:
	move.b	d1,EXC_LV+EXC_VOFF(a6)	* store strg
	move.b	d0,$1+EXC_LV+EXC_VOFF(a6)	* store size

	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	move.l	(a6),-(sp)	* make a copy of a6
	move.l	d0,-(sp)	* save d0
	move.l	d1,-(sp)	* save d1
	move.l	EXC_LV+EXC_EXTWPTR(a6),-(sp)	* make a copy of Next PC

	clr.l	d0
	move.b	$1+EXC_LV+EXC_VOFF(a6),d0	* fetch size
	neg.l	d0	* get negative of size

	btst	#$7,EXC_LV+EXC_SR(a6)	* is trace enabled?
	beq.b	iea_fmovm_data_p2

	move.w	EXC_LV+EXC_SR(a6),(EXC_LV+EXC_SR-$4,a6,d0)
	move.l	EXC_LV+EXC_PC(a6),(EXC_LV+EXC_VOFF-$2,a6,d0)
	move.l	(sp)+,(EXC_LV+EXC_PC-$4,a6,d0)
	move.w	#$2024,(EXC_LV+EXC_VOFF-$4,a6,d0)

	pea	(a6,d0)	* create final sp
	bra.b	iea_fmovm_data_p3

iea_fmovm_data_p2:
	move.w	EXC_LV+EXC_SR(a6),(EXC_LV+EXC_SR,a6,d0)
	move.l	(sp)+,(EXC_LV+EXC_PC,a6,d0)
	move.w	#$00f0,(EXC_LV+EXC_VOFF,a6,d0)

	pea	($4,a6,d0)	* create final sp

iea_fmovm_data_p3:
	clr.l	d1
	move.b	EXC_LV+EXC_VOFF(a6),d1	* fetch strg

	tst.b	d1
	bpl.b	fm_1
	fmovem.x	fp0,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_1:
	lsl.b	#$1,d1
	bpl.b	fm_2
	fmovem.x	fp1,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_2:
	lsl.b	#$1,d1
	bpl.b	fm_3
	fmovem.x	fp2,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_3:
	lsl.b	#$1,d1
	bpl.b	fm_4
	fmovem.x	fp3,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_4:
	lsl.b	#$1,d1
	bpl.b	fm_5
	fmovem.x	fp4,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_5:
	lsl.b	#$1,d1
	bpl.b	fm_6
	fmovem.x	fp5,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_6:
	lsl.b	#$1,d1
	bpl.b	fm_7
	fmovem.x	fp6,($4+$8,a6,d0)
	addi.l	#$c,d0
fm_7:
	lsl.b	#$1,d1
	bpl.b	fm_end
	fmovem.x	fp7,($4+$8,a6,d0)
fm_end:
	move.l	$4(sp),d1
	move.l	$8(sp),d0
	move.l	$c(sp),a6
	move.l	(sp)+,sp

	btst	#$7,(sp)	* is trace enabled?
	beq.l	_fpsp_done
	bra.l	_real_trace

**-------------------------------------------------------------------------------------------------
iea_fmovm_ctrl:

	bsr.l	fmovm_ctrl	* load ctrl regs

iea_fmovm_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	btst	#$7,EXC_LV+EXC_SR(a6)	* is trace on?
	bne.b	iea_fmovm_trace	* yes

	move.l	EXC_LV+EXC_EXTWPTR(a6),EXC_LV+EXC_PC(a6) * set Next PC

	unlk	a6	* unravel the frame

	bra.l	_fpsp_done	* exit to os

*
* The control reg instruction that took an "Unimplemented Effective Address"
* exception was being traced. The "Current PC" for the trace frame is the 
* PC stacked for Unimp EA. The "Next PC" is in EXC_LV+EXC_EXTWPTR.
* After fixing the stack frame, jump to _real_trace().
*		
*	 UNIMP EA FRAME	   TRACE FRAME
*	*****************	*****************
*	* $0 *  $0f0	*	*    Current
*	*****************	*      PC
*	*    Current	*	*****************
*	*      PC	*	* $2 *  $024
*	*****************	*****************
*	*      SR	*	*     Next
*	*****************	*      PC
*		*****************
*		*      SR
*		*****************
* this ain't a pretty solution, but it works:
* -restore a6 (not with unlk)
* -shift stack frame down over where old a6 used to be
* -add LOCAL_SIZE to stack pointer
iea_fmovm_trace:
	move.l	(a6),a6	* restore frame pointer
	move.w	EXC_LV+EXC_SR+LOCAL_SIZE(sp),$0+LOCAL_SIZE(sp)
	move.l	EXC_LV+EXC_PC+LOCAL_SIZE(sp),$8+LOCAL_SIZE(sp)
	move.l	EXC_LV+EXC_EXTWPTR+LOCAL_SIZE(sp),$2+LOCAL_SIZE(sp)
	move.w	#$2024,$6+LOCAL_SIZE(sp) * stk fmt = $2; voff = $024
	add.l	#LOCAL_SIZE,sp	* clear stack frame

	bra.l	_real_trace

**-------------------------------------------------------------------------------------------------
* The FPU is disabled and so we should really have taken the "Line
* F Emulator" exception. So, here we create an 8-word stack frame
* from our 4-word stack frame. This means we must calculate the length
* the the faulting instruction to get the "next PC". This is trivial for
* immediate operands but requires some extra work for fmovm dynamic
* which can use most addressing modes.
iea_disabled:
	move.l	(sp)+,d0	* restore d0

	link	a6,#LOCAL_SIZE	* init stack frame

	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1

* PC of instruction that took the exception is the PC in the frame
	move.l	EXC_LV+EXC_PC(a6),EXC_LV+EXC_EXTWPTR(a6)
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)	* store OPWORD and EXTWORD

	tst.w	d0	* is instr fmovm?
	bmi.b	iea_dis_fmovm	* yes
* instruction is using an extended precision immediate operand. therefore,
* the total instruction length is 16 bytes.
iea_dis_immed:
	move.l	#$10,d0	* 16 bytes of instruction
	bra.b	iea_dis_cont
iea_dis_fmovm:
	btst	#$e,d0	* is instr fmovm ctrl
	bne.b	iea_dis_fmovm_data	* no
* the instruction is a fmovem.l with 2 or 3 registers.
	bfextu	d0{19:3},d1
	move.l	#$c,d0
	ICMP.b	d1,#$7	* move all regs?
	bne.b	iea_dis_cont
	addq.l	#$4,d0
	bra.b	iea_dis_cont
* the instruction is an fmovem.x dynamic which can use many addressing
* modes and thus can have several different total instruction lengths.
* call fmovm_calc_ea which will go through the ea calc process and,
* as a by-product, will tell us how dc.l the instruction is.
iea_dis_fmovm_data:
	clr.l	d0
	bsr.l	fmovm_calc_ea
	move.l	EXC_LV+EXC_EXTWPTR(a6),d0
	sub.l	EXC_LV+EXC_PC(a6),d0
iea_dis_cont:
	move.w	d0,EXC_LV+EXC_VOFF(a6)	* store stack shift value

	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

* here, we actually create the 8-word frame from the 4-word frame,
* with the "next PC" as additional info.
* the <ea> field is let as undefined.
	subq.l	#$8,sp	* make room for new stack
	move.l	d0,-(sp)	* save d0
	move.w	$c(sp),$4(sp)	* move SR
	move.l	$e(sp),$6(sp)	* move Current PC
	clr.l	d0
	move.w	$12(sp),d0
	move.l	$6(sp),$10(sp)	* move Current PC
	add.l	d0,$6(sp)	* make Next PC
	move.w	#$402c,$a(sp)	* insert offset,frame format
	move.l	(sp)+,d0	* restore d0

	bra.l	_real_fpu_disabled

**********

iea_iacc:
	movec	pcr,d0
	btst	#$1,d0
	bne.b	iea_iacc_cont
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1 on stack
iea_iacc_cont:
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	subq.w	#$8,sp	* make stack frame bigger
	move.l	$8(sp),(sp)	* store SR,hi(PC)
	move.w	$c(sp),$4(sp)	* store lo(PC)
	move.w	#$4008,$6(sp)	* store voff
	move.l	$2(sp),$8(sp)	* store ea
	move.l	#$09428001,$c(sp)	* store fslw

iea_acc_done:
	btst	#$5,(sp)	* user or supervisor mode?
	beq.b	iea_acc_done2	* user
	bset	#$2,$d(sp)	* set supervisor TM bit

iea_acc_done2:
	bra.l	_real_access

iea_dacc:
	lea	LOCAL_SIZE(a6),sp

	movec	pcr,d1
	btst	#$1,d1
	bne.b	iea_dacc_cont
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1 on stack
	fmovem.l	LOCAL_SIZE-EXC_LV+USER_FPCR(sp),fpcr/fpsr/fpiar * restore ctrl regs
iea_dacc_cont:
	move.l	(a6),a6

	move.l	$4+LOCAL_SIZE(sp),-$8+$4+LOCAL_SIZE(sp)
	move.w	$8+LOCAL_SIZE(sp),-$8+$8+LOCAL_SIZE(sp)
	move.w	#$4008,-$8+$a+LOCAL_SIZE(sp)
	move.l	a0,-$8+$c+LOCAL_SIZE(sp)
	move.w	d0,-$8+$10+LOCAL_SIZE(sp)
	move.w	#$0001,-$8+$12+LOCAL_SIZE(sp)

	movem.l	LOCAL_SIZE-EXC_LV+EXC_DREGS(sp),d0-d1/a0-a1 * restore d0-d1/a0-a1
	add.w	#LOCAL_SIZE-$4,sp

	bra.b	iea_acc_done

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_operr(): 060FPSP entry point for FP Operr exception.
*		
*	This handler should be the first code executed upon taking the
* 	FP Operand Error exception in an operating system.
*		
* xdef **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	_real_operr() - "callout" to operating system operr handler
*	_dmem_write_{byte,word,dc.l}() - store data to mem (opclass 3)
*	store_dreg_{b,w,l}() - store data to data regfile (opclass 3)
*	facc_out_{b,w,l}() - store to memory took access error (opcl 3)
*		
* INPUT ***************************************************************
*	- The system stack contains the FP Operr exception frame
*	- The fsave frame contains the source operand
* 		
* OUTPUT **************************************************************
*	No access error:	
*	- The system stack is unchanged	
*	- The fsave frame contains the adjusted src op for opclass 0,2
*		
* ALGORITHM ***********************************************************
*	In a system where the FP Operr exception is enabled, the goal
* is to get to the handler specified at _real_operr(). But, on the 060,
* for opclass zero and two instruction taking this exception, the 
* input operand in the fsave frame may be incorrect for some cases
* and needs to be corrected. This handler calls fix_skewed_ops() to
* do just this and then exits through _real_operr().
*	For opclass 3 instructions, the 060 doesn't store the default
* operr result out to memory or data register file as it should.
* This code must emulate the move out before finally exiting through
* _real_inex(). The move out, if to memory, is performed using 
* _mem_write() "callout" routines that may return a failing result.
* In this special case, the handler must exit through facc_out() 
* which creates an access error stack frame from the current operr
* stack frame.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_operr
_fpsp_operr:

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------

	btst	#13,d0	* is instr an fmove out?
	bne.b	foperr_out	* fmove out


* here, we simply see if the operand in the fsave frame needs to be "unskewed".
* this would be the case for opclass two operations with a source infinity or
* denorm operand in the sgl or dbl format. NANs also become skewed, but can't
* cause an operr so we don't need to check for them here.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

foperr_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6
	bra.l	_real_operr

**********

*
* the hardware does not save the default result to memory on enabled
* operand error exceptions. we do this here before passing control to
* the user operand error handler.
*
* byte, word, and dc.l destination format operations can pass
* through here. we simply need to test the sign of the src
* operand and save the appropriate minimum or maximum integer value
* to the effective address as pointed to by the stacked effective address.
*
* although packed opclass three operations can take operand error
* exceptions, they won't pass through here since they are caught
* first by the unsupported data format exception handler. that handler
* sends them directly to _real_operr() if necessary.
*
foperr_out:

	move.w	EXC_LV+FP_SRC_EX(a6),d1	* fetch exponent
	andi.w	#$7fff,d1
	ICMP.w	d1,#$7fff
	bne.b	foperr_out_not_qnan
* the operand is either an infinity or a QNAN.
	tst.l	EXC_LV+FP_SRC_LO(a6)
	bne.b	foperr_out_qnan
	move.l	EXC_LV+FP_SRC_HI(a6),d1
	andi.l	#$7fffffff,d1
	beq.b	foperr_out_not_qnan
foperr_out_qnan:
	move.l	EXC_LV+FP_SRC_HI(a6),EXC_LV+L_SCR1(a6)
	bra.b	foperr_out_jmp

foperr_out_not_qnan:
	move.l	#$7fffffff,d1
	tst.b	EXC_LV+FP_SRC_EX(a6)
	bpl.b	foperr_out_not_qnan2
	addq.l	#$1,d1
foperr_out_not_qnan2:
	move.l	d1,EXC_LV+L_SCR1(a6)

foperr_out_jmp:
	bfextu	d0{19:3},d0	* extract dst format field
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract <ea> mode,reg
	move.w	((tbl_operr).b,pc,d0.w*2),a0
	jmp	((tbl_operr).b,pc,a0)

tbl_operr:
	dc.w	foperr_out_l - tbl_operr * dc.l word integer
	dc.w	tbl_operr    - tbl_operr * sgl prec shouldn't happen
	dc.w	tbl_operr    - tbl_operr * ext prec shouldn't happen
	dc.w	foperr_exit  - tbl_operr * packed won't enter here
	dc.w	foperr_out_w - tbl_operr * word integer
	dc.w	tbl_operr    - tbl_operr * dbl prec shouldn't happen
	dc.w	foperr_out_b - tbl_operr * byte integer
	dc.w	tbl_operr    - tbl_operr * packed won't enter here
	
foperr_out_b:
	move.b	EXC_LV+L_SCR1(a6),d0	* load positive default result
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	foperr_out_b_save_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_byte	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_b	* yes

	bra.w	foperr_exit
foperr_out_b_save_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_b	* store result to regfile
	bra.w	foperr_exit

foperr_out_w:
	move.w	EXC_LV+L_SCR1(a6),d0	* load positive default result
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	foperr_out_w_save_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_word	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_w	* yes

	bra.w	foperr_exit
foperr_out_w_save_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_w	* store result to regfile
	bra.w	foperr_exit

foperr_out_l:
	move.l	EXC_LV+L_SCR1(a6),d0	* load positive default result
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	foperr_out_l_save_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_long	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	bra.w	foperr_exit
foperr_out_l_save_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_l	* store result to regfile
	bra.w	foperr_exit

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_snan(): 060FPSP entry point for FP SNAN exception.
*		
*	This handler should be the first code executed upon taking the
* 	FP Signalling NAN exception in an operating system.
*		
* xdef **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	_real_snan() - "callout" to operating system SNAN handler
*	_dmem_write_{byte,word,dc.l}() - store data to mem (opclass 3)
*	store_dreg_{b,w,l}() - store data to data regfile (opclass 3)
*	facc_out_{b,w,l,d,x}() - store to mem took acc error (opcl 3)
*	_calc_ea_fout() - fix An if <ea> is -() or ()+; also get <ea>
*		
* INPUT ***************************************************************
*	- The system stack contains the FP SNAN exception frame
*	- The fsave frame contains the source operand
* 		
* OUTPUT **************************************************************
*	No access error:	
*	- The system stack is unchanged	
*	- The fsave frame contains the adjusted src op for opclass 0,2
*		
* ALGORITHM ***********************************************************
*	In a system where the FP SNAN exception is enabled, the goal
* is to get to the handler specified at _real_snan(). But, on the 060,
* for opclass zero and two instructions taking this exception, the 
* input operand in the fsave frame may be incorrect for some cases
* and needs to be corrected. This handler calls fix_skewed_ops() to
* do just this and then exits through _real_snan().
*	For opclass 3 instructions, the 060 doesn't store the default
* SNAN result out to memory or data register file as it should.
* This code must emulate the move out before finally exiting through
* _real_snan(). The move out, if to memory, is performed using 
* _mem_write() "callout" routines that may return a failing result.
* In this special case, the handler must exit through facc_out() 
* which creates an access error stack frame from the current SNAN
* stack frame.	
*	For the case of an extended precision opclass 3 instruction,
* if the effective addressing mode was -() or ()+, then the address
* register must get updated by calling _calc_ea_fout(). If the <ea>
* was -(a7) from supervisor mode, then the exception frame currently
* on the system stack must be carefully moved "down" to make room
* for the operand being moved.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_snan
_fpsp_snan:

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------*****

	btst	#13,d0	* is instr an fmove out?
	bne.w	fsnan_out	* fmove out


* here, we simply see if the operand in the fsave frame needs to be "unskewed".
* this would be the case for opclass two operations with a source infinity or
* denorm operand in the sgl or dbl format. NANs also become skewed and must be
* fixed here.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

fsnan_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6
	bra.l	_real_snan
	
**********

*
* the hardware does not save the default result to memory on enabled
* snan exceptions. we do this here before passing control to
* the user snan handler.
*
* byte, word, dc.l, and packed destination format operations can pass
* through here. since packed format operations already were handled by
* fpsp_unsupp(), then we need to do nothing else for them here.
* for byte, word, and dc.l, we simply need to test the sign of the src
* operand and save the appropriate minimum or maximum integer value
* to the effective address as pointed to by the stacked effective address.
*
fsnan_out:

	bfextu	d0{19:3},d0	* extract dst format field
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract <ea> mode,reg
	move.w	((tbl_snan).b,pc,d0.w*2),a0
	jmp	((tbl_snan).b,pc,a0)

tbl_snan:
	dc.w	fsnan_out_l - tbl_snan * dc.l word integer
	dc.w	fsnan_out_s - tbl_snan * sgl prec shouldn't happen
	dc.w	fsnan_out_x - tbl_snan * ext prec shouldn't happen
	dc.w	tbl_snan    - tbl_snan * packed needs no help
	dc.w	fsnan_out_w - tbl_snan * word integer
	dc.w	fsnan_out_d - tbl_snan * dbl prec shouldn't happen
	dc.w	fsnan_out_b - tbl_snan * byte integer
	dc.w	tbl_snan    - tbl_snan * packed needs no help

fsnan_out_b:
	move.b	EXC_LV+FP_SRC_HI(a6),d0	* load upper byte of SNAN
	bset	#6,d0	* set SNAN bit
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	fsnan_out_b_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_byte	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_b	* yes

	bra.w	fsnan_exit
fsnan_out_b_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_b	* store result to regfile
	bra.w	fsnan_exit

fsnan_out_w:
	move.w	EXC_LV+FP_SRC_HI(a6),d0	* load upper word of SNAN
	bset	#14,d0	* set SNAN bit
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	fsnan_out_w_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_word	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_w	* yes

	bra.w	fsnan_exit
fsnan_out_w_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_w	* store result to regfile
	bra.w	fsnan_exit

fsnan_out_l:
	move.l	EXC_LV+FP_SRC_HI(a6),d0	* load upper longword of SNAN
	bset	#30,d0	* set SNAN bit
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	fsnan_out_l_dn	* yes
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_long	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	bra.w	fsnan_exit
fsnan_out_l_dn:
	andi.w	#$0007,d1
	bsr.l	store_dreg_l	* store result to regfile
	bra.w	fsnan_exit

fsnan_out_s:
	ICMP.b	d1,#$7	* is <ea> mode a data reg?
	ble.b	fsnan_out_d_dn	* yes
	move.l	EXC_LV+FP_SRC_EX(a6),d0	* fetch SNAN sign
	andi.l	#$80000000,d0	* keep sign
	ori.l	#$7fc00000,d0	* insert new exponent,SNAN bit
	move.l	EXC_LV+FP_SRC_HI(a6),d1	* load mantissa
	lsr.l	#$8,d1	* shift mantissa for sgl
	or.l	d1,d0	* create sgl SNAN
	move.l	EXC_LV+EXC_EA(a6),a0	* pass: <ea> of default result
	bsr.l	_dmem_write_long	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	bra.w	fsnan_exit
fsnan_out_d_dn:
	move.l	EXC_LV+FP_SRC_EX(a6),d0	* fetch SNAN sign
	andi.l	#$80000000,d0	* keep sign
	ori.l	#$7fc00000,d0	* insert new exponent,SNAN bit
	move.l	d1,-(sp)
	move.l	EXC_LV+FP_SRC_HI(a6),d1	* load mantissa
	lsr.l	#$8,d1	* shift mantissa for sgl
	or.l	d1,d0	* create sgl SNAN
	move.l	(sp)+,d1
	andi.w	#$0007,d1
	bsr.l	store_dreg_l	* store result to regfile
	bra.w	fsnan_exit

fsnan_out_d:
	move.l	EXC_LV+FP_SRC_EX(a6),d0	* fetch SNAN sign
	andi.l	#$80000000,d0	* keep sign
	ori.l	#$7ff80000,d0	* insert new exponent,SNAN bit
	move.l	EXC_LV+FP_SRC_HI(a6),d1	* load hi mantissa
	move.l	d0,EXC_LV+FP_SCR0_EX(a6)	* store to temp space
	move.l	#11,d0	* load shift amt
	lsr.l	d0,d1
	or.l	d1,EXC_LV+FP_SCR0_EX(a6)	* create dbl hi
	move.l	EXC_LV+FP_SRC_HI(a6),d1	* load hi mantissa
	andi.l	#$000007ff,d1
	ror.l	d0,d1
	move.l	d1,EXC_LV+FP_SCR0_HI(a6)	* store to temp space
	move.l	EXC_LV+FP_SRC_LO(a6),d1	* load lo mantissa
	lsr.l	d0,d1
	or.l	d1,EXC_LV+FP_SCR0_HI(a6)	* create dbl lo
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	move.l	EXC_LV+EXC_EA(a6),a1	* pass: dst addr
	moveq.l	#$8,d0	* pass: size of 8 bytes
	bsr.l	_dmem_write	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_d	* yes

	bra.w	fsnan_exit

* for extended precision, if the addressing mode is pre-decrement or
* post-increment, then the address register did not get updated.
* in addition, for pre-decrement, the stacked <ea> is incorrect.
fsnan_out_x:
	clr.b	EXC_LV+SPCOND_FLG(a6)	* clear special case flag

	move.w	EXC_LV+FP_SRC_EX(a6),EXC_LV+FP_SCR0_EX(a6)
	clr.w	2+EXC_LV+FP_SCR0(a6)
	move.l	EXC_LV+FP_SRC_HI(a6),d0
	bset	#30,d0
	move.l	d0,EXC_LV+FP_SCR0_HI(a6)
	move.l	EXC_LV+FP_SRC_LO(a6),EXC_LV+FP_SCR0_LO(a6O(a6)

	btst	#$5,EXC_LV+EXC_SR(a6)	* supervisor mode exception?
	bne.b	fsnan_out_x_s	* yes

	move.l	usp,a0	* fetch user stack pointer
	move.l	a0,EXC_LV+EXC_A7(a6)	* save on stack for calc_ea()
	move.l	(a6),EXC_LV+EXC_A6(a6)
	
	bsr.l	_calc_ea_fout	* find the correct ea,update An
	move.l	a0,a1
	move.l	a0,EXC_LV+EXC_EA(a6)	* stack correct <ea>

	move.l	EXC_LV+EXC_A7(a6),a0
	move.l	a0,usp	* restore user stack pointer
	move.l	EXC_LV+EXC_A6(a6),(a6)

fsnan_out_x_save:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	moveq.l	#$c,d0	* pass: size of extended
	bsr.l	_dmem_write	* write the default result

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_x	* yes

	bra.w	fsnan_exit

fsnan_out_x_s:
	move.l	(a6),EXC_LV+EXC_A6(a6)

	bsr.l	_calc_ea_fout	* find the correct ea,update An
	move.l	a0,a1
	move.l	a0,EXC_LV+EXC_EA(a6)	* stack correct <ea>

	move.l	EXC_LV+EXC_A6(a6),(a6)

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg * is <ea> mode -(a7)?
	bne.b	fsnan_out_x_save	* no

* the operation was "fmove.x SNAN,-(a7)" from supervisor mode.
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)

	move.l	EXC_LV+EXC_A6(a6),a6	* restore frame pointer

	move.l	LOCAL_SIZE-EXC_LV+EXC_SR(sp),LOCAL_SIZE-EXC_LV+EXC_SR-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_PC+$2(sp),LOCAL_SIZE-EXC_LV+EXC_PC+$2-$c(sp)
	move.l	LOCAL_SIZE-EXC_LV+EXC_EA(sp),LOCAL_SIZE-EXC_LV+EXC_EA-$c(sp)

	move.l	LOCAL_SIZE-EXC_LV+FP_SCR0_EX(sp),LOCAL_SIZE-EXC_LV+EXC_SR(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SCR0_HI(sp),LOCAL_SIZE-EXC_LV+EXC_PC+$2(sp)
	move.l	LOCAL_SIZE-EXC_LV+FP_SCR0_LO(sp),LOCAL_SIZE-EXC_LV+EXC_EA(sp)

	add.l	#LOCAL_SIZE-$8,sp
	
	bra.l	_real_snan

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_inex(): 060FPSP entry point for FP Inexact exception.
*		
*	This handler should be the first code executed upon taking the
* 	FP Inexact exception in an operating system.
*		
* xdef **
*	_imem_read_long() - read instruction longword
*	fix_skewed_ops() - adjust src operand in fsave frame
*	set_tag_x() - determine optype of src/dst operands
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	unnorm_fix() - change UNNORM operands to NORM or ZERO
*	load_fpn2() - load dst operand from FP regfile
*	smovcr() - emulate an "fmovcr" instruction
*	fout() - emulate an opclass 3 instruction
*	tbl_unsupp - add of table of emulation routines for opclass 0,2
*	_real_inex() - "callout" to operating system inexact handler
*		
* INPUT ***************************************************************
*	- The system stack contains the FP Inexact exception frame
*	- The fsave frame contains the source operand
* 		
* OUTPUT **************************************************************
*	- The system stack is unchanged	
*	- The fsave frame contains the adjusted src op for opclass 0,2
*		
* ALGORITHM ***********************************************************
*	In a system where the FP Inexact exception is enabled, the goal
* is to get to the handler specified at _real_inex(). But, on the 060,
* for opclass zero and two instruction taking this exception, the 
* hardware doesn't store the correct result to the destination FP
* register as did the '040 and '881/2. This handler must emulate the 
* instruction in order to get this value and then store it to the 
* correct register before calling _real_inex().
*	For opclass 3 instructions, the 060 doesn't store the default
* inexact result out to memory or data register file as it should.
* This code must emulate the move out by calling fout() before finally
* exiting through _real_inex().	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_inex
_fpsp_inex:

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------*****

	btst	#13,d0	* is instr an fmove out?
	bne.w	finex_out	* fmove out


* the hardware, for "fabs" and "fneg" w/ a dc.l source format, puts the 
* longword integer directly into the upper longword of the mantissa along
* w/ an exponent value of $401e. we convert this to extended precision here.
	bfextu	d0{19:3},d0	* fetch instr size
	bne.b	finex_cont	* instr size is not dc.l
	ICMP.w	EXC_LV+FP_SRC_EX(a6),#$401e	* is exponent $401e?
	bne.b	finex_cont	* no
	fmove.l	#$0,fpcr
	fmove.l	EXC_LV+FP_SRC_HI(a6),fp0	* load integer src
	fmove.x	fp0,EXC_LV+FP_SRC(a6)	* store integer as extended precision
	move.w	#$e001,$2+EXC_LV+FP_SRC(a6)

finex_cont:
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

* Here, we zero the ccode and exception byte field since we're going to
* emulate the whole instruction. Notice, though, that we don't kill the
* INEX1 bit. This is because a packed op has dc.l since been converted
* to extended before arriving here. Therefore, we need to retain the
* INEX1 bit from when the operand was first converted.
	andi.l	#$00ff01ff,EXC_LV+USER_FPSR(a6) * zero all but accured field

	fmove.l	#$0,fpcr	* zero current control regs
	fmove.l	#$0,fpsr

	bfextu	EXC_LV+EXC_EXTWORD(a6){0:6},d1 * extract upper 6 of cmdreg
	ICMP.b	d1,#$17	* is op an fmovecr?
	beq.w	finex_fmovcr	* yes

	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	set_tag_x	* tag the operand type
	move.b	d0,EXC_LV+STAG(a6)	* maybe NORM,DENORM

* bits four and five of the fp extension word separate the monadic and dyadic
* operations that can pass through fpsp_inex(). remember that fcmp and ftst
* will never take this exception, but fsincos will.
	btst	#$5,1+EXC_LV+EXC_CMDREG(a6)	* is operation monadic or dyadic?
	beq.b	finex_extract	* monadic

	btst	#$4,1+EXC_LV+EXC_CMDREG(a6)	* is operation an fsincos?
	bne.b	finex_extract	* yes

	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * dyadic; load dst reg
	bsr.l	load_fpn2	* load dst into EXC_LV+FP_DST

	lea	EXC_LV+FP_DST(a6),a0	* pass: ptr to dst op
	bsr.l	set_tag_x	* tag the operand type
	ICMP.b	d0,#UNNORM	* is operand an UNNORM?
	bne.b	finex_op2_done	* no
	bsr.l	unnorm_fix	* yes; convert to NORM,DENORM,or ZERO
finex_op2_done:
	move.b	d0,EXC_LV+DTAG(a6)	* save dst optype tag

finex_extract:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec/mode

	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.w	#$007f,d1	* extract extension

	lea	EXC_LV+FP_SRC(a6),a0
	lea	EXC_LV+FP_DST(a6),a1

	move.l	(tbl_unsupp.l,pc,d1.w*4),d1 * fetch routine addr
	jsr	(tbl_unsupp.l,pc,d1.l*1)

* the operation has been emulated. the result is in fp0.
finex_save:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0
	bsr.l	store_fpreg

finex_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6
	bra.l	_real_inex

finex_fmovcr:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec,mode
	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.l	#$0000007f,d1	* pass rom offset
	bsr.l	smovcr
	bra.b	finex_save

**********

*
* the hardware does not save the default result to memory on enabled
* inexact exceptions. we do this here before passing control to
* the user inexact handler.
*
* byte, word, and dc.l destination format operations can pass
* through here. so can double and single precision.
* although packed opclass three operations can take inexact
* exceptions, they won't pass through here since they are caught
* first by the unsupported data format exception handler. that handler
* sends them directly to _real_inex() if necessary.
*
finex_out:

	move.b	#NORM,EXC_LV+STAG(a6)	* src is a NORM

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* pass rnd prec,mode

	andi.l	#$ffff00ff,EXC_LV+USER_FPSR(a6) * zero exception field

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src operand

	bsr.l	fout	* store the default result

	bra.b	finex_exit

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_dz(): 060FPSP entry point for FP DZ exception.
*		
*	This handler should be the first code executed upon taking
*	the FP DZ exception in an operating system.
*		
* xdef **
*	_imem_read_long() - read instruction longword from memory
*	fix_skewed_ops() - adjust fsave operand
*	_real_dz() - "callout" exit point from FP DZ handler
*		
* INPUT ***************************************************************
*	- The system stack contains the FP DZ exception stack.
*	- The fsave frame contains the source operand.
* 		
* OUTPUT **************************************************************
*	- The system stack contains the FP DZ exception stack.
*	- The fsave frame contains the adjusted source operand.
*		
* ALGORITHM ***********************************************************
*	In a system where the DZ exception is enabled, the goal is to
* get to the handler specified at _real_dz(). But, on the 060, when the
* exception is taken, the input operand in the fsave state frame may
* be incorrect for some cases and need to be adjusted. So, this package
* adjusts the operand using fix_skewed_ops() and then branches to
* _real_dz(). 	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_dz
_fpsp_dz:

	link	a6,#LOCAL_SIZE	* init stack frame

	fsave	EXC_LV+FP_SRC(a6)	* grab the "busy" frame

 	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
 	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1 on stack

* the FPIAR holds the "current PC" of the faulting instruction
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)
	
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------*****


* here, we simply see if the operand in the fsave frame needs to be "unskewed".
* this would be the case for opclass two operations with a source zero
* in the sgl or dbl format.
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to src op
	bsr.l	fix_skewed_ops	* fix src op

fdz_exit:
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)

	unlk	a6
	bra.l	_real_dz

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_fline(): 060FPSP entry point for "Line F emulator" exc.
*		
*	This handler should be the first code executed upon taking the
*	"Line F Emulator" exception in an operating system.
*		
* xdef **
*	_fpsp_unimp() - handle "FP Unimplemented" exceptions
*	_real_fpu_disabled() - handle "FPU disabled" exceptions
*	_real_fline() - handle "FLINE" exceptions
*	_imem_read_long() - read instruction longword
*		
* INPUT ***************************************************************
*	- The system stack contains a "Line F Emulator" exception
*	  stack frame.	
* 		
* OUTPUT **************************************************************
*	- The system stack is unchanged	
*		
* ALGORITHM ***********************************************************
*	When a "Line F Emulator" exception occurs, there are 3 possible
* exception types, denoted by the exception stack frame format number:
*	(1) FPU unimplemented instruction (6 word stack frame)
*	(2) FPU disabled (8 word stack frame)
*	(3) Line F (4 word stack frame)	
*		
*	This module determines which and forks the flow off to the 
* appropriate "callout" (for "disabled" and "Line F") or to the
* correct emulation code (for "FPU unimplemented").
*	This code also must check for "fmovecr" instructions w/ a
* non-zero <ea> field. These may get flagged as "Line F" but should
* really be flagged as "FPU Unimplemented". (This is a "feature" on
* the '060.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fpsp_fline
_fpsp_fline:

* check to see if this exception is a "FP Unimplemented Instruction"
* exception. if so, branch directly to that handler's entry point.
	ICMP.w	$6(sp),#$202c
	beq.l	_fpsp_unimp

* check to see if the FPU is disabled. if so, jump to the OS entry
* point for that condition.
	ICMP.w	$6(sp),#$402c
	beq.l	_real_fpu_disabled

* the exception was an "F-Line Illegal" exception. we check to see
* if the F-Line instruction is an "fmovecr" w/ a non-zero <ea>. if
* so, convert the F-Line exception stack frame to an FP Unimplemented
* Instruction exception stack frame else branch to the OS entry
* point for the F-Line exception handler.
	link	a6,#LOCAL_SIZE	* init stack frame

	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1

	move.l	EXC_LV+EXC_PC(a6),EXC_LV+EXC_EXTWPTR(a6)
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch instruction words

	bfextu	d0{0:10},d1	* is it an fmovecr?
	ICMP.w	d1,#$03c8
	bne.b	fline_fline	* no

	bfextu	d0{16:6},d1	* is it an fmovecr?
	ICMP.b	d1,#$17
	bne.b	fline_fline	* no

* it's an fmovecr w/ a non-zero <ea> that has entered through
* the F-Line Illegal exception.
* so, we need to convert the F-Line exception stack frame into an
* FP Unimplemented Instruction stack frame and jump to that entry
* point.
*
* but, if the FPU is disabled, then we need to jump to the FPU diabled
* entry point.
	movec	pcr,d0
	btst	#$1,d0
	beq.b	fline_fmovcr

	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	sub.l	#$8,sp	* make room for "Next PC", <ea>
	move.w	$8(sp),(sp)
	move.l	$a(sp),$2(sp)	* move "Current PC"
	move.w	#$402c,$6(sp)
	move.l	$2(sp),$c(sp)
	addq.l	#$4,$2(sp)	* set "Next PC"

	bra.l	_real_fpu_disabled

fline_fmovcr:
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	fmove.l	$2(sp),fpiar	* set current PC
	addq.l	#$4,$2(sp)	* set Next PC

	move.l	(sp),-(sp)
	move.l	$8(sp),$4(sp)
	move.b	#$20,$6(sp)

	bra.l	_fpsp_unimp

fline_fline:
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	bra.l	_real_fline

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_fpsp_unimp(): 060FPSP entry point for FP "Unimplemented
*	       Instruction" exception.
*		
*	This handler should be the first code executed upon taking the
*	FP Unimplemented Instruction exception in an operating system.
*		
* xdef **
*	_imem_read_{word,dc.l}() - read instruction word/longword
*	load_fop() - load src/dst ops from memory and/or FP regfile
*	store_fpreg() - store opclass 0 or 2 result to FP regfile
*	tbl_trans - addr of table of emulation routines for trnscndls
*	_real_access() - "callout" for access error exception
*	_fpsp_done() - "callout" for exit; work all done
*	_real_trace() - "callout" for Trace enabled exception
*	smovcr() - emulate "fmovecr" instruction
*	funimp_skew() - adjust fsave src ops to "incorrect" value
*	_ftrapcc() - emulate an "ftrapcc" instruction
*	_fdbcc() - emulate an "fdbcc" instruction
*	_fscc() - emulate an "fscc" instruction
*	_real_trap() - "callout" for Trap exception
* 	_real_bsun() - "callout" for enabled Bsun exception
*		
* INPUT ***************************************************************
*	- The system stack contains the "Unimplemented Instr" stk frame
* 		
* OUTPUT **************************************************************
*	If access error:	
*	- The system stack is changed to an access error stack frame
*	If Trace exception enabled:	
*	- The system stack is changed to a Trace exception stack frame
*	Else: (normal case)	
*	- Correct result has been stored as appropriate
*		
* ALGORITHM ***********************************************************
*	There are two main cases of instructions that may enter here to
* be emulated: (1) the FPgen instructions, most of which were also
* unimplemented on the 040, and (2) "ftrapcc", "fscc", and "fdbcc".
*	For the first set, this handler calls the routine load_fop()
* to load the source and destination (for dyadic) operands to be used
* for instruction emulation. The correct emulation routine is then 
* chosen by decoding the instruction type and indexing into an 
* emulation subroutine index table. After emulation returns, this 
* handler checks to see if an exception should occur as a result of the *
* FP instruction emulation. If so, then an FP exception of the correct
* type is inserted into the FPU state frame using the "frestore"
* instruction before exiting through _fpsp_done(). In either the 
* exceptional or non-exceptional cases, we must check to see if the
* Trace exception is enabled. If so, then we must create a Trace
* exception frame from the current exception frame and exit through
* _real_trace().	
* 	For "fdbcc", "ftrapcc", and "fscc", the emulation subroutines
* _fdbcc(), _ftrapcc(), and _fscc() respectively are used. All three
* may flag that a BSUN exception should be taken. If so, then the 
* current exception stack frame is converted into a BSUN exception 
* stack frame and an exit is made through _real_bsun(). If the
* instruction was "ftrapcc" and a Trap exception should result, a Trap
* exception stack frame is created from the current frame and an exit
* is made through _real_trap(). If a Trace exception is pending, then
* a Trace exception frame is created from the current frame and a jump
* is made to _real_trace(). Finally, if none of these conditions exist,
* then the handler exits though the callout _fpsp_done().
*		
* 	In any of the above scenarios, if a _mem_read() or _mem_write()
* "callout" returns a failing value, then an access error stack frame
* is created from the current stack frame and an exit is made through
* _real_access().	
*		
**-------------------------------------------------------------------------------------------------

*
* FP UNIMPLEMENTED INSTRUCTION STACK FRAME:
*
*	*****************
*	*	* => <ea> of fp unimp instr.
*	-      EA	-
*	*
*	*****************
*	* $2 *  $02c	* => frame format and vector offset(vector *11)
*	*****************
*	*
*	-    Next PC	- => PC of instr to execute after exc handling
*	*
*	*****************
*	*      SR	* => SR at the time the exception was taken
*	*****************
*
* Note: the !NULL bit does not get set in the fsave frame when the
* machine encounters an fp unimp exception. Therefore, it must be set
* before leaving this handler.
*
	xdef	_fpsp_unimp
_fpsp_unimp:

	link	a6,#LOCAL_SIZE	* init stack frame

	movem.l	d0-d1/a0-a1,EXC_LV+EXC_DREGS(a6)	* save d0-d1/a0-a1
	fmovem.l	fpcr/fpsr/fpiar,EXC_LV+USER_FPCR(a6) * save ctrl regs
	fmovem.x	fp0-fp1,EXC_LV+EXC_FPREGS(a6)	* save fp0-fp1

	btst	#$5,EXC_LV+EXC_SR(a6)	* user mode exception?
	bne.b	funimp_s	* no; supervisor mode

* save the value of the user stack pointer onto the stack frame
funimp_u:
	move.l	usp,a0	* fetch user stack pointer
	move.l	a0,EXC_LV+EXC_A7(a6)	* store in stack frame
	bra.b	funimp_cont

* store the value of the supervisor stack pointer BEFORE the exc occurred.
* old_sp is address just above stacked effective address.
funimp_s:
	lea	4+EXC_LV+EXC_EA(a6),a0	* load old a7'
	move.l	a0,EXC_LV+EXC_A7(a6)	* store a7'
	move.l	a0,OLD_A7(a6)	* make a copy

funimp_cont:

* the FPIAR holds the "current PC" of the faulting instruction.
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EXTWPTR(a6)

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch the instruction words
	move.l	d0,EXC_LV+EXC_OPWORD(a6)

**-------------------------------------------------------------------------------------------------***

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	clr.b	EXC_LV+SPCOND_FLG(a6)	* clear "special case" flag

* Divide the fp instructions into 8 types based on the TYPE field in
* bits 6-8 of the opword(classes 6,7 are undefined).
* (for the '060, only two types  can take this exception)
*	bftst	d07:3}	* test TYPE
	btst	#22,d0	* type 0 or 1 ?
	bne.w	funimp_misc	* type 1

*****************************************
* TYPE == 0: General instructions
*****************************************
funimp_gen:

	clr.b	EXC_LV+STORE_FLG(a6)	* clear "store result" flag

* clear the ccode byte and exception status byte
	andi.l	#$00ff00ff,EXC_LV+USER_FPSR(a6)

	bfextu	d0{16:6},d1	* extract upper 6 of cmdreg
	ICMP.b	d1,#$17	* is op an fmovecr?
	beq.w	funimp_fmovcr	* yes

funimp_gen_op:
	bsr.l	_load_fop	* load 

	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0	* fetch rnd mode

	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.w	#$003f,d1	* extract extension bits
	lsl.w	#$3,d1	* shift right 3 bits
	or.b	EXC_LV+STAG(a6),d1	* insert src optag bits

	lea	EXC_LV+FP_DST(a6),a1	* pass dst ptr in a1
	lea	EXC_LV+FP_SRC(a6),a0	* pass src ptr in a0

	move.w	(tbl_trans.w,pc,d1.w*2),d1
	jsr	(tbl_trans.w,pc,d1.w*1) * emulate

funimp_fsave:
	move.b	EXC_LV+FPCR_ENABLE(a6),d0	* fetch exceptions enabled
	bne.w	funimp_ena	* some are enabled

funimp_store:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3},d0 * fetch Dn
	bsr.l	store_fpreg	* store result to fp regfile

funimp_gen_exit:
	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

funimp_gen_exit_cmp:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mia7_flg * was the ea mode (sp)+ ?
	beq.b	funimp_gen_exit_a7	* yes

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg * was the ea mode -(sp) ?
	beq.b	funimp_gen_exit_a7	* yes

funimp_gen_exit_cont:
	unlk	a6

funimp_gen_exit_cont2:
	btst	#$7,(sp)	* is trace on?
	beq.l	_fpsp_done	* no

* this catches a problem with the case where an exception will be re-inserted
* into the machine. the frestore has already been executed...so, the fmove.l
* alone of the control register would trigger an unwanted exception.
* until I feel like fixing this, we'll sidestep the exception.
	fsave	-(sp)
	fmove.l	fpiar,$14(sp)	* "Current PC" is in FPIAR
	frestore	(sp)+
	move.w	#$2024,$6(sp)	* stk fmt = $2; voff = $24
	bra.l	_real_trace
	
funimp_gen_exit_a7:
	btst	#$5,EXC_LV+EXC_SR(a6)	* supervisor or user mode?
	bne.b	funimp_gen_exit_a7_s	* supervisor

	move.l	a0,-(sp)
	move.l	EXC_LV+EXC_A7(a6),a0
	move.l	a0,usp
	move.l	(sp)+,a0
	bra.b	funimp_gen_exit_cont

* if the instruction was executed from supervisor mode and the addressing
* mode was (a7)+, then the stack frame for the rte must be shifted "up"
* "n" bytes where "n" is the size of the src operand type.
* f<op>.{b,w,l,s,d,x,p}
funimp_gen_exit_a7_s:
	move.l	d0,-(sp)	* save d0
	move.l	EXC_LV+EXC_A7(a6),d0	* load new a7'
	sub.l	OLD_A7(a6),d0	* subtract old a7'
	move.l	$2+EXC_LV+EXC_PC(a6),($2+EXC_LV+EXC_PC,a6,d0) * shift stack frame
	move.l	EXC_LV+EXC_SR(a6),(EXC_LV+EXC_SR,a6,d0) * shift stack frame
	move.w	d0,EXC_LV+EXC_SR(a6)	* store incr number
	move.l	(sp)+,d0	* restore d0

	unlk	a6

	add.w	(sp),sp	* stack frame shifted
	bra.b	funimp_gen_exit_cont2	

**********************
* fmovecr.x *ccc,fpn *
**********************
funimp_fmovcr:
	clr.l	d0
	move.b	EXC_LV+FPCR_MODE(a6),d0
	move.b	1+EXC_LV+EXC_CMDREG(a6),d1
	andi.l	#$0000007f,d1	* pass rom offset in d1
	bsr.l	smovcr
	bra.w	funimp_fsave

**-------------------------------------------------------------------------------------------------

*
* the user has enabled some exceptions. we figure not to see this too
* often so that's why it gets lower priority.
*
funimp_ena:

* was an exception set that was also enabled?
	and.b	EXC_LV+FPSR_EXCEPT(a6),d0	* keep only ones enabled and set
	bfffo	d0{24:8},d0	* find highest priority exception
	bne.b	funimp_exc	* at least one was set

* no exception that was enabled was set BUT if we got an exact overflow
* and overflow wasn't enabled but inexact was (yech!) then this is
* an inexact exception; otherwise, return to normal non-exception flow.
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did overflow occur?
	beq.w	funimp_store	* no; return to normal flow

* the overflow w/ exact result happened but was inexact set in the FPCR?
funimp_ovfl:
	btst	#inex2_bit,EXC_LV+FPCR_ENABLE(a6) * is inexact enabled?
	beq.w	funimp_store	* no; return to normal flow
	bra.b	funimp_EXC_LV+EXC_ovfl	* yes

* some exception happened that was actually enabled.
* we'll insert this new exception into the FPU and then return.
funimp_exc:
	subi.l	#24,d0	* fix offset to be 0-8
	ICMP.b	d0,#$6	* is exception INEX?
	bne.b	funimp_EXC_LV+EXC_force	* no

* the enabled exception was inexact. so, if it occurs with an overflow
* or underflow that was disabled, then we have to force an overflow or
* underflow frame. the eventual overflow or underflow handler will see that
* it's actually an inexact and act appropriately. this is the only easy
* way to have the EXOP available for the enabled inexact handler when
* a disabled overflow or underflow has also happened.
	btst	#ovfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did overflow occur?
	bne.b	funimp_EXC_LV+EXC_ovfl	* yes
	btst	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * did underflow occur?
	bne.b	funimp_EXC_LV+EXC_unfl	* yes

* force the fsave exception status bits to signal an exception of the 
* appropriate type. don't forget to "skew" the source operand in case we
* "unskewed" the one the hardware initially gave us.
funimp_EXC_LV+EXC_force:
	move.l	d0,-(sp)	* save d0
	bsr.l	funimp_skew	* check for special case
	move.l	(sp)+,d0	* restore d0
	move.w	((tbl_funimp_except).b,pc,d0.w*2),2+EXC_LV+FP_SRC(a6)
	bra.b	funimp_gen_exit2	* exit with frestore

tbl_funimp_except:
	dc.w	$e002, $e006, $e004, $e005
	dc.w	$e003, $e002, $e001, $e001

* insert an overflow frame
funimp_EXC_LV+EXC_ovfl:
	bsr.l	funimp_skew	* check for special case
	move.w	#$e005,2+EXC_LV+FP_SRC(a6)
	bra.b	funimp_gen_exit2

* insert an underflow frame
funimp_EXC_LV+EXC_unfl:
	bsr.l	funimp_skew	* check for special case
	move.w	#$e003,2+EXC_LV+FP_SRC(a6)

* this is the general exit point for an enabled exception that will be
* restored into the machine for the instruction just emulated.
funimp_gen_exit2:
	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* insert exceptional status

	bra.w	funimp_gen_exit_cmp

**-------------------------------------------------------------------------------------------------***

*
* TYPE == 1: FDB<cc>, FS<cc>, FTRAP<cc>
*
* These instructions were implemented on the '881/2 and '040 in hardware but
* are emulated in software on the '060.
*
funimp_misc:
	bfextu	d0{10:3},d1	* extract mode field
	ICMP.b	d1,#$1	* is it an fdb<cc>?
	beq.w	funimp_fdbcc	* yes
	ICMP.b	d1,#$7	* is it an fs<cc>?
	bne.w	funimp_fscc	* yes
	bfextu	d0{13:3},d1
	ICMP.b	d1,#$2	* is it an fs<cc>?
	blt.w	funimp_fscc	* yes

*************************
* ftrap<cc>
* ftrap<cc>.w *<data>
* ftrap<cc>.l *<data>
*************************
funimp_ftrapcc:

	bsr.l	_ftrapcc	* FTRAP<cc>()

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#fbsun_flg * is enabled bsun occurring?
	beq.w	funimp_bsun	* yes

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#ftrapcc_flg * should a trap occur?
	bne.w	funimp_done	* no

*	 FP UNIMP FRAME	   TRAP  FRAME
*	*****************	*****************
*	**    <EA>     **	**  Current PC **
*	*****************	*****************
*	* $2 *  $02c	*	* $2 *  $01c  *
*	*****************	*****************
*	**   Next PC   **	**   Next PC   **
*	*****************	*****************
*	*      SR	*	*      SR
*	*****************	*****************
*	    (6 words)	    (6 words)
*
* the ftrapcc instruction should take a trap. so, here we must create a
* trap stack frame from an unimplemented fp instruction stack frame and
* jump to the user supplied entry point for the trap exception
funimp_ftrapcc_tp:
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_EA(a6) * Address = Current PC
	move.w	#$201c,EXC_LV+EXC_VOFF(a6)	* Vector Offset = $01c

	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	unlk	a6
	bra.l	_real_trap

*************************
* fdb<cc> Dn,<label>
*************************
funimp_fdbcc:

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word	* read displacement

	tst.l	d1	* did ifetch fail?
	bne.w	funimp_iacc	* yes

	ext.l	d0	* sign extend displacement

	bsr.l	_fdbcc	* FDB<cc>()

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#fbsun_flg * is enabled bsun occurring?
	beq.w	funimp_bsun

	bra.w	funimp_done	* branch to finish

*****************
* fs<cc>.b <ea>
*****************
funimp_fscc:

	bsr.l	_fscc	* FS<cc>()

* I am assuming here that an "fs<cc>.b -(An)" or "fs<cc>.b (An)+" instruction
* does not need to update "An" before taking a bsun exception.
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#fbsun_flg * is enabled bsun occurring?
	beq.w	funimp_bsun

	btst	#$5,EXC_LV+EXC_SR(a6)	* yes; is it a user mode exception?
	bne.b	funimp_fscc_s	* no

funimp_fscc_u:
	move.l	EXC_LV+EXC_A7(a6),a0	* yes; set new USP
	move.l	a0,usp
	bra.w	funimp_done	* branch to finish	

* remember, I'm assuming that post-increment is bogus...(it IS!!!)
* so, the least significant WORD of the stacked effective address got
* overwritten by the "fs<cc> -(An)". We must shift the stack frame "down"
* so that the rte will work correctly without destroying the result.
* even though the operation size is byte, the stack ptr is decr by 2.
*
* remember, also, this instruction may be traced.
funimp_fscc_s:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg * was a7 modified?
	bne.w	funimp_done	* no

	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	unlk	a6

	btst	#$7,(sp)	* is trace enabled?
	bne.b	funimp_fscc_s_trace	* yes

	subq.l	#$2,sp
	move.l	$2(sp),(sp)	* shift SR,hi(PC) "down"
	move.l	$6(sp),$4(sp)	* shift lo(PC),voff "down"
	bra.l	_fpsp_done

funimp_fscc_s_trace:
	subq.l	#$2,sp
	move.l	$2(sp),(sp)	* shift SR,hi(PC) "down"
	move.w	$6(sp),$4(sp)	* shift lo(PC)
	move.w	#$2024,$6(sp)	* fmt/voff = $2024
	fmove.l	fpiar,$8(sp)	* insert "current PC"

	bra.l	_real_trace
	
*
* The ftrap<cc>, fs<cc>, or fdb<cc> is to take an enabled bsun. we must convert
* the fp unimplemented instruction exception stack frame into a bsun stack frame,
* restore a bsun exception into the machine, and branch to the user
* supplied bsun hook.
*
*	 FP UNIMP FRAME	   BSUN FRAME
*	*****************	*****************
*	**    <EA>     **	* $0 * $0c0
*	*****************	*****************
*	* $2 *  $02c  *	** Current PC  **
*	*****************	*****************
*	**   Next PC   **	*      SR
*	*****************	*****************
*	*      SR	*	    (4 words)
*	*****************
*	    (6 words)
*
funimp_bsun:
	move.w	#$00c0,2+EXC_LV+EXC_EA(a6)	* Fmt = $0; Vector Offset = $0c0
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_VOFF(a6) * PC = Current PC
	move.w	EXC_LV+EXC_SR(a6),2+EXC_LV+EXC_PC(a6) * shift SR "up"

	move.w	#$e000,2+EXC_LV+FP_SRC(a6)	* bsun exception enabled

	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	frestore	EXC_LV+FP_SRC(a6)	* restore bsun exception

	unlk	a6

	addq.l	#$4,sp	* erase sludge

	bra.l	_real_bsun	* branch to user bsun hook

*
* all ftrapcc/fscc/fdbcc processing has been completed. unwind the stack frame
* and return.
*
* as usual, we have to check for trace mode being on here. since instructions
* modifying the supervisor stack frame don't pass through here, this is a
* relatively easy task.
*
funimp_done:
	fmovem.x	EXC_LV+EXC_FP0(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
 	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1 	* restore d0-d1/a0-a1

	unlk	a6

	btst	#$7,(sp)	* is trace enabled?
	bne.b	funimp_trace	* yes

	bra.l	_fpsp_done

*	 FP UNIMP FRAME	  TRACE  FRAME
*	*****************	*****************
*	**    <EA>     **	**  Current PC **
*	*****************	*****************
*	* $2 *  $02c	*	* $2 *  $024  *
*	*****************	*****************
*	**   Next PC   **	**   Next PC   **
*	*****************	*****************
*	*      SR	*	*      SR
*	*****************	*****************
*	    (6 words)	    (6 words)
*
* the fscc instruction should take a trace trap. so, here we must create a
* trace stack frame from an unimplemented fp instruction stack frame and
* jump to the user supplied entry point for the trace exception
funimp_trace:
	fmove.l	fpiar,$8(sp)	* current PC is in fpiar
	move.b	#$24,$7(sp)	* vector offset = $024

	bra.l	_real_trace

**

	xdef	tbl_trans
	illegal
        dc.w	$1c0
tbl_trans:
	dc.w 	tbl_trans - tbl_trans	* $00-0 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-1 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-2 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-3 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-4 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-5 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-6 fmovecr all
	dc.w 	tbl_trans - tbl_trans	* $00-7 fmovecr all

	dc.w 	tbl_trans - tbl_trans	* $01-0 fint norm
	dc.w	tbl_trans - tbl_trans	* $01-1 fint zero
	dc.w	tbl_trans - tbl_trans	* $01-2 fint inf
	dc.w	tbl_trans - tbl_trans	* $01-3 fint qnan
	dc.w	tbl_trans - tbl_trans	* $01-5 fint denorm
	dc.w	tbl_trans - tbl_trans	* $01-4 fint snan
	dc.w	tbl_trans - tbl_trans	* $01-6 fint unnorm
	dc.w	tbl_trans - tbl_trans	* $01-7 ERROR

	dc.w	ssinh	 - tbl_trans	* $02-0 fsinh norm
	dc.w	src_zero - tbl_trans	* $02-1 fsinh zero
	dc.w	src_inf	 - tbl_trans	* $02-2 fsinh inf
	dc.w	src_qnan - tbl_trans	* $02-3 fsinh qnan
	dc.w	ssinhd	 - tbl_trans	* $02-5 fsinh denorm
	dc.w	src_snan - tbl_trans	* $02-4 fsinh snan
	dc.w	tbl_trans - tbl_trans	* $02-6 fsinh unnorm
	dc.w	tbl_trans - tbl_trans	* $02-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $03-0 fintrz norm
	dc.w	tbl_trans - tbl_trans	* $03-1 fintrz zero
	dc.w	tbl_trans - tbl_trans	* $03-2 fintrz inf
	dc.w	tbl_trans - tbl_trans	* $03-3 fintrz qnan
	dc.w	tbl_trans - tbl_trans	* $03-5 fintrz denorm
	dc.w	tbl_trans - tbl_trans	* $03-4 fintrz snan
	dc.w	tbl_trans - tbl_trans	* $03-6 fintrz unnorm
	dc.w	tbl_trans - tbl_trans	* $03-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $04-0 fsqrt norm
	dc.w	tbl_trans - tbl_trans	* $04-1 fsqrt zero
	dc.w	tbl_trans - tbl_trans	* $04-2 fsqrt inf
	dc.w	tbl_trans - tbl_trans	* $04-3 fsqrt qnan
	dc.w	tbl_trans - tbl_trans	* $04-5 fsqrt denorm
	dc.w	tbl_trans - tbl_trans	* $04-4 fsqrt snan
	dc.w	tbl_trans - tbl_trans	* $04-6 fsqrt unnorm
	dc.w	tbl_trans - tbl_trans	* $04-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $05-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $05-7 ERROR

	dc.w	slognp1	 - tbl_trans	* $06-0 flognp1 norm
	dc.w	src_zero - tbl_trans	* $06-1 flognp1 zero
	dc.w	sopr_inf - tbl_trans	* $06-2 flognp1 inf
	dc.w	src_qnan - tbl_trans	* $06-3 flognp1 qnan
	dc.w	slognp1d - tbl_trans	* $06-5 flognp1 denorm
	dc.w	src_snan - tbl_trans	* $06-4 flognp1 snan
	dc.w	tbl_trans - tbl_trans	* $06-6 flognp1 unnorm
	dc.w	tbl_trans - tbl_trans	* $06-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $07-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $07-7 ERROR

	dc.w	setoxm1	 - tbl_trans	* $08-0 fetoxm1 norm
	dc.w	src_zero - tbl_trans	* $08-1 fetoxm1 zero
	dc.w	setoxm1i - tbl_trans	* $08-2 fetoxm1 inf
	dc.w	src_qnan - tbl_trans	* $08-3 fetoxm1 qnan
	dc.w	setoxm1d - tbl_trans	* $08-5 fetoxm1 denorm
	dc.w	src_snan - tbl_trans	* $08-4 fetoxm1 snan
	dc.w	tbl_trans - tbl_trans	* $08-6 fetoxm1 unnorm
	dc.w	tbl_trans - tbl_trans	* $08-7 ERROR

	dc.w	stanh	 - tbl_trans	* $09-0 ftanh norm
	dc.w	src_zero - tbl_trans	* $09-1 ftanh zero
	dc.w	src_one	 - tbl_trans	* $09-2 ftanh inf
	dc.w	src_qnan - tbl_trans	* $09-3 ftanh qnan
	dc.w	stanhd	 - tbl_trans	* $09-5 ftanh denorm
	dc.w	src_snan - tbl_trans	* $09-4 ftanh snan
	dc.w	tbl_trans - tbl_trans	* $09-6 ftanh unnorm
	dc.w	tbl_trans - tbl_trans	* $09-7 ERROR

	dc.w	satan	 - tbl_trans	* $0a-0 fatan norm
	dc.w	src_zero - tbl_trans	* $0a-1 fatan zero
	dc.w	spi_2	 - tbl_trans	* $0a-2 fatan inf
	dc.w	src_qnan - tbl_trans	* $0a-3 fatan qnan
	dc.w	satand	 - tbl_trans	* $0a-5 fatan denorm
	dc.w	src_snan - tbl_trans	* $0a-4 fatan snan
	dc.w	tbl_trans - tbl_trans	* $0a-6 fatan unnorm
	dc.w	tbl_trans - tbl_trans	* $0a-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $0b-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $0b-7 ERROR

	dc.w	sasin	 - tbl_trans	* $0c-0 fasin norm
	dc.w	src_zero - tbl_trans	* $0c-1 fasin zero
	dc.w	t_operr	 - tbl_trans	* $0c-2 fasin inf
	dc.w	src_qnan - tbl_trans	* $0c-3 fasin qnan
	dc.w	sasind	 - tbl_trans	* $0c-5 fasin denorm
	dc.w	src_snan - tbl_trans	* $0c-4 fasin snan
	dc.w	tbl_trans - tbl_trans	* $0c-6 fasin unnorm
	dc.w	tbl_trans - tbl_trans	* $0c-7 ERROR

	dc.w	satanh	 - tbl_trans	* $0d-0 fatanh norm
	dc.w	src_zero - tbl_trans	* $0d-1 fatanh zero
	dc.w	t_operr	 - tbl_trans	* $0d-2 fatanh inf
	dc.w	src_qnan - tbl_trans	* $0d-3 fatanh qnan
	dc.w	satanhd	 - tbl_trans	* $0d-5 fatanh denorm
	dc.w	src_snan - tbl_trans	* $0d-4 fatanh snan
	dc.w	tbl_trans - tbl_trans	* $0d-6 fatanh unnorm
	dc.w	tbl_trans - tbl_trans	* $0d-7 ERROR

	dc.w	ssin	 - tbl_trans	* $0e-0 fsin norm
	dc.w	src_zero - tbl_trans	* $0e-1 fsin zero
	dc.w	t_operr	 - tbl_trans	* $0e-2 fsin inf
	dc.w	src_qnan - tbl_trans	* $0e-3 fsin qnan
	dc.w	ssind	 - tbl_trans	* $0e-5 fsin denorm
	dc.w	src_snan - tbl_trans	* $0e-4 fsin snan
	dc.w	tbl_trans - tbl_trans	* $0e-6 fsin unnorm
	dc.w	tbl_trans - tbl_trans	* $0e-7 ERROR
	
	dc.w	stan	 - tbl_trans	* $0f-0 ftan norm
	dc.w	src_zero - tbl_trans	* $0f-1 ftan zero
	dc.w	t_operr	 - tbl_trans	* $0f-2 ftan inf
	dc.w	src_qnan - tbl_trans	* $0f-3 ftan qnan
	dc.w	stand	 - tbl_trans	* $0f-5 ftan denorm
	dc.w	src_snan - tbl_trans	* $0f-4 ftan snan
	dc.w	tbl_trans - tbl_trans	* $0f-6 ftan unnorm
	dc.w	tbl_trans - tbl_trans	* $0f-7 ERROR

	dc.w	setox	 - tbl_trans	* $10-0 fetox norm
	dc.w	ld_pone	 - tbl_trans	* $10-1 fetox zero
	dc.w	szr_inf	 - tbl_trans	* $10-2 fetox inf
	dc.w	src_qnan - tbl_trans	* $10-3 fetox qnan
	dc.w	setoxd	 - tbl_trans	* $10-5 fetox denorm
	dc.w	src_snan - tbl_trans	* $10-4 fetox snan
	dc.w	tbl_trans - tbl_trans	* $10-6 fetox unnorm
	dc.w	tbl_trans - tbl_trans	* $10-7 ERROR

	dc.w	stwotox	 - tbl_trans	* $11-0 ftwotox norm
	dc.w	ld_pone	 - tbl_trans	* $11-1 ftwotox zero
	dc.w	szr_inf	 - tbl_trans	* $11-2 ftwotox inf
	dc.w	src_qnan - tbl_trans	* $11-3 ftwotox qnan
	dc.w	stwotoxd - tbl_trans	* $11-5 ftwotox denorm
	dc.w	src_snan - tbl_trans	* $11-4 ftwotox snan
	dc.w	tbl_trans - tbl_trans	* $11-6 ftwotox unnorm
	dc.w	tbl_trans - tbl_trans	* $11-7 ERROR

	dc.w	stentox	 - tbl_trans	* $12-0 ftentox norm
	dc.w	ld_pone	 - tbl_trans	* $12-1 ftentox zero
	dc.w	szr_inf	 - tbl_trans	* $12-2 ftentox inf
	dc.w	src_qnan - tbl_trans	* $12-3 ftentox qnan
	dc.w	stentoxd - tbl_trans	* $12-5 ftentox denorm
	dc.w	src_snan - tbl_trans	* $12-4 ftentox snan
	dc.w	tbl_trans - tbl_trans	* $12-6 ftentox unnorm
	dc.w	tbl_trans - tbl_trans	* $12-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $13-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $13-7 ERROR

	dc.w	slogn	 - tbl_trans	* $14-0 flogn norm
	dc.w	t_dz2	 - tbl_trans	* $14-1 flogn zero
	dc.w	sopr_inf - tbl_trans	* $14-2 flogn inf
	dc.w	src_qnan - tbl_trans	* $14-3 flogn qnan
	dc.w	slognd	 - tbl_trans	* $14-5 flogn denorm
	dc.w	src_snan - tbl_trans	* $14-4 flogn snan
	dc.w	tbl_trans - tbl_trans	* $14-6 flogn unnorm
	dc.w	tbl_trans - tbl_trans	* $14-7 ERROR

	dc.w	slog10	 - tbl_trans	* $15-0 flog10 norm
	dc.w	t_dz2	 - tbl_trans	* $15-1 flog10 zero
	dc.w	sopr_inf - tbl_trans	* $15-2 flog10 inf
	dc.w	src_qnan - tbl_trans	* $15-3 flog10 qnan
	dc.w	slog10d	 - tbl_trans	* $15-5 flog10 denorm
	dc.w	src_snan - tbl_trans	* $15-4 flog10 snan
	dc.w	tbl_trans - tbl_trans	* $15-6 flog10 unnorm
	dc.w	tbl_trans - tbl_trans	* $15-7 ERROR

	dc.w	slog2	 - tbl_trans	* $16-0 flog2 norm
	dc.w	t_dz2	 - tbl_trans	* $16-1 flog2 zero
	dc.w	sopr_inf - tbl_trans	* $16-2 flog2 inf
	dc.w	src_qnan - tbl_trans	* $16-3 flog2 qnan
	dc.w	slog2d	 - tbl_trans	* $16-5 flog2 denorm
	dc.w	src_snan - tbl_trans	* $16-4 flog2 snan
	dc.w	tbl_trans - tbl_trans	* $16-6 flog2 unnorm
	dc.w	tbl_trans - tbl_trans	* $16-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $17-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $17-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $18-0 fabs norm
	dc.w	tbl_trans - tbl_trans	* $18-1 fabs zero
	dc.w	tbl_trans - tbl_trans	* $18-2 fabs inf
	dc.w	tbl_trans - tbl_trans	* $18-3 fabs qnan
	dc.w	tbl_trans - tbl_trans	* $18-5 fabs denorm
	dc.w	tbl_trans - tbl_trans	* $18-4 fabs snan
	dc.w	tbl_trans - tbl_trans	* $18-6 fabs unnorm
	dc.w	tbl_trans - tbl_trans	* $18-7 ERROR

	dc.w	scosh	 - tbl_trans	* $19-0 fcosh norm
	dc.w	ld_pone	 - tbl_trans	* $19-1 fcosh zero
	dc.w	ld_pinf	 - tbl_trans	* $19-2 fcosh inf
	dc.w	src_qnan - tbl_trans	* $19-3 fcosh qnan
	dc.w	scoshd	 - tbl_trans	* $19-5 fcosh denorm
	dc.w	src_snan - tbl_trans	* $19-4 fcosh snan
	dc.w	tbl_trans - tbl_trans	* $19-6 fcosh unnorm
	dc.w	tbl_trans - tbl_trans	* $19-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $1a-0 fneg norm
	dc.w	tbl_trans - tbl_trans	* $1a-1 fneg zero
	dc.w	tbl_trans - tbl_trans	* $1a-2 fneg inf
	dc.w	tbl_trans - tbl_trans	* $1a-3 fneg qnan
	dc.w	tbl_trans - tbl_trans	* $1a-5 fneg denorm
	dc.w	tbl_trans - tbl_trans	* $1a-4 fneg snan
	dc.w	tbl_trans - tbl_trans	* $1a-6 fneg unnorm
	dc.w	tbl_trans - tbl_trans	* $1a-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $1b-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $1b-7 ERROR

	dc.w	sacos	 - tbl_trans	* $1c-0 facos norm
	dc.w	ld_ppi2	 - tbl_trans	* $1c-1 facos zero
	dc.w	t_operr	 - tbl_trans	* $1c-2 facos inf
	dc.w	src_qnan - tbl_trans	* $1c-3 facos qnan
	dc.w	sacosd	 - tbl_trans	* $1c-5 facos denorm
	dc.w	src_snan - tbl_trans	* $1c-4 facos snan
	dc.w	tbl_trans - tbl_trans	* $1c-6 facos unnorm
	dc.w	tbl_trans - tbl_trans	* $1c-7 ERROR

	dc.w	scos	 - tbl_trans	* $1d-0 fcos norm
	dc.w	ld_pone	 - tbl_trans	* $1d-1 fcos zero
	dc.w	t_operr	 - tbl_trans	* $1d-2 fcos inf
	dc.w	src_qnan - tbl_trans	* $1d-3 fcos qnan
	dc.w	scosd	 - tbl_trans	* $1d-5 fcos denorm
	dc.w	src_snan - tbl_trans	* $1d-4 fcos snan
	dc.w	tbl_trans - tbl_trans	* $1d-6 fcos unnorm
	dc.w	tbl_trans - tbl_trans	* $1d-7 ERROR

	dc.w	sgetexp	 - tbl_trans	* $1e-0 fgetexp norm
	dc.w	src_zero - tbl_trans	* $1e-1 fgetexp zero
	dc.w	t_operr	 - tbl_trans	* $1e-2 fgetexp inf
	dc.w	src_qnan - tbl_trans	* $1e-3 fgetexp qnan
	dc.w	sgetexpd - tbl_trans	* $1e-5 fgetexp denorm
	dc.w	src_snan - tbl_trans	* $1e-4 fgetexp snan
	dc.w	tbl_trans - tbl_trans	* $1e-6 fgetexp unnorm
	dc.w	tbl_trans - tbl_trans	* $1e-7 ERROR

	dc.w	sgetman	 - tbl_trans	* $1f-0 fgetman norm
	dc.w	src_zero - tbl_trans	* $1f-1 fgetman zero
	dc.w	t_operr	 - tbl_trans	* $1f-2 fgetman inf
	dc.w	src_qnan - tbl_trans	* $1f-3 fgetman qnan
	dc.w	sgetmand - tbl_trans	* $1f-5 fgetman denorm
	dc.w	src_snan - tbl_trans	* $1f-4 fgetman snan
	dc.w	tbl_trans - tbl_trans	* $1f-6 fgetman unnorm
	dc.w	tbl_trans - tbl_trans	* $1f-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $20-0 fdiv norm
	dc.w	tbl_trans - tbl_trans	* $20-1 fdiv zero
	dc.w	tbl_trans - tbl_trans	* $20-2 fdiv inf
	dc.w	tbl_trans - tbl_trans	* $20-3 fdiv qnan
	dc.w	tbl_trans - tbl_trans	* $20-5 fdiv denorm
	dc.w	tbl_trans - tbl_trans	* $20-4 fdiv snan
	dc.w	tbl_trans - tbl_trans	* $20-6 fdiv unnorm
	dc.w	tbl_trans - tbl_trans	* $20-7 ERROR

	dc.w	smod_snorm - tbl_trans	* $21-0 fmod norm
	dc.w	smod_szero - tbl_trans	* $21-1 fmod zero
	dc.w	smod_sinf - tbl_trans	* $21-2 fmod inf
	dc.w	sop_sqnan - tbl_trans	* $21-3 fmod qnan
	dc.w	smod_sdnrm - tbl_trans	* $21-5 fmod denorm
	dc.w	sop_ssnan - tbl_trans	* $21-4 fmod snan
	dc.w	tbl_trans - tbl_trans	* $21-6 fmod unnorm
	dc.w	tbl_trans - tbl_trans	* $21-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $22-0 fadd norm
	dc.w	tbl_trans - tbl_trans	* $22-1 fadd zero
	dc.w	tbl_trans - tbl_trans	* $22-2 fadd inf
	dc.w	tbl_trans - tbl_trans	* $22-3 fadd qnan
	dc.w	tbl_trans - tbl_trans	* $22-5 fadd denorm
	dc.w	tbl_trans - tbl_trans	* $22-4 fadd snan
	dc.w	tbl_trans - tbl_trans	* $22-6 fadd unnorm
	dc.w	tbl_trans - tbl_trans	* $22-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $23-0 fmul norm
	dc.w	tbl_trans - tbl_trans	* $23-1 fmul zero
	dc.w	tbl_trans - tbl_trans	* $23-2 fmul inf
	dc.w	tbl_trans - tbl_trans	* $23-3 fmul qnan
	dc.w	tbl_trans - tbl_trans	* $23-5 fmul denorm
	dc.w	tbl_trans - tbl_trans	* $23-4 fmul snan
	dc.w	tbl_trans - tbl_trans	* $23-6 fmul unnorm
	dc.w	tbl_trans - tbl_trans	* $23-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $24-0 fsgldiv norm
	dc.w	tbl_trans - tbl_trans	* $24-1 fsgldiv zero
	dc.w	tbl_trans - tbl_trans	* $24-2 fsgldiv inf
	dc.w	tbl_trans - tbl_trans	* $24-3 fsgldiv qnan
	dc.w	tbl_trans - tbl_trans	* $24-5 fsgldiv denorm
	dc.w	tbl_trans - tbl_trans	* $24-4 fsgldiv snan
	dc.w	tbl_trans - tbl_trans	* $24-6 fsgldiv unnorm
	dc.w	tbl_trans - tbl_trans	* $24-7 ERROR

	dc.w	srem_snorm - tbl_trans	* $25-0 frem norm
	dc.w	srem_szero - tbl_trans	* $25-1 frem zero
	dc.w	srem_sinf - tbl_trans	* $25-2 frem inf
	dc.w	sop_sqnan - tbl_trans	* $25-3 frem qnan
	dc.w	srem_sdnrm - tbl_trans	* $25-5 frem denorm
	dc.w	sop_ssnan - tbl_trans	* $25-4 frem snan
	dc.w	tbl_trans - tbl_trans	* $25-6 frem unnorm
	dc.w	tbl_trans - tbl_trans	* $25-7 ERROR

	dc.w	sscale_snorm - tbl_trans * $26-0 fscale norm
	dc.w	sscale_szero - tbl_trans * $26-1 fscale zero
	dc.w	sscale_sinf - tbl_trans	* $26-2 fscale inf
	dc.w	sop_sqnan - tbl_trans	* $26-3 fscale qnan
	dc.w	sscale_sdnrm - tbl_trans * $26-5 fscale denorm
	dc.w	sop_ssnan - tbl_trans	* $26-4 fscale snan
	dc.w	tbl_trans - tbl_trans	* $26-6 fscale unnorm
	dc.w	tbl_trans - tbl_trans	* $26-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $27-0 fsglmul norm
	dc.w	tbl_trans - tbl_trans	* $27-1 fsglmul zero
	dc.w	tbl_trans - tbl_trans	* $27-2 fsglmul inf
	dc.w	tbl_trans - tbl_trans	* $27-3 fsglmul qnan
	dc.w	tbl_trans - tbl_trans	* $27-5 fsglmul denorm
	dc.w	tbl_trans - tbl_trans	* $27-4 fsglmul snan
	dc.w	tbl_trans - tbl_trans	* $27-6 fsglmul unnorm
	dc.w	tbl_trans - tbl_trans	* $27-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $28-0 fsub norm
	dc.w	tbl_trans - tbl_trans	* $28-1 fsub zero
	dc.w	tbl_trans - tbl_trans	* $28-2 fsub inf
	dc.w	tbl_trans - tbl_trans	* $28-3 fsub qnan
	dc.w	tbl_trans - tbl_trans	* $28-5 fsub denorm
	dc.w	tbl_trans - tbl_trans	* $28-4 fsub snan
	dc.w	tbl_trans - tbl_trans	* $28-6 fsub unnorm
	dc.w	tbl_trans - tbl_trans	* $28-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $29-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $29-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2a-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2a-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2b-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2b-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2c-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2c-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2d-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2d-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2e-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2e-7 ERROR

	dc.w	tbl_trans - tbl_trans	* $2f-0 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-1 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-2 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-3 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-4 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-5 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-6 ERROR
	dc.w	tbl_trans - tbl_trans	* $2f-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $30-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $30-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $30-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $30-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $30-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $30-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $30-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $30-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $31-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $31-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $31-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $31-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $31-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $31-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $31-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $31-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $32-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $32-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $32-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $32-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $32-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $32-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $32-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $32-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $33-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $33-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $33-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $33-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $33-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $33-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $33-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $33-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $34-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $34-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $34-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $34-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $34-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $34-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $34-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $34-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $35-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $35-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $35-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $35-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $35-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $35-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $35-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $35-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $36-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $36-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $36-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $36-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $36-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $36-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $36-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $36-7 ERROR

	dc.w	ssincos	 - tbl_trans	* $37-0 fsincos norm
	dc.w	ssincosz - tbl_trans	* $37-1 fsincos zero
	dc.w	ssincosi - tbl_trans	* $37-2 fsincos inf
	dc.w	ssincosqnan - tbl_trans	* $37-3 fsincos qnan
	dc.w	ssincosd - tbl_trans	* $37-5 fsincos denorm
	dc.w	ssincossnan - tbl_trans	* $37-4 fsincos snan
	dc.w	tbl_trans - tbl_trans	* $37-6 fsincos unnorm
	dc.w	tbl_trans - tbl_trans	* $37-7 ERROR

**********

* the instruction fetch access for the displacement word for the
* fdbcc emulation failed. here, we create an access error frame
* from the current frame and branch to _real_access().
funimp_iacc:
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1

	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_PC(a6) * store current PC

	unlk	a6

	move.l	(sp),-(sp)	* store SR,hi(PC)
	move.w	$8(sp),$4(sp)	* store lo(PC)
	move.w	#$4008,$6(sp)	* store voff
	move.l	$2(sp),$8(sp)	* store EA
	move.l	#$09428001,$c(sp)	* store FSLW

	btst	#$5,(sp)	* user or supervisor mode?
	beq.b	funimp_iacc_end	* user
	bset	#$2,$d(sp)	* set supervisor TM bit

funimp_iacc_end:
	bra.l	_real_access

**-------------------------------------------------------------------------------------------------
* ssin():     computes the sine of a normalized input
* ssind():    computes the sine of a denormalized input
* scos():     computes the cosine of a normalized input
* scosd():    computes the cosine of a denormalized input
* ssincos():  computes the sine and cosine of a normalized input
* ssincosd(): computes the sine and cosine of a denormalized input
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = sin(X) or cos(X) 	
*		
*    For ssincos(X):	
*	fp0 = sin(X)	
*	fp1 = cos(X)	
*		
* ACCURACY and MONOTONICITY ******************************************* *
*	The returned result is within 1 ulp in 64 significant bit, i.e.
*	within 0.5001 ulp to 53 bits if the result is subsequently 
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	SIN and COS:	
*	1. If SIN is invoked, set AdjN := 0; otherwise, set AdjN := 1.
*		
*	2. If |X| >= 15Pi or |X| < 2**(-40), go to 7.
*		
*	3. Decompose X as X = N(Pi/2) + r where |r| <= Pi/4. Let
*	k = N mod 4, so in particular, k = 0,1,2,or 3.
*	Overwrite k by k := k + AdjN.
*		
*	4. If k is even, go to 6.	
*		
*	5. (k is odd) Set j := (k-1)/2, sgn := (-1)**j. 
*	Return sgn*cos(r) where cos(r) is approximated by an 
*	even polynomial in r, 1 + r*r*(B1+s*(B2+ ... + s*B8)),
*	s = r*r.	
*	Exit.	
*		
*	6. (k is even) Set j := k/2, sgn := (-1)**j. Return sgn*sin(r)
*	where sin(r) is approximated by an odd polynomial in r
*	r + r*s*(A1+s*(A2+ ... + s*A7)),	s = r*r.
*	Exit.	
*		
*	7. If |X| > 1, go to 9.	
*		
*	8. (|X|<2**(-40)) If SIN is invoked, return X; 
*	otherwise return 1.	
*		
*	9. Overwrite X by X := X rem 2Pi. Now that |X| <= Pi, 
*	go back to 3.	
*		
*	SINCOS:	
*	1. If |X| >= 15Pi or |X| < 2**(-40), go to 6.
*		
*	2. Decompose X as X = N(Pi/2) + r where |r| <= Pi/4. Let
*	k = N mod 4, so in particular, k = 0,1,2,or 3.
*		
*	3. If k is even, go to 5.	
*		
*	4. (k is odd) Set j1 := (k-1)/2, j2 := j1 (EOR) (k mod 2), ie.
*	j1 exclusive or with the l.s.b. of k.
*	sgn1 := (-1)**j1, sgn2 := (-1)**j2.
*	SIN(X) = sgn1 * cos(r) and COS(X) = sgn2*sin(r) where
*	sin(r) and cos(r) are computed as odd and even 
*	polynomials in r, respectively. Exit
*		
*	5. (k is even) Set j1 := k/2, sgn1 := (-1)**j1.
*	SIN(X) = sgn1 * sin(r) and COS(X) = sgn1*cos(r) where
*	sin(r) and cos(r) are computed as odd and even 
*	polynomials in r, respectively. Exit
*		
*	6. If |X| > 1, go to 8.	
*		
*	7. (|X|<2**(-40)) SIN(X) = X and COS(X) = 1. Exit.
*		
*	8. Overwrite X by X := X rem 2Pi. Now that |X| <= Pi, 
*	go back to 2.	
*		
**-------------------------------------------------------------------------------------------------

SINA7:	dc.l	$BD6AAA77,$CCC994F5
SINA6:	dc.l	$3DE61209,$7AAE8DA1
SINA5:	dc.l	$BE5AE645,$2A118AE4
SINA4:	dc.l	$3EC71DE3,$A5341531
SINA3:	dc.l	$BF2A01A0,$1A018B59,$00000000,$00000000
SINA2:	dc.l	$3FF80000,$88888888,$888859AF,$00000000
SINA1:	dc.l	$BFFC0000,$AAAAAAAA,$AAAAAA99,$00000000

COSB8:	dc.l	$3D2AC4D0,$D6011EE3
COSB7:	dc.l	$BDA9396F,$9F45AC19
COSB6:	dc.l	$3E21EED9,$0612C972
COSB5:	dc.l	$BE927E4F,$B79D9FCF
COSB4:	dc.l	$3EFA01A0,$1A01D423,$00000000,$00000000
COSB3:	dc.l	$BFF50000,$B60B60B6,$0B61D438,$00000000
COSB2:	dc.l	$3FFA0000,$AAAAAAAA,$AAAAAB5E
COSB1:	dc.l	$BF000000

INARG	equ	EXC_LV+FP_SCR0

X	equ	EXC_LV+FP_SCR0
*XDCARE	equ	X+2
XFRAC	equ	X+4

RPRIME	equ	EXC_LV+FP_SCR0
SPRIME	equ	EXC_LV+FP_SCR1

POSNEG1	equ	EXC_LV+L_SCR1
TWOTO63	equ	EXC_LV+L_SCR1

ENDFLAG	equ	EXC_LV+L_SCR2
INT	equ	EXC_LV+L_SCR2

ADJN	equ	EXC_LV+L_SCR3

********************************************
	xdef	ssin
ssin:
	move.l	#0,ADJN(a6)	* yes; SET ADJN TO 0
	bra.b	SINBGN

********************************************
	xdef	scos
scos:
	move.l	#1,ADJN(a6)	* yes; SET ADJN TO 1

********************************************
SINBGN:
*--SAVE FPCR, FP1. CHECK IF |X| IS TOO SMALL OR LARGE

	fmove.x	(a0),fp0	* LOAD INPUT
	fmove.x	fp0,X(a6)	* save input at X

* "COMPACTIFY" X
	move.l	(a0),d1	* put exp in hi word
	move.w	4(a0),d1	* fetch hi(man)
	and.l	#$7FFFFFFF,d1	* strip sign

	ICMP.l	d1,#$3FD78000	* is |X| >= 2**(-40)?
	bge.b	SOK1	* no
	bra.w	SINSM	* yes; input is very small

SOK1:
	ICMP.l	d1,#$4004BC7E	* is |X| < 15 PI?
	blt.b	SINMAIN	* no
	bra.w	SREDUCEX	* yes; input is very large

*--THIS IS THE USUAL CASE, |X| <= 15 PI.
*--THE ARGUMENT REDUCTION IS DONE BY TABLE LOOK UP.
SINMAIN:
	fmove.x	fp0,fp1
	fmul.d	TWOBYPI(pc),fp1 	* X*2/PI

	lea	PITBL+$200(pc),a1 	* TABLE OF N*PI/2, N = -32,...,32

	fmove.l	fp1,INT(a6)	* CONVERT TO INTEGER

	move.l	INT(a6),d1	* make a copy of N
	asl.l	#4,d1	* N *= 16
	add.l	d1,a1	* tbl_addr = a1 + (N*16)

* A1 IS THE ADDRESS OF N*PIBY2
* ...WHICH IS IN TWO PIECES Y1 # Y2
	fsub.x	(a1)+,fp0 	* X-Y1
	fsub.s	(a1),fp0 	* fp0 = R = (X-Y1)-Y2

SINCONT:
*--continuation from REDUCEX

*--GET N+ADJN AND SEE IF SIN(R) OR COS(R) IS NEEDED
	move.l	INT(a6),d1
	add.l	ADJN(a6),d1	* SEE IF D0 IS ODD OR EVEN
	ror.l	#1,d1	* D0 WAS ODD IFF D0 IS NEGATIVE
	cmp.l	#0,d1
	blt.w	COSPOLY

*--LET J BE THE LEAST SIG. BIT OF D0, LET SGN := (-1)**J.
*--THEN WE RETURN	SGN*SIN(R). SGN*SIN(R) IS COMPUTED BY
*--R' + R'*S*(A1 + S(A2 + S(A3 + S(A4 + ... + SA7)))), WHERE
*--R' = SGN*R, S=R*R. THIS CAN BE REWRITTEN AS
*--R' + R'*S*( [A1+T(A3+T(A5+TA7))] + [S(A2+T(A4+TA6))])
*--WHERE T=S*S.
*--NOTE THAT A3 THROUGH A7 ARE STORED IN DOUBLE PRECISION
*--WHILE A1 AND A2 ARE IN DOUBLE-EXTENDED FORMAT.
SINPOLY:
	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmove.x	fp0,X(a6)	* X IS R
	fmul.x	fp0,fp0	* FP0 IS S

	fmove.d	SINA7(pc),fp3
	fmove.d	SINA6(pc),fp2

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS T

	ror.l	#1,d1
	and.l	#$80000000,d1
* ...LEAST SIG. BIT OF D0 IN SIGN POSITION
	eor.l	d1,X(a6)	* X IS NOW R'= SGN*R

	fmul.x	fp1,fp3	* TA7
	fmul.x	fp1,fp2	* TA6

	fadd.d	SINA5(pc),fp3	* A5+TA7
	fadd.d	SINA4(pc),fp2	* A4+TA6

	fmul.x	fp1,fp3	* T(A5+TA7)
	fmul.x	fp1,fp2	* T(A4+TA6)

	fadd.d	SINA3(pc),fp3	* A3+T(A5+TA7)
	fadd.x	SINA2(pc),fp2	* A2+T(A4+TA6)

	fmul.x	fp3,fp1	* T(A3+T(A5+TA7))

	fmul.x	fp0,fp2	* S(A2+T(A4+TA6))
	fadd.x	SINA1(pc),fp1	* A1+T(A3+T(A5+TA7))
	fmul.x	X(a6),fp0	* R'*S

	fadd.x	fp2,fp1	* [A1+T(A3+T(A5+TA7))]+[S(A2+T(A4+TA6))]

	fmul.x	fp1,fp0	* SIN(R')-R'

	fmovem.x	(sp)+,fp2-fp3	* restore fp2/fp3

	fmove.l	d0,fpcr	* restore users round mode,prec
	fadd.x	X(a6),fp0	* last inst - possible exception set
	bra	t_inx2

*--LET J BE THE LEAST SIG. BIT OF D0, LET SGN := (-1)**J.
*--THEN WE RETURN	SGN*COS(R). SGN*COS(R) IS COMPUTED BY
*--SGN + S'*(B1 + S(B2 + S(B3 + S(B4 + ... + SB8)))), WHERE
*--S=R*R AND S'=SGN*S. THIS CAN BE REWRITTEN AS
*--SGN + S'*([B1+T(B3+T(B5+TB7))] + [S(B2+T(B4+T(B6+TB8)))])
*--WHERE T=S*S.
*--NOTE THAT B4 THROUGH B8 ARE STORED IN DOUBLE PRECISION
*--WHILE B2 AND B3 ARE IN DOUBLE-EXTENDED FORMAT, B1 IS -1/2
*--AND IS THEREFORE STORED AS SINGLE PRECISION.
COSPOLY:
	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmul.x	fp0,fp0	* FP0 IS S

	fmove.d	COSB8(pc),fp2
	fmove.d	COSB7(pc),fp3

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS T

	fmove.x	fp0,X(a6)	* X IS S
	ror.l	#1,d1
	and.l	#$80000000,d1
* ...LEAST SIG. BIT OF D0 IN SIGN POSITION

	fmul.x	fp1,fp2	* TB8

	eor.l	d1,X(a6)	* X IS NOW S'= SGN*S
	and.l	#$80000000,d1

	fmul.x	fp1,fp3	* TB7

	or.l	#$3F800000,d1	* D0 IS SGN IN SINGLE
	move.l	d1,POSNEG1(a6)

	fadd.d	COSB6(pc),fp2	* B6+TB8
	fadd.d	COSB5(pc),fp3	* B5+TB7

	fmul.x	fp1,fp2	* T(B6+TB8)
	fmul.x	fp1,fp3	* T(B5+TB7)

	fadd.d	COSB4(pc),fp2	* B4+T(B6+TB8)
	fadd.x	COSB3(pc),fp3	* B3+T(B5+TB7)

	fmul.x	fp1,fp2	* T(B4+T(B6+TB8))
	fmul.x	fp3,fp1	* T(B3+T(B5+TB7))

	fadd.x	COSB2(pc),fp2	* B2+T(B4+T(B6+TB8))
	fadd.s	COSB1(pc),fp1	* B1+T(B3+T(B5+TB7))

	fmul.x	fp2,fp0	* S(B2+T(B4+T(B6+TB8)))

	fadd.x	fp1,fp0

	fmul.x	X(a6),fp0

	fmovem.x	(sp)+,fp2-fp3	* restore fp2/fp3

	fmove.l	d0,fpcr	* restore users round mode,prec
	fadd.s	POSNEG1(a6),fp0	* last inst - possible exception set
	bra	t_inx2

**********************************************

* SINe: Big OR Small?
*--IF |X| > 15PI, WE USE THE GENERAL ARGUMENT REDUCTION.
*--IF |X| < 2**(-40), RETURN X OR 1.
SINBORS:
	ICMP.l	d1,#$3FFF8000
	bgt.l	SREDUCEX

SINSM:
	move.l	ADJN(a6),d1
	ICMP.l	d1,#0
	bgt.b	COSTINY

* here, the operation may underflow iff the precision is sgl or dbl.
* extended denorms are handled through another entry point.
SINTINY:
*	move.w	#$0000,XDCARE(a6)	* JUST IN CASE

	fmove.l	d0,fpcr	* restore users round mode,prec
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	X(a6),fp0	* last inst - possible exception set
	bra	t_catch

COSTINY:
	fmove.s	#$3F800000,fp0	* fp0 = 1.0
	fmove.l	d0,fpcr	* restore users round mode,prec
	fadd.s 	#$80800000,fp0	* last inst - possible exception set
	bra	t_pinx2

************************************************
	xdef	ssind
*--SIN(X) = X FOR DENORMALIZED X
ssind:
	bra	t_extdnrm

********************************************
	xdef	scosd
*--COS(X) = 1 FOR DENORMALIZED X
scosd:
	fmove.s	#$3F800000,fp0	* fp0 = 1.0
	bra	t_pinx2

**************************************************

	xdef	ssincos
ssincos:
*--SET ADJN TO 4
	move.l	#4,ADJN(a6)

	fmove.x	(a0),fp0	* LOAD INPUT
	fmove.x	fp0,X(a6)

	move.l	(a0),d1
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1	* COMPACTIFY X

	ICMP.l	d1,#$3FD78000	* |X| >= 2**(-40)?
	bge.b	SCOK1
	bra.w	SCSM

SCOK1:
	ICMP.l	d1,#$4004BC7E	* |X| < 15 PI?
	blt.b	SCMAIN
	bra.w	SREDUCEX


*--THIS IS THE USUAL CASE, |X| <= 15 PI.
*--THE ARGUMENT REDUCTION IS DONE BY TABLE LOOK UP.
SCMAIN:
	fmove.x	fp0,fp1

	fmul.d	TWOBYPI(pc),fp1	* X*2/PI

	lea	PITBL+$200(pc),a1	* TABLE OF N*PI/2, N = -32,...,32

	fmove.l	fp1,INT(a6)	* CONVERT TO INTEGER

	move.l	INT(a6),d1
	asl.l	#4,d1
	add.l	d1,a1	* ADDRESS OF N*PIBY2, IN Y1, Y2

	fsub.x	(a1)+,fp0	* X-Y1
	fsub.s	(a1),fp0	* FP0 IS R = (X-Y1)-Y2

SCCONT:
*--continuation point from REDUCEX

	move.l	INT(a6),d1
	ror.l	#1,d1
	ICMP.l	d1,#0	* D0 < 0 IFF N IS ODD
	bge.w	NEVEN

SNODD:
*--REGISTERS SAVED SO FAR: D0, A0, FP2.
	fmovem.x	fp5,-(sp)	* save fp2

	fmove.x	fp0,RPRIME(a6)
	fmul.x	fp0,fp0	* FP0 IS S = R*R
	fmove.d	SINA7(pc),fp1	* A7
	fmove.d	COSB8(pc),fp2	* B8
	fmul.x	fp0,fp1	* SA7
	fmul.x	fp0,fp2	* SB8

	move.l	d2,-(sp)
	move.l	d1,d2
	ror.l	#1,d2
	and.l	#$80000000,d2
	eor.l	d1,d2
	and.l	#$80000000,d2

	fadd.d	SINA6(pc),fp1	* A6+SA7
	fadd.d	COSB7(pc),fp2	* B7+SB8

	fmul.x	fp0,fp1	* S(A6+SA7)
	eor.l	d2,RPRIME(a6)
	move.l	(sp)+,d2
	fmul.x	fp0,fp2	* S(B7+SB8)
	ror.l	#1,d1
	and.l	#$80000000,d1
	move.l	#$3F800000,POSNEG1(a6)
	eor.l	d1,POSNEG1(a6)

	fadd.d	SINA5(pc),fp1	* A5+S(A6+SA7)
	fadd.d	COSB6(pc),fp2	* B6+S(B7+SB8)

	fmul.x	fp0,fp1	* S(A5+S(A6+SA7))
	fmul.x	fp0,fp2	* S(B6+S(B7+SB8))
	fmove.x	fp0,SPRIME(a6)

	fadd.d	SINA4(pc),fp1	* A4+S(A5+S(A6+SA7))
	eor.l	d1,SPRIME(a6)
	fadd.d	COSB5(pc),fp2	* B5+S(B6+S(B7+SB8))

	fmul.x	fp0,fp1	* S(A4+...)
	fmul.x	fp0,fp2	* S(B5+...)

	fadd.d	SINA3(pc),fp1	* A3+S(A4+...)
	fadd.d	COSB4(pc),fp2	* B4+S(B5+...)

	fmul.x	fp0,fp1	* S(A3+...)
	fmul.x	fp0,fp2	* S(B4+...)

	fadd.x	SINA2(pc),fp1	* A2+S(A3+...)
	fadd.x	COSB3(pc),fp2	* B3+S(B4+...)

	fmul.x	fp0,fp1	* S(A2+...)
	fmul.x	fp0,fp2	* S(B3+...)

	fadd.x	SINA1(pc),fp1	* A1+S(A2+...)
	fadd.x	COSB2(pc),fp2	* B2+S(B3+...)

	fmul.x	fp0,fp1	* S(A1+...)
	fmul.x	fp2,fp0	* S(B2+...)

	fmul.x	RPRIME(a6),fp1	* R'S(A1+...)
	fadd.s	COSB1(pc),fp0	* B1+S(B2...)
	fmul.x	SPRIME(a6),fp0	* S'(B1+S(B2+...))

	fmovem.x	(sp)+,fp2	* restore fp2

	fmove.l	d0,fpcr
	fadd.x	RPRIME(a6),fp1	* COS(X)
	bsr	sto_cos	* store cosine result
	fadd.s	POSNEG1(a6),fp0	* SIN(X)
	bra	t_inx2

NEVEN:
*--REGISTERS SAVED SO FAR: FP2.
	fmovem.x	fp5,-(sp)	* save fp2

	fmove.x	fp0,RPRIME(a6)
	fmul.x	fp0,fp0	* FP0 IS S = R*R

	fmove.d	COSB8(pc),fp1	* B8
	fmove.d	SINA7(pc),fp2	* A7

	fmul.x	fp0,fp1	* SB8
	fmove.x	fp0,SPRIME(a6)
	fmul.x	fp0,fp2	* SA7

	ror.l	#1,d1
	and.l	#$80000000,d1

	fadd.d	COSB7(pc),fp1	* B7+SB8
	fadd.d	SINA6(pc),fp2	* A6+SA7

	eor.l	d1,RPRIME(a6)
	eor.l	d1,SPRIME(a6)

	fmul.x	fp0,fp1	* S(B7+SB8)

	or.l	#$3F800000,d1
	move.l	d1,POSNEG1(a6)

	fmul.x	fp0,fp2	* S(A6+SA7)

	fadd.d	COSB6(pc),fp1	* B6+S(B7+SB8)
	fadd.d	SINA5(pc),fp2	* A5+S(A6+SA7)

	fmul.x	fp0,fp1	* S(B6+S(B7+SB8))
	fmul.x	fp0,fp2	* S(A5+S(A6+SA7))

	fadd.d	COSB5(pc),fp1	* B5+S(B6+S(B7+SB8))
	fadd.d	SINA4(pc),fp2	* A4+S(A5+S(A6+SA7))

	fmul.x	fp0,fp1	* S(B5+...)
	fmul.x	fp0,fp2	* S(A4+...)

	fadd.d	COSB4(pc),fp1	* B4+S(B5+...)
	fadd.d	SINA3(pc),fp2	* A3+S(A4+...)

	fmul.x	fp0,fp1	* S(B4+...)
	fmul.x	fp0,fp2	* S(A3+...)

	fadd.x	COSB3(pc),fp1	* B3+S(B4+...)
	fadd.x	SINA2(pc),fp2	* A2+S(A3+...)

	fmul.x	fp0,fp1	* S(B3+...)
	fmul.x	fp0,fp2	* S(A2+...)

	fadd.x	COSB2(pc),fp1	* B2+S(B3+...)
	fadd.x	SINA1(pc),fp2	* A1+S(A2+...)

	fmul.x	fp0,fp1	* S(B2+...)
	fmul.x	fp2,fp0	* s(a1+...)


	fadd.s	COSB1(pc),fp1	* B1+S(B2...)
	fmul.x	RPRIME(a6),fp0	* R'S(A1+...)
	fmul.x	SPRIME(a6),fp1	* S'(B1+S(B2+...))

	fmovem.x	(sp)+,fp2	* restore fp2

	fmove.l	d0,fpcr
	fadd.s	POSNEG1(a6),fp1	* COS(X)
	bsr	sto_cos	* store cosine result
	fadd.x	RPRIME(a6),fp0	* SIN(X)
	bra	t_inx2

************************************************

SCBORS:
	ICMP.l	d1,#$3FFF8000
	bgt.w	SREDUCEX

************************************************

SCSM:
*	move.w	#$0000,XDCARE(a6)
	fmove.s	#$3F800000,fp1

	fmove.l	d0,fpcr
	fsub.s	#$00800000,fp1
	bsr	sto_cos	* store cosine result
	fmove.l	fpcr,d0	* d0 must have fpcr,too
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	X(a6),fp0
	bra	t_catch

**********************************************

	xdef	ssincosd
*--SIN AND COS OF X FOR DENORMALIZED X
ssincosd:
	move.l	d0,-(sp)	* save d0
	fmove.s	#$3F800000,fp1
	bsr	sto_cos	* store cosine result
	move.l	(sp)+,d0	* restore d0
	bra	t_extdnrm

********************************************

*--WHEN REDUCEX IS USED, THE CODE WILL INEVITABLY BE SLOW.
*--THIS REDUCTION METHOD, HOWEVER, IS MUCH FASTER THAN USING
*--THE REMAINDER INSTRUCTION WHICH IS NOW IN SOFTWARE.
SREDUCEX:
	fmovem.x	fp2-fp5,-(sp)	* save {fp2-fp5}
	move.l	d2,-(sp)	* save d2
	fmove.s	#$00000000,fp1	* fp1 = 0

*--If compact form of abs(arg) in d0=$7ffeffff, argument is so large that
*--there is a danger of unwanted overflow in first LOOP iteration.  In this
*--case, reduce argument by one remainder step to make subsequent reduction
*--safe.
	ICMP.l	d1,#$7ffeffff	* is arg dangerously large?
	bne.b	SLOOP	* no

* yes; create 2**16383*PI/2
	move.w	#$7ffe,EXC_LV+FP_SCR0_EX(a6)
	move.l	#$c90fdaa2,EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)

* create low half of 2**16383*PI/2 at EXC_LV+FP_SCR1
	move.w	#$7fdc,EXC_LV+FP_SCR1_EX(a6)
	move.l	#$85a308d3,EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)

	ftst.x	fp0	* test sign of argument
	fblt.w	sred_neg

	or.b	#$80,EXC_LV+FP_SCR0_EX(a6)	* positive arg
	or.b	#$80,EXC_LV+FP_SCR1_EX(a6)
sred_neg:
	fadd.x	EXC_LV+FP_SCR0(a6),fp0	* high part of reduction is exact
	fmove.x	fp0,fp1	* save high result in fp1
	fadd.x	EXC_LV+FP_SCR1(a6),fp0	* low part of reduction
	fsub.x	fp0,fp1	* determine low component of result
	fadd.x	EXC_LV+FP_SCR1(a6),fp1	* fp0/fp1 are reduced argument.

*--ON ENTRY, FP0 IS X, ON RETURN, FP0 IS X REM PI/2, |X| <= PI/4.
*--integer quotient will be stored in N
*--Intermeditate remainder is 66-bit dc.l; (R,r) in (FP0,FP1)
SLOOP:
	fmove.x	fp0,INARG(a6)	* +-2**K * F, 1 <= F < 2
	move.w	INARG(a6),d1
	move.l	d1,a1	* save a copy of D0
	and.l	#$00007FFF,d1
	sub.l	#$00003FFF,d1	* d0 = K
	ICMP.l	d1,#28
	ble.b	SLASTLOOP
SCONTLOOP:
	sub.l	#27,d1	* d0 = L := K-27
	move.b	#0,ENDFLAG(a6)
	bra.b	SWORK
SLASTLOOP:
	clr.l	d1	* d0 = L := 0
	move.b	#1,ENDFLAG(a6)

SWORK:
*--FIND THE REMAINDER OF (R,r) W.R.T.	2**L * (PI/2). L IS SO CHOSEN
*--THAT	INT( X * (2/PI) / 2**(L) ) < 2**29.

*--CREATE 2**(-L) * (2/PI), SIGN(INARG)*2**(63),
*--2**L * (PIby2_1), 2**L * (PIby2_2)

	move.l	#$00003FFE,d2	* BIASED EXP OF 2/PI
	sub.l	d1,d2	* BIASED EXP OF 2**(-L)*(2/PI)

	move.l	#$A2F9836E,EXC_LV+FP_SCR0_HI(a6)
	move.l	#$4E44152A,EXC_LV+FP_SCR0_LO(a6)
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* EXC_LV+FP_SCR0 = 2**(-L)*(2/PI)

	fmove.x	fp0,fp2
	fmul.x	EXC_LV+FP_SCR0(a6),fp2	* fp2 = X * 2**(-L)*(2/PI)

*--WE MUST NOW FIND INT(FP2). SINCE WE NEED THIS VALUE IN
*--FLOATING POINT FORMAT, THE TWO FMOVE'S	FMOVE.L FP <--> N
*--WILL BE TOO INEFFICIENT. THE WAY AROUND IT IS THAT
*--(SIGN(INARG)*2**63	+	FP2) - SIGN(INARG)*2**63 WILL GIVE
*--US THE DESIRED VALUE IN FLOATING POINT.
	move.l	a1,d2
	swap	d2
	and.l	#$80000000,d2
	or.l	#$5F000000,d2	* d2 = SIGN(INARG)*2**63 IN SGL
	move.l	d2,TWOTO63(a6)
	fadd.s	TWOTO63(a6),fp2	* THE FRACTIONAL PART OF FP1 IS ROUNDED
	fsub.s	TWOTO63(a6),fp2	* fp2 = N
*	fint.x	fp2

*--CREATING 2**(L)*Piby2_1 and 2**(L)*Piby2_2
	move.l	d1,d2	* d2 = L

	add.l	#$00003FFF,d2	* BIASED EXP OF 2**L * (PI/2)
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)
	move.l	#$C90FDAA2,EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)	* EXC_LV+FP_SCR0 = 2**(L) * Piby2_1

	add.l	#$00003FDD,d1
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)
	move.l	#$85A308D3,EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)	* EXC_LV+FP_SCR1 = 2**(L) * Piby2_2

	move.b	ENDFLAG(a6),d1

*--We are now ready to perform (R+r) - N*P1 - N*P2, P1 = 2**(L) * Piby2_1 and
*--P2 = 2**(L) * Piby2_2
	fmove.x	fp2,fp4	* fp4 = N
	fmul.x	EXC_LV+FP_SCR0(a6),fp4	* fp4 = W = N*P1
	fmove.x	fp2,fp5	* fp5 = N
	fmul.x	EXC_LV+FP_SCR1(a6),fp5	* fp5 = w = N*P2
	fmove.x	fp4,fp3	* fp3 = W = N*P1

*--we want P+p = W+w  but  |p| <= half ulp of P
*--Then, we need to compute  A := R-P   and  a := r-p
	fadd.x	fp5,fp3	* fp3 = P
	fsub.x	fp3,fp4	* fp4 = W-P

	fsub.x	fp3,fp0	* fp0 = A := R - P
	fadd.x	fp5,fp4	* fp4 = p = (W-P)+w

	fmove.x	fp0,fp3	* fp3 = A
	fsub.x	fp4,fp1	* fp1 = a := r - p

*--Now we need to normalize (A,a) to  "new (R,r)" where R+r = A+a but
*--|r| <= half ulp of R.
	fadd.x	fp1,fp0	* fp0 = R := A+a
*--No need to calculate r if this is the last loop
	ICMP.b	d1,#0
	bgt.w	SRESTORE

*--Need to calculate r
	fsub.x	fp0,fp3	* fp3 = A-R
	fadd.x	fp3,fp1	* fp1 = r := (A-R)+a
	bra.w	SLOOP

SRESTORE:
	fmove.l	fp2,INT(a6)
	move.l	(sp)+,d2	* restore d2
	fmovem.x	(sp)+,fp2-fp5	* restore {fp2-fp5}

	move.l	ADJN(a6),d1
	ICMP.l	d1,#4

	blt.w	SINCONT
	bra.w	SCCONT

**-------------------------------------------------------------------------------------------------
* stan():  computes the tangent of a normalized input
* stand(): computes the tangent of a denormalized input
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = tan(X)	
*		
* ACCURACY and MONOTONICITY ******************************************* *
*	The returned result is within 3 ulp in 64 significant bit, i.e. *
*	within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM *********************************************************** *
*		
*	1. If |X| >= 15Pi or |X| < 2**(-40), go to 6.
*		
*	2. Decompose X as X = N(Pi/2) + r where |r| <= Pi/4. Let
*	k = N mod 2, so in particular, k = 0 or 1.
*		
*	3. If k is odd, go to 5.	
*		
*	4. (k is even) Tan(X) = tan(r) and tan(r) is approximated by a
*	rational function U/V where
*	U = r + r*s*(P1 + s*(P2 + s*P3)), and
*	V = 1 + s*(Q1 + s*(Q2 + s*(Q3 + s*Q4))),  s = r*r.
*	Exit.	
*		
*	4. (k is odd) Tan(X) = -cot(r). Since tan(r) is approximated by *
*	a rational function U/V where
*	U = r + r*s*(P1 + s*(P2 + s*P3)), and
*	V = 1 + s*(Q1 + s*(Q2 + s*(Q3 + s*Q4))), s = r*r,
*	-Cot(r) = -V/U. Exit.	
*		
*	6. If |X| > 1, go to 8.	
*		
*	7. (|X|<2**(-40)) Tan(X) = X. Exit.
*		
*	8. Overwrite X by X := X rem 2Pi. Now that |X| <= Pi, go back 
*	to 2.	
*		
**-------------------------------------------------------------------------------------------------

TANQ4:
	dc.l	$3EA0B759,$F50F8688
TANP3:
	dc.l	$BEF2BAA5,$A8924F04

TANQ3:
	dc.l	$BF346F59,$B39BA65F,$00000000,$00000000

TANP2:
	dc.l	$3FF60000,$E073D3FC,$199C4A00,$00000000

TANQ2:
	dc.l	$3FF90000,$D23CD684,$15D95FA1,$00000000

TANP1:
	dc.l	$BFFC0000,$8895A6C5,$FB423BCA,$00000000

TANQ1:
	dc.l	$BFFD0000,$EEF57E0D,$A84BC8CE,$00000000

INVTWOPI:
	dc.l	$3FFC0000,$A2F9836E,$4E44152A,$00000000

TWOPI1:
	dc.l	$40010000,$C90FDAA2,$00000000,$00000000
TWOPI2:
	dc.l	$3FDF0000,$85A308D4,$00000000,$00000000

*--N*PI/2, -32 <= N <= 32, IN A LEADING TERM IN EXT. AND TRAILING
*--TERM IN SGL. NOTE THAT PI IS 64-BIT LONG, THUS N*PI/2 IS AT
*--MOST 69 BITS LONG.
*	xdef	PITBL
PITBL:
	dc.l	$C0040000,$C90FDAA2,$2168C235,$21800000
	dc.l	$C0040000,$C2C75BCD,$105D7C23,$A0D00000
	dc.l	$C0040000,$BC7EDCF7,$FF523611,$A1E80000
	dc.l	$C0040000,$B6365E22,$EE46F000,$21480000
	dc.l	$C0040000,$AFEDDF4D,$DD3BA9EE,$A1200000
	dc.l	$C0040000,$A9A56078,$CC3063DD,$21FC0000
	dc.l	$C0040000,$A35CE1A3,$BB251DCB,$21100000
	dc.l	$C0040000,$9D1462CE,$AA19D7B9,$A1580000
	dc.l	$C0040000,$96CBE3F9,$990E91A8,$21E00000
	dc.l	$C0040000,$90836524,$88034B96,$20B00000
	dc.l	$C0040000,$8A3AE64F,$76F80584,$A1880000
	dc.l	$C0040000,$83F2677A,$65ECBF73,$21C40000
	dc.l	$C0030000,$FB53D14A,$A9C2F2C2,$20000000
	dc.l	$C0030000,$EEC2D3A0,$87AC669F,$21380000
	dc.l	$C0030000,$E231D5F6,$6595DA7B,$A1300000
	dc.l	$C0030000,$D5A0D84C,$437F4E58,$9FC00000
	dc.l	$C0030000,$C90FDAA2,$2168C235,$21000000
	dc.l	$C0030000,$BC7EDCF7,$FF523611,$A1680000
	dc.l	$C0030000,$AFEDDF4D,$DD3BA9EE,$A0A00000
	dc.l	$C0030000,$A35CE1A3,$BB251DCB,$20900000
	dc.l	$C0030000,$96CBE3F9,$990E91A8,$21600000
	dc.l	$C0030000,$8A3AE64F,$76F80584,$A1080000
	dc.l	$C0020000,$FB53D14A,$A9C2F2C2,$1F800000
	dc.l	$C0020000,$E231D5F6,$6595DA7B,$A0B00000
	dc.l	$C0020000,$C90FDAA2,$2168C235,$20800000
	dc.l	$C0020000,$AFEDDF4D,$DD3BA9EE,$A0200000
	dc.l	$C0020000,$96CBE3F9,$990E91A8,$20E00000
	dc.l	$C0010000,$FB53D14A,$A9C2F2C2,$1F000000
	dc.l	$C0010000,$C90FDAA2,$2168C235,$20000000
	dc.l	$C0010000,$96CBE3F9,$990E91A8,$20600000
	dc.l	$C0000000,$C90FDAA2,$2168C235,$1F800000
	dc.l	$BFFF0000,$C90FDAA2,$2168C235,$1F000000
	dc.l	$00000000,$00000000,$00000000,$00000000
	dc.l	$3FFF0000,$C90FDAA2,$2168C235,$9F000000
	dc.l	$40000000,$C90FDAA2,$2168C235,$9F800000
	dc.l	$40010000,$96CBE3F9,$990E91A8,$A0600000
	dc.l	$40010000,$C90FDAA2,$2168C235,$A0000000
	dc.l	$40010000,$FB53D14A,$A9C2F2C2,$9F000000
	dc.l	$40020000,$96CBE3F9,$990E91A8,$A0E00000
	dc.l	$40020000,$AFEDDF4D,$DD3BA9EE,$20200000
	dc.l	$40020000,$C90FDAA2,$2168C235,$A0800000
	dc.l	$40020000,$E231D5F6,$6595DA7B,$20B00000
	dc.l	$40020000,$FB53D14A,$A9C2F2C2,$9F800000
	dc.l	$40030000,$8A3AE64F,$76F80584,$21080000
	dc.l	$40030000,$96CBE3F9,$990E91A8,$A1600000
	dc.l	$40030000,$A35CE1A3,$BB251DCB,$A0900000
	dc.l	$40030000,$AFEDDF4D,$DD3BA9EE,$20A00000
	dc.l	$40030000,$BC7EDCF7,$FF523611,$21680000
	dc.l	$40030000,$C90FDAA2,$2168C235,$A1000000
	dc.l	$40030000,$D5A0D84C,$437F4E58,$1FC00000
	dc.l	$40030000,$E231D5F6,$6595DA7B,$21300000
	dc.l	$40030000,$EEC2D3A0,$87AC669F,$A1380000
	dc.l	$40030000,$FB53D14A,$A9C2F2C2,$A0000000
	dc.l	$40040000,$83F2677A,$65ECBF73,$A1C40000
	dc.l	$40040000,$8A3AE64F,$76F80584,$21880000
	dc.l	$40040000,$90836524,$88034B96,$A0B00000
	dc.l	$40040000,$96CBE3F9,$990E91A8,$A1E00000
	dc.l	$40040000,$9D1462CE,$AA19D7B9,$21580000
	dc.l	$40040000,$A35CE1A3,$BB251DCB,$A1100000
	dc.l	$40040000,$A9A56078,$CC3063DD,$A1FC0000
	dc.l	$40040000,$AFEDDF4D,$DD3BA9EE,$21200000
	dc.l	$40040000,$B6365E22,$EE46F000,$A1480000
	dc.l	$40040000,$BC7EDCF7,$FF523611,$21E80000
	dc.l	$40040000,$C2C75BCD,$105D7C23,$20D00000
	dc.l	$40040000,$C90FDAA2,$2168C235,$A1800000

*INT	equ	EXC_LV+L_SCR1
*ENDFLAG	equ	EXC_LV+L_SCR2

	xdef	stan
stan:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1

	ICMP.l	d1,#$3FD78000	* |X| >= 2**(-40)?
	bge.b	TANOK1
	bra.w	TANSM
TANOK1:
	ICMP.l	d1,#$4004BC7E	* |X| < 15 PI?
	blt.b	TANMAIN
	bra.w	REDUCEX

TANMAIN:
*--THIS IS THE USUAL CASE, |X| <= 15 PI.
*--THE ARGUMENT REDUCTION IS DONE BY TABLE LOOK UP.
	fmove.x	fp0,fp1
	fmul.d	TWOBYPI(pc),fp1	* X*2/PI

	lea.l	PITBL+$200(pc),a1	* TABLE OF N*PI/2, N = -32,...,32

	fmove.l	fp1,d1	* CONVERT TO INTEGER

	asl.l	#4,d1
	add.l	d1,a1	* ADDRESS N*PIBY2 IN Y1, Y2

	fsub.x	(a1)+,fp0	* X-Y1

	fsub.s	(a1),fp0	* FP0 IS R = (X-Y1)-Y2

	ror.l	#5,d1
	and.l	#$80000000,d1	* D0 WAS ODD IFF D0 < 0

TANCONT:
	fmovem.x	fp2-fp3,-(sp)	* save fp2,fp3

	ICMP.l	d1,#0
	blt.w	NODD

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* S = R*R

	fmove.d	TANQ4(pc),fp3
	fmove.d	TANP3(pc),fp2

	fmul.x	fp1,fp3	* SQ4
	fmul.x	fp1,fp2	* SP3

	fadd.d	TANQ3(pc),fp3	* Q3+SQ4
	fadd.x	TANP2(pc),fp2	* P2+SP3

	fmul.x	fp1,fp3	* S(Q3+SQ4)
	fmul.x	fp1,fp2	* S(P2+SP3)

	fadd.x	TANQ2(pc),fp3	* Q2+S(Q3+SQ4)
	fadd.x	TANP1(pc),fp2	* P1+S(P2+SP3)

	fmul.x	fp1,fp3	* S(Q2+S(Q3+SQ4))
	fmul.x	fp1,fp2	* S(P1+S(P2+SP3))

	fadd.x	TANQ1(pc),fp3	* Q1+S(Q2+S(Q3+SQ4))
	fmul.x	fp0,fp2	* RS(P1+S(P2+SP3))

	fmul.x	fp3,fp1	* S(Q1+S(Q2+S(Q3+SQ4)))

	fadd.x	fp2,fp0	* R+RS(P1+S(P2+SP3))

	fadd.s	#$3F800000,fp1	* 1+S(Q1+...)

	fmovem.x	(sp)+,fp2-fp3	* restore fp2,fp3

	fmove.l	d0,fpcr	* restore users round mode,prec
	fdiv.x	fp1,fp0	* last inst - possible exception set
	bra	t_inx2

NODD:
	fmove.x	fp0,fp1
	fmul.x	fp0,fp0	* S = R*R

	fmove.d	TANQ4(pc),fp3
	fmove.d	TANP3(pc),fp2

	fmul.x	fp0,fp3	* SQ4
	fmul.x	fp0,fp2	* SP3

	fadd.d	TANQ3(pc),fp3	* Q3+SQ4
	fadd.x	TANP2(pc),fp2	* P2+SP3

	fmul.x	fp0,fp3	* S(Q3+SQ4)
	fmul.x	fp0,fp2	* S(P2+SP3)

	fadd.x	TANQ2(pc),fp3	* Q2+S(Q3+SQ4)
	fadd.x	TANP1(pc),fp2	* P1+S(P2+SP3)

	fmul.x	fp0,fp3	* S(Q2+S(Q3+SQ4))
	fmul.x	fp0,fp2	* S(P1+S(P2+SP3))

	fadd.x	TANQ1(pc),fp3	* Q1+S(Q2+S(Q3+SQ4))
	fmul.x	fp1,fp2	* RS(P1+S(P2+SP3))

	fmul.x	fp3,fp0	* S(Q1+S(Q2+S(Q3+SQ4)))

	fadd.x	fp2,fp1	* R+RS(P1+S(P2+SP3))
	fadd.s	#$3F800000,fp0	* 1+S(Q1+...)

	fmovem.x	(sp)+,fp2-fp3	* restore fp2,fp3

	fmove.x	fp1,-(sp)
	eor.l	#$80000000,(sp)

	fmove.l	d0,fpcr	* restore users round mode,prec
	fdiv.x	(sp)+,fp0	* last inst - possible exception set
	bra	t_inx2

TANBORS:
*--IF |X| > 15PI, WE USE THE GENERAL ARGUMENT REDUCTION.
*--IF |X| < 2**(-40), RETURN X OR 1.
	ICMP.l	d1,#$3FFF8000
	bgt.b	REDUCEX

TANSM:
	fmove.x	fp0,-(sp)
	fmove.l	d0,fpcr	* restore users round mode,prec
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	(sp)+,fp0	* last inst - posibble exception set
	bra	t_catch

	xdef	stand
*--TAN(X) = X FOR DENORMALIZED X
stand:
	bra	t_extdnrm

*--WHEN REDUCEX IS USED, THE CODE WILL INEVITABLY BE SLOW.
*--THIS REDUCTION METHOD, HOWEVER, IS MUCH FASTER THAN USING
*--THE REMAINDER INSTRUCTION WHICH IS NOW IN SOFTWARE.
REDUCEX:
	fmovem.x	fp2-fp5,-(sp)	* save {fp2-fp5}
	move.l	d2,-(sp)	* save d2
	fmove.s	#$00000000,fp1	* fp1 = 0

*--If compact form of abs(arg) in d0=$7ffeffff, argument is so large that
*--there is a danger of unwanted overflow in first LOOP iteration.  In this
*--case, reduce argument by one remainder step to make subsequent reduction
*--safe.
	ICMP.l	d1,#$7ffeffff	* is arg dangerously large?
	bne.b	LOOP	* no

* yes; create 2**16383*PI/2
	move.w	#$7ffe,EXC_LV+FP_SCR0_EX(a6)
	move.l	#$c90fdaa2,EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)

* create low half of 2**16383*PI/2 at EXC_LV+FP_SCR1
	move.w	#$7fdc,EXC_LV+FP_SCR1_EX(a6)
	move.l	#$85a308d3,EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)

	ftst.x	fp0	* test sign of argument
	fblt.w	red_neg

	or.b	#$80,EXC_LV+FP_SCR0_EX(a6)	* positive arg
	or.b	#$80,EXC_LV+FP_SCR1_EX(a6)
red_neg:
	fadd.x	EXC_LV+FP_SCR0(a6),fp0	* high part of reduction is exact
	fmove.x	fp0,fp1	* save high result in fp1
	fadd.x	EXC_LV+FP_SCR1(a6),fp0	* low part of reduction
	fsub.x	fp0,fp1	* determine low component of result
	fadd.x	EXC_LV+FP_SCR1(a6),fp1	* fp0/fp1 are reduced argument.

*--ON ENTRY, FP0 IS X, ON RETURN, FP0 IS X REM PI/2, |X| <= PI/4.
*--integer quotient will be stored in N
*--Intermeditate remainder is 66-bit dc.l; (R,r) in (FP0,FP1)
LOOP:
	fmove.x	fp0,INARG(a6)	* +-2**K * F, 1 <= F < 2
	move.w	INARG(a6),d1
	move.l	d1,a1	* save a copy of D0
	and.l	#$00007FFF,d1
	sub.l	#$00003FFF,d1	* d0 = K
	ICMP.l	d1,#28
	ble.b	LASTLOOP
CONTLOOP:
	sub.l	#27,d1	* d0 = L := K-27
	move.b	#0,ENDFLAG(a6)
	bra.b	WORK
LASTLOOP:
	clr.l	d1	* d0 = L := 0
	move.b	#1,ENDFLAG(a6)

WORK:
*--FIND THE REMAINDER OF (R,r) W.R.T.	2**L * (PI/2). L IS SO CHOSEN
*--THAT	INT( X * (2/PI) / 2**(L) ) < 2**29.

*--CREATE 2**(-L) * (2/PI), SIGN(INARG)*2**(63),
*--2**L * (PIby2_1), 2**L * (PIby2_2)

	move.l	#$00003FFE,d2	* BIASED EXP OF 2/PI
	sub.l	d1,d2	* BIASED EXP OF 2**(-L)*(2/PI)

	move.l	#$A2F9836E,EXC_LV+FP_SCR0_HI(a6)
	move.l	#$4E44152A,EXC_LV+FP_SCR0_LO(a6)
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* EXC_LV+FP_SCR0 = 2**(-L)*(2/PI)

	fmove.x	fp0,fp2
	fmul.x	EXC_LV+FP_SCR0(a6),fp2	* fp2 = X * 2**(-L)*(2/PI)

*--WE MUST NOW FIND INT(FP2). SINCE WE NEED THIS VALUE IN
*--FLOATING POINT FORMAT, THE TWO FMOVE'S	FMOVE.L FP <--> N
*--WILL BE TOO INEFFICIENT. THE WAY AROUND IT IS THAT
*--(SIGN(INARG)*2**63	+	FP2) - SIGN(INARG)*2**63 WILL GIVE
*--US THE DESIRED VALUE IN FLOATING POINT.
	move.l	a1,d2
	swap	d2
	and.l	#$80000000,d2
	or.l	#$5F000000,d2	* d2 = SIGN(INARG)*2**63 IN SGL
	move.l	d2,TWOTO63(a6)
	fadd.s	TWOTO63(a6),fp2	* THE FRACTIONAL PART OF FP1 IS ROUNDED
	fsub.s	TWOTO63(a6),fp2	* fp2 = N
*	fintrz.x	fp2,fp2

*--CREATING 2**(L)*Piby2_1 and 2**(L)*Piby2_2
	move.l	d1,d2	* d2 = L

	add.l	#$00003FFF,d2	* BIASED EXP OF 2**L * (PI/2)
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)
	move.l	#$C90FDAA2,EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)	* EXC_LV+FP_SCR0 = 2**(L) * Piby2_1

	add.l	#$00003FDD,d1
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)
	move.l	#$85A308D3,EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)	* EXC_LV+FP_SCR1 = 2**(L) * Piby2_2

	move.b	ENDFLAG(a6),d1

*--We are now ready to perform (R+r) - N*P1 - N*P2, P1 = 2**(L) * Piby2_1 and
*--P2 = 2**(L) * Piby2_2
	fmove.x	fp2,fp4	* fp4 = N
	fmul.x	EXC_LV+FP_SCR0(a6),fp4	* fp4 = W = N*P1
	fmove.x	fp2,fp5	* fp5 = N
	fmul.x	EXC_LV+FP_SCR1(a6),fp5	* fp5 = w = N*P2
	fmove.x	fp4,fp3	* fp3 = W = N*P1

*--we want P+p = W+w  but  |p| <= half ulp of P
*--Then, we need to compute  A := R-P   and  a := r-p
	fadd.x	fp5,fp3	* fp3 = P
	fsub.x	fp3,fp4	* fp4 = W-P

	fsub.x	fp3,fp0	* fp0 = A := R - P
	fadd.x	fp5,fp4	* fp4 = p = (W-P)+w

	fmove.x	fp0,fp3	* fp3 = A
	fsub.x	fp4,fp1	* fp1 = a := r - p

*--Now we need to normalize (A,a) to  "new (R,r)" where R+r = A+a but
*--|r| <= half ulp of R.
	fadd.x	fp1,fp0	* fp0 = R := A+a
*--No need to calculate r if this is the last loop
	ICMP.b	d1,#0
	bgt.w	RESTORE

*--Need to calculate r
	fsub.x	fp0,fp3	* fp3 = A-R
	fadd.x	fp3,fp1	* fp1 = r := (A-R)+a
	bra.w	LOOP

RESTORE:
	fmove.l	fp2,INT(a6)
	move.l	(sp)+,d2	* restore d2
	fmovem.x	(sp)+,fp2-fp5	* restore {fp2-fp5}

	move.l	INT(a6),d1
	ror.l	#1,d1

	bra.w	TANCONT






**-------------------------------------------------------------------------------------------------
* satan():  computes the arctangent of a normalized number
* satand(): computes the arctangent of a denormalized number
*		
* INPUT	*************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = arctan(X)	
*		
* ACCURACY and MONOTONICITY ******************************************* *
*	The returned result is within 2 ulps in	64 significant bit,
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision. 	
*		
* ALGORITHM *********************************************************** *
*	Step 1. If |X| >= 16 or |X| < 1/16, go to Step 5.
*		
*	Step 2. Let X = sgn * 2**k * 1.xxxxxxxx...x. 
*	Note that k = -4, -3,..., or 3.
*	Define F = sgn * 2**k * 1.xxxx1, i.e. the first 5 
*	significant bits of X with a bit-1 attached at the 6-th
*	bit position. Define u to be u = (X-F) / (1 + X*F).
*		
*	Step 3. Approximate arctan(u) by a polynomial poly.
*		
*	Step 4. Return arctan(F) + poly, arctan(F) is fetched from a 
*	table of values calculated beforehand. Exit.
*		
*	Step 5. If |X| >= 16, go to Step 7.
*		
*	Step 6. Approximate arctan(X) by an odd polynomial in X. Exit.
*		
*	Step 7. Define X' = -1/X. Approximate arctan(X') by an odd 
*	polynomial in X'.	
*	Arctan(X) = sign(X)*Pi/2 + arctan(X'). Exit.
*		
**-------------------------------------------------------------------------------------------------

ATANA3:	dc.l	$BFF6687E,$314987D8
ATANA2:	dc.l	$4002AC69,$34A26DB3
ATANA1:	dc.l	$BFC2476F,$4E1DA28E

ATANB6:	dc.l	$3FB34444,$7F876989
ATANB5:	dc.l	$BFB744EE,$7FAF45DB
ATANB4:	dc.l	$3FBC71C6,$46940220
ATANB3:	dc.l	$BFC24924,$921872F9
ATANB2:	dc.l	$3FC99999,$99998FA9
ATANB1:	dc.l	$BFD55555,$55555555

ATANC5:	dc.l	$BFB70BF3,$98539E6A
ATANC4:	dc.l	$3FBC7187,$962D1D7D
ATANC3:	dc.l	$BFC24924,$827107B8
ATANC2:	dc.l	$3FC99999,$9996263E
ATANC1:	dc.l	$BFD55555,$55555536

PPIBY2:	dc.l	$3FFF0000,$C90FDAA2,$2168C235,$00000000
NPIBY2:	dc.l	$BFFF0000,$C90FDAA2,$2168C235,$00000000

PTINY:	dc.l	$00010000,$80000000,$00000000,$00000000
NTINY:	dc.l	$80010000,$80000000,$00000000,$00000000

ATANTBL:
	dc.l	$3FFB0000,$83D152C5,$060B7A51,$00000000
	dc.l	$3FFB0000,$8BC85445,$65498B8B,$00000000
	dc.l	$3FFB0000,$93BE4060,$17626B0D,$00000000
	dc.l	$3FFB0000,$9BB3078D,$35AEC202,$00000000
	dc.l	$3FFB0000,$A3A69A52,$5DDCE7DE,$00000000
	dc.l	$3FFB0000,$AB98E943,$62765619,$00000000
	dc.l	$3FFB0000,$B389E502,$F9C59862,$00000000
	dc.l	$3FFB0000,$BB797E43,$6B09E6FB,$00000000
	dc.l	$3FFB0000,$C367A5C7,$39E5F446,$00000000
	dc.l	$3FFB0000,$CB544C61,$CFF7D5C6,$00000000
	dc.l	$3FFB0000,$D33F62F8,$2488533E,$00000000
	dc.l	$3FFB0000,$DB28DA81,$62404C77,$00000000
	dc.l	$3FFB0000,$E310A407,$8AD34F18,$00000000
	dc.l	$3FFB0000,$EAF6B0A8,$188EE1EB,$00000000
	dc.l	$3FFB0000,$F2DAF194,$9DBE79D5,$00000000
	dc.l	$3FFB0000,$FABD5813,$61D47E3E,$00000000
	dc.l	$3FFC0000,$8346AC21,$0959ECC4,$00000000
	dc.l	$3FFC0000,$8B232A08,$304282D8,$00000000
	dc.l	$3FFC0000,$92FB70B8,$D29AE2F9,$00000000
	dc.l	$3FFC0000,$9ACF476F,$5CCD1CB4,$00000000
	dc.l	$3FFC0000,$A29E7630,$4954F23F,$00000000
	dc.l	$3FFC0000,$AA68C5D0,$8AB85230,$00000000
	dc.l	$3FFC0000,$B22DFFFD,$9D539F83,$00000000
	dc.l	$3FFC0000,$B9EDEF45,$3E900EA5,$00000000
	dc.l	$3FFC0000,$C1A85F1C,$C75E3EA5,$00000000
	dc.l	$3FFC0000,$C95D1BE8,$28138DE6,$00000000
	dc.l	$3FFC0000,$D10BF300,$840D2DE4,$00000000
	dc.l	$3FFC0000,$D8B4B2BA,$6BC05E7A,$00000000
	dc.l	$3FFC0000,$E0572A6B,$B42335F6,$00000000
	dc.l	$3FFC0000,$E7F32A70,$EA9CAA8F,$00000000
	dc.l	$3FFC0000,$EF888432,$64ECEFAA,$00000000
	dc.l	$3FFC0000,$F7170A28,$ECC06666,$00000000
	dc.l	$3FFD0000,$812FD288,$332DAD32,$00000000
	dc.l	$3FFD0000,$88A8D1B1,$218E4D64,$00000000
	dc.l	$3FFD0000,$9012AB3F,$23E4AEE8,$00000000
	dc.l	$3FFD0000,$976CC3D4,$11E7F1B9,$00000000
	dc.l	$3FFD0000,$9EB68949,$3889A227,$00000000
	dc.l	$3FFD0000,$A5EF72C3,$4487361B,$00000000
	dc.l	$3FFD0000,$AD1700BA,$F07A7227,$00000000
	dc.l	$3FFD0000,$B42CBCFA,$FD37EFB7,$00000000
	dc.l	$3FFD0000,$BB303A94,$0BA80F89,$00000000
	dc.l	$3FFD0000,$C22115C6,$FCAEBBAF,$00000000
	dc.l	$3FFD0000,$C8FEF3E6,$86331221,$00000000
	dc.l	$3FFD0000,$CFC98330,$B4000C70,$00000000
	dc.l	$3FFD0000,$D6807AA1,$102C5BF9,$00000000
	dc.l	$3FFD0000,$DD2399BC,$31252AA3,$00000000
	dc.l	$3FFD0000,$E3B2A855,$6B8FC517,$00000000
	dc.l	$3FFD0000,$EA2D764F,$64315989,$00000000
	dc.l	$3FFD0000,$F3BF5BF8,$BAD1A21D,$00000000
	dc.l	$3FFE0000,$801CE39E,$0D205C9A,$00000000
	dc.l	$3FFE0000,$8630A2DA,$DA1ED066,$00000000
	dc.l	$3FFE0000,$8C1AD445,$F3E09B8C,$00000000
	dc.l	$3FFE0000,$91DB8F16,$64F350E2,$00000000
	dc.l	$3FFE0000,$97731420,$365E538C,$00000000
	dc.l	$3FFE0000,$9CE1C8E6,$A0B8CDBA,$00000000
	dc.l	$3FFE0000,$A22832DB,$CADAAE09,$00000000
	dc.l	$3FFE0000,$A746F2DD,$B7602294,$00000000
	dc.l	$3FFE0000,$AC3EC0FB,$997DD6A2,$00000000
	dc.l	$3FFE0000,$B110688A,$EBDC6F6A,$00000000
	dc.l	$3FFE0000,$B5BCC490,$59ECC4B0,$00000000
	dc.l	$3FFE0000,$BA44BC7D,$D470782F,$00000000
	dc.l	$3FFE0000,$BEA94144,$FD049AAC,$00000000
	dc.l	$3FFE0000,$C2EB4ABB,$661628B6,$00000000
	dc.l	$3FFE0000,$C70BD54C,$E602EE14,$00000000
	dc.l	$3FFE0000,$CD000549,$ADEC7159,$00000000
	dc.l	$3FFE0000,$D48457D2,$D8EA4EA3,$00000000
	dc.l	$3FFE0000,$DB948DA7,$12DECE3B,$00000000
	dc.l	$3FFE0000,$E23855F9,$69E8096A,$00000000
	dc.l	$3FFE0000,$E8771129,$C4353259,$00000000
	dc.l	$3FFE0000,$EE57C16E,$0D379C0D,$00000000
	dc.l	$3FFE0000,$F3E10211,$A87C3779,$00000000
	dc.l	$3FFE0000,$F919039D,$758B8D41,$00000000
	dc.l	$3FFE0000,$FE058B8F,$64935FB3,$00000000
	dc.l	$3FFF0000,$8155FB49,$7B685D04,$00000000
	dc.l	$3FFF0000,$83889E35,$49D108E1,$00000000
	dc.l	$3FFF0000,$859CFA76,$511D724B,$00000000
	dc.l	$3FFF0000,$87952ECF,$FF8131E7,$00000000
	dc.l	$3FFF0000,$89732FD1,$9557641B,$00000000
	dc.l	$3FFF0000,$8B38CAD1,$01932A35,$00000000
	dc.l	$3FFF0000,$8CE7A8D8,$301EE6B5,$00000000
	dc.l	$3FFF0000,$8F46A39E,$2EAE5281,$00000000
	dc.l	$3FFF0000,$922DA7D7,$91888487,$00000000
	dc.l	$3FFF0000,$94D19FCB,$DEDF5241,$00000000
	dc.l	$3FFF0000,$973AB944,$19D2A08B,$00000000
	dc.l	$3FFF0000,$996FF00E,$08E10B96,$00000000
	dc.l	$3FFF0000,$9B773F95,$12321DA7,$00000000
	dc.l	$3FFF0000,$9D55CC32,$0F935624,$00000000
	dc.l	$3FFF0000,$9F100575,$006CC571,$00000000
	dc.l	$3FFF0000,$A0A9C290,$D97CC06C,$00000000
	dc.l	$3FFF0000,$A22659EB,$EBC0630A,$00000000
	dc.l	$3FFF0000,$A388B4AF,$F6EF0EC9,$00000000
	dc.l	$3FFF0000,$A4D35F10,$61D292C4,$00000000
	dc.l	$3FFF0000,$A60895DC,$FBE3187E,$00000000
	dc.l	$3FFF0000,$A72A51DC,$7367BEAC,$00000000
	dc.l	$3FFF0000,$A83A5153,$0956168F,$00000000
	dc.l	$3FFF0000,$A93A2007,$7539546E,$00000000
	dc.l	$3FFF0000,$AA9E7245,$023B2605,$00000000
	dc.l	$3FFF0000,$AC4C84BA,$6FE4D58F,$00000000
	dc.l	$3FFF0000,$ADCE4A4A,$606B9712,$00000000
	dc.l	$3FFF0000,$AF2A2DCD,$8D263C9C,$00000000
	dc.l	$3FFF0000,$B0656F81,$F22265C7,$00000000
	dc.l	$3FFF0000,$B1846515,$0F71496A,$00000000
	dc.l	$3FFF0000,$B28AAA15,$6F9ADA35,$00000000
	dc.l	$3FFF0000,$B37B44FF,$3766B895,$00000000
	dc.l	$3FFF0000,$B458C3DC,$E9630433,$00000000
	dc.l	$3FFF0000,$B525529D,$562246BD,$00000000
	dc.l	$3FFF0000,$B5E2CCA9,$5F9D88CC,$00000000
	dc.l	$3FFF0000,$B692CADA,$7ACA1ADA,$00000000
	dc.l	$3FFF0000,$B736AEA7,$A6925838,$00000000
	dc.l	$3FFF0000,$B7CFAB28,$7E9F7B36,$00000000
	dc.l	$3FFF0000,$B85ECC66,$CB219835,$00000000
	dc.l	$3FFF0000,$B8E4FD5A,$20A593DA,$00000000
	dc.l	$3FFF0000,$B99F41F6,$4AFF9BB5,$00000000
	dc.l	$3FFF0000,$BA7F1E17,$842BBE7B,$00000000
	dc.l	$3FFF0000,$BB471285,$7637E17D,$00000000
	dc.l	$3FFF0000,$BBFABE8A,$4788DF6F,$00000000
	dc.l	$3FFF0000,$BC9D0FAD,$2B689D79,$00000000
	dc.l	$3FFF0000,$BD306A39,$471ECD86,$00000000
	dc.l	$3FFF0000,$BDB6C731,$856AF18A,$00000000
	dc.l	$3FFF0000,$BE31CAC5,$02E80D70,$00000000
	dc.l	$3FFF0000,$BEA2D55C,$E33194E2,$00000000
	dc.l	$3FFF0000,$BF0B10B7,$C03128F0,$00000000
	dc.l	$3FFF0000,$BF6B7A18,$DACB778D,$00000000
	dc.l	$3FFF0000,$BFC4EA46,$63FA18F6,$00000000
	dc.l	$3FFF0000,$C0181BDE,$8B89A454,$00000000
	dc.l	$3FFF0000,$C065B066,$CFBF6439,$00000000
	dc.l	$3FFF0000,$C0AE345F,$56340AE6,$00000000
	dc.l	$3FFF0000,$C0F22291,$9CB9E6A7,$00000000

*X	equ	EXC_LV+FP_SCR0
XDCARE	equ	X+2
*XFRAC	equ	X+4
XFRACLO	equ	X+8

ATANF	equ	EXC_LV+FP_SCR1
ATANFHI	equ	ATANF+4
ATANFLO	equ	ATANF+8

	xdef	satan
*--ENTRY POINT FOR ATAN(X), HERE X IS FINITE, NON-ZERO, AND NOT NAN'S
satan:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	fmove.x	fp0,X(a6)
	and.l	#$7FFFFFFF,d1

	ICMP.l	d1,#$3FFB8000	* |X| >= 1/16?
	bge.b	ATANOK1
	bra.w	ATANSM

ATANOK1:
	ICMP.l	d1,#$4002FFFF	* |X| < 16 ?
	ble.b	ATANMAIN
	bra.w	ATANBIG

*--THE MOST LIKELY CASE, |X| IN [1/16, 16). WE USE TABLE TECHNIQUE
*--THE IDEA IS ATAN(X) = ATAN(F) + ATAN( [X-F] / [1+XF] ).
*--SO IF F IS CHOSEN TO BE CLOSE TO X AND ATAN(F) IS STORED IN
*--A TABLE, ALL WE NEED IS TO APPROXIMATE ATAN(U) WHERE
*--U = (X-F)/(1+XF) IS SMALL (REMEMBER F IS CLOSE TO X). IT IS
*--TRUE THAT A DIVIDE IS NOW NEEDED, BUT THE APPROXIMATION FOR
*--ATAN(U) IS A VERY dc.w POLYNOMIAL AND THE INDEXING TO
*--FETCH F AND SAVING OF REGISTERS CAN BE ALL HIDED UNDER THE
*--DIVIDE. IN THE END THIS METHOD IS MUCH FASTER THAN A TRADITIONAL
*--ONE. NOTE ALSO THAT THE TRADITIONAL SCHEME THAT APPROXIMATE
*--ATAN(X) DIRECTLY WILL NEED TO USE A RATIONAL APPROXIMATION
*--(DIVISION NEEDED) ANYWAY BECAUSE A POLYNOMIAL APPROXIMATION
*--WILL INVOLVE A VERY LONG POLYNOMIAL.

*--NOW WE SEE X AS +-2^K * 1.BBBBBBB....B <- 1. + 63 BITS
*--WE CHOSE F TO BE +-2^K * 1.BBBB1
*--THAT IS IT MATCHES THE EXPONENT AND FIRST 5 BITS OF X, THE
*--SIXTH BITS IS SET TO BE 1. SINCE K = -4, -3, ..., 3, THERE
*--ARE ONLY 8 TIMES 16 = 2^7 = 128 |F|'S. SINCE ATAN(-|F|) IS
*-- -ATAN(|F|), WE NEED TO STORE ONLY ATAN(|F|).

ATANMAIN:

	and.l	#$F8000000,XFRAC(a6)	* FIRST 5 BITS
	or.l	#$04000000,XFRAC(a6)	* SET 6-TH BIT TO 1
	move.l	#$00000000,XFRACLO(a6) * LOCATION OF X IS NOW F

	fmove.x	fp0,fp1	* FP1 IS X
	fmul.x	X(a6),fp1	* FP1 IS X*F, NOTE THAT X*F > 0
	fsub.x	X(a6),fp0	* FP0 IS X-F
	fadd.s	#$3F800000,fp1	* FP1 IS 1 + X*F
	fdiv.x	fp1,fp0	* FP0 IS U = (X-F)/(1+X*F)

*--WHILE THE DIVISION IS TAKING ITS TIME, WE FETCH ATAN(|F|)
*--CREATE ATAN(F) AND STORE IT IN ATANF, AND
*--SAVE REGISTERS FP2.

	move.l	d2,-(sp)	* SAVE d2 TEMPORARILY
	move.l	d1,d2	* THE EXP AND 16 BITS OF X
	and.l	#$00007800,d1	* 4 VARYING BITS OF F'S FRACTION
	and.l	#$7FFF0000,d2	* EXPONENT OF F
	sub.l	#$3FFB0000,d2	* K+4
	asr.l	#1,d2
	add.l	d2,d1	* THE 7 BITS IDENTIFYING F
	asr.l	#7,d1	* INDEX INTO TBL OF ATAN(|F|)
	lea	ATANTBL(pc),a1
	add.l	d1,a1	* ADDRESS OF ATAN(|F|)
	move.l	(a1)+,ATANF(a6)
	move.l	(a1)+,ATANFHI(a6)
	move.l	(a1)+,ATANFLO(a6)	* ATANF IS NOW ATAN(|F|)
	move.l	X(a6),d1	* LOAD SIGN AND EXPO. AGAIN
	and.l	#$80000000,d1	* SIGN(F)
	or.l	d1,ATANF(a6)	* ATANF IS NOW SIGN(F)*ATAN(|F|)
	move.l	(sp)+,d2	* RESTORE d2

*--THAT'S ALL I HAVE TO DO FOR NOW,
*--BUT ALAS, THE DIVIDE IS STILL CRANKING!

*--U IN FP0, WE ARE NOW READY TO COMPUTE ATAN(U) AS
*--U + A1*U*V*(A2 + V*(A3 + V)), V = U*U
*--THE POLYNOMIAL MAY LOOK STRANGE, BUT IS NEVERTHELESS CORRECT.
*--THE NATURAL FORM IS U + U*V*(A1 + V*(A2 + V*A3))
*--WHAT WE HAVE HERE IS MERELY	A1 = A3, A2 = A1/A3, A3 = A2/A3.
*--THE REASON FOR THIS REARRANGEMENT IS TO MAKE THE INDEPENDENT
*--PARTS A1*U*V AND (A2 + ... STUFF) MORE LOAD-BALANCED

	fmovem.x	fp2,-(sp)	* save fp2

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1
	fmove.d	ATANA3(pc),fp2
	fadd.x	fp1,fp2	* A3+V
	fmul.x	fp1,fp2	* V*(A3+V)
	fmul.x	fp0,fp1	* U*V
	fadd.d	ATANA2(pc),fp2	* A2+V*(A3+V)
	fmul.d	ATANA1(pc),fp1	* A1*U*V
	fmul.x	fp2,fp1	* A1*U*V*(A2+V*(A3+V))
	fadd.x	fp1,fp0	* ATAN(U), FP1 RELEASED

	fmovem.x 	(sp)+,fp2	* restore fp2

	fmove.l	d0,fpcr	* restore users rnd mode,prec
	fadd.x	ATANF(a6),fp0	* ATAN(X)
	bra	t_inx2

ATANBORS:
*--|X| IS IN d0 IN COMPACT FORM. FP1, d0 SAVED.
*--FP0 IS X AND |X| <= 1/16 OR |X| >= 16.
	ICMP.l	d1,#$3FFF8000
	bgt.w	ATANBIG	* I.E. |X| >= 16

ATANSM:
*--|X| <= 1/16
*--IF |X| < 2^(-40), RETURN X AS ANSWER. OTHERWISE, APPROXIMATE
*--ATAN(X) BY X + X*Y*(B1+Y*(B2+Y*(B3+Y*(B4+Y*(B5+Y*B6)))))
*--WHICH IS X + X*Y*( [B1+Z*(B3+Z*B5)] + [Y*(B2+Z*(B4+Z*B6)] )
*--WHERE Y = X*X, AND Z = Y*Y.

	ICMP.l	d1,#$3FD78000
	blt.w	ATANTINY

*--COMPUTE POLYNOMIAL
	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmul.x	fp0,fp0	* FPO IS Y = X*X

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS Z = Y*Y

	fmove.d	ATANB6(pc),fp2
	fmove.d	ATANB5(pc),fp3

	fmul.x	fp1,fp2	* Z*B6
	fmul.x	fp1,fp3	* Z*B5

	fadd.d	ATANB4(pc),fp2	* B4+Z*B6
	fadd.d	ATANB3(pc),fp3	* B3+Z*B5

	fmul.x	fp1,fp2	* Z*(B4+Z*B6)
	fmul.x	fp3,fp1	* Z*(B3+Z*B5)

	fadd.d	ATANB2(pc),fp2	* B2+Z*(B4+Z*B6)
	fadd.d	ATANB1(pc),fp1	* B1+Z*(B3+Z*B5)

	fmul.x	fp0,fp2	* Y*(B2+Z*(B4+Z*B6))
	fmul.x	X(a6),fp0	* X*Y

	fadd.x	fp2,fp1	* [B1+Z*(B3+Z*B5)]+[Y*(B2+Z*(B4+Z*B6))]

	fmul.x	fp1,fp0	* X*Y*([B1+Z*(B3+Z*B5)]+[Y*(B2+Z*(B4+Z*B6))])

	fmovem.x	(sp)+,fp2-fp3	* restore fp2/fp3

	fmove.l	d0,fpcr	* restore users rnd mode,prec
	fadd.x	X(a6),fp0
	bra	t_inx2

ATANTINY:
*--|X| < 2^(-40), ATAN(X) = X

	fmove.l	d0,fpcr	* restore users rnd mode,prec
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	X(a6),fp0	* last inst - possible exception set

	bra	t_catch

ATANBIG:
*--IF |X| > 2^(100), RETURN	SIGN(X)*(PI/2 - TINY). OTHERWISE,
*--RETURN SIGN(X)*PI/2 + ATAN(-1/X).
	ICMP.l	d1,#$40638000
	bgt.w	ATANHUGE

*--APPROXIMATE ATAN(-1/X) BY
*--X'+X'*Y*(C1+Y*(C2+Y*(C3+Y*(C4+Y*C5)))), X' = -1/X, Y = X'*X'
*--THIS CAN BE RE-WRITTEN AS
*--X'+X'*Y*( [C1+Z*(C3+Z*C5)] + [Y*(C2+Z*C4)] ), Z = Y*Y.

	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmove.s	#$BF800000,fp1	* LOAD -1
	fdiv.x	fp0,fp1	* FP1 IS -1/X

*--DIVIDE IS STILL CRANKING

	fmove.x	fp1,fp0	* FP0 IS X'
	fmul.x	fp0,fp0	* FP0 IS Y = X'*X'
	fmove.x	fp1,X(a6)	* X IS REALLY X'

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS Z = Y*Y

	fmove.d	ATANC5(pc),fp3
	fmove.d	ATANC4(pc),fp2

	fmul.x	fp1,fp3	* Z*C5
	fmul.x	fp1,fp2	* Z*B4

	fadd.d	ATANC3(pc),fp3	* C3+Z*C5
	fadd.d	ATANC2(pc),fp2	* C2+Z*C4

	fmul.x	fp3,fp1	* Z*(C3+Z*C5), FP3 RELEASED
	fmul.x	fp0,fp2	* Y*(C2+Z*C4)

	fadd.d	ATANC1(pc),fp1	* C1+Z*(C3+Z*C5)
	fmul.x	X(a6),fp0	* X'*Y

	fadd.x	fp2,fp1	* [Y*(C2+Z*C4)]+[C1+Z*(C3+Z*C5)]

	fmul.x	fp1,fp0	* X'*Y*([B1+Z*(B3+Z*B5)]
*		...	+[Y*(B2+Z*(B4+Z*B6))])
	fadd.x	X(a6),fp0

	fmovem.x	(sp)+,fp2-fp3	* restore fp2/fp3

	fmove.l	d0,fpcr	* restore users rnd mode,prec
	tst.b	(a0)
	bpl.b	pos_big

neg_big:
	fadd.x	NPIBY2(pc),fp0
	bra	t_minx2

pos_big:
	fadd.x	PPIBY2(pc),fp0
	bra	t_pinx2

ATANHUGE:
*--RETURN SIGN(X)*(PIBY2 - TINY) = SIGN(X)*PIBY2 - SIGN(X)*TINY
	tst.b	(a0)
	bpl.b	pos_huge

neg_huge:
	fmove.x	NPIBY2(pc),fp0
	fmove.l	d0,fpcr
	fadd.x	PTINY(pc),fp0
	bra	t_minx2

pos_huge:
	fmove.x	PPIBY2(pc),fp0
	fmove.l	d0,fpcr
	fadd.x	NTINY(pc),fp0
	bra	t_pinx2

	xdef	satand
*--ENTRY POINT FOR ATAN(X) FOR DENORMALIZED ARGUMENT
satand:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* sasin():  computes the inverse sine of a normalized input
* sasind(): computes the inverse sine of a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************	* 
*	fp0 = arcsin(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in	64 significant bit,
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	ASIN	
*	1. If |X| >= 1, go to 3.	
*		
*	2. (|X| < 1) Calculate asin(X) by
*	z := sqrt( [1-X][1+X] )	
*	asin(X) = atan( x / z ).
*	Exit.	
*		
*	3. If |X| > 1, go to 5.	
*		
*	4. (|X| = 1) sgn := sign(X), return asin(X) := sgn * Pi/2. Exit.*
*		
*	5. (|X| > 1) Generate an invalid operation by 0 * infinity.
*	Exit.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	sasin
sasin:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1,#$3FFF8000
	bge.b	ASINBIG

* This catch is added here for the '060 QSP. Originally, the call to
* satan() would handle this case by causing the exception which would
* not be caught until gen_except(). Now, with the exceptions being 
* detected inside of satan(), the exception would have been handled there
* instead of inside sasin() as expected.
	ICMP.l	d1,#$3FD78000
	blt.w	ASINTINY

*--THIS IS THE USUAL CASE, |X| < 1
*--ASIN(X) = ATAN( X / SQRT( (1-X)(1+X) ) )

ASINMAIN:
	fmove.s	#$3F800000,fp1
	fsub.x	fp0,fp1	* 1-X
	fmovem.x	fp2,-(sp)	*  {fp2}
	fmove.s	#$3F800000,fp2
	fadd.x	fp0,fp2	* 1+X
	fmul.x	fp2,fp1	* (1+X)(1-X)
	fmovem.x	(sp)+,fp2	*  {fp2}
	fsqrt.x	fp1	* SQRT([1-X][1+X])
	fdiv.x	fp1,fp0	* X/SQRT([1-X][1+X])
	fmovem.x	fp0,-(sp)	* save X/SQRT(...)
	lea	(sp),a0	* pass ptr to X/SQRT(...)
	bsr	satan
	add.l	#$c,sp	* clear X/SQRT(...) from stack
	bra	t_inx2

ASINBIG:
	fabs.x	fp0	* |X|
	fcmp.s	#$3F800000,fp0
	fbgt	t_operr	* cause an operr exception

*--|X| = 1, ASIN(X) = +- PI/2.
ASINONE:
	fmove.x	PIBY2(pc),fp0
	move.l	(a0),d1
	and.l	#$80000000,d1	* SIGN BIT OF X
	or.l	#$3F800000,d1	* +-1 IN SGL FORMAT
	move.l	d1,-(sp)	* push SIGN(X) IN SGL-FMT
	fmove.l	d0,fpcr
	fmul.s	(sp)+,fp0
	bra	t_inx2

*--|X| < 2^(-40), ATAN(X) = X
ASINTINY:
	fmove.l	d0,fpcr	* restore users rnd mode,prec
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	(a0),fp0	* last inst - possible exception
	bra	t_catch

	xdef	sasind
*--ASIN(X) = X FOR DENORMALIZED X
sasind:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* sacos():  computes the inverse cosine of a normalized input
* sacosd(): computes the inverse cosine of a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = arccos(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in	64 significant bit,
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM *********************************************************** *
*		
*	ACOS	
*	1. If |X| >= 1, go to 3.	
*		
*	2. (|X| < 1) Calculate acos(X) by
*	z := (1-X) / (1+X)	
*	acos(X) = 2 * atan( sqrt(z) ).
*	Exit.	
*		
*	3. If |X| > 1, go to 5.	
*		
*	4. (|X| = 1) If X > 0, return 0. Otherwise, return Pi. Exit.
*		
*	5. (|X| > 1) Generate an invalid operation by 0 * infinity.
*	Exit.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	sacos
sacos:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1	* pack exp w/ upper 16 fraction
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1,#$3FFF8000
	bge.b	ACOSBIG

*--THIS IS THE USUAL CASE, |X| < 1
*--ACOS(X) = 2 * ATAN(	SQRT( (1-X)/(1+X) ) )

ACOSMAIN:
	fmove.s	#$3F800000,fp1
	fadd.x	fp0,fp1	* 1+X
	fneg.x	fp0	* -X
	fadd.s	#$3F800000,fp0	* 1-X
	fdiv.x	fp1,fp0	* (1-X)/(1+X)
	fsqrt.x	fp0	* SQRT((1-X)/(1+X))
	move.l	d0,-(sp)	* save original users fpcr
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save SQRT(...) to stack
	lea	(sp),a0	* pass ptr to sqrt
	bsr	satan	* ATAN(SQRT([1-X]/[1+X]))
	add.l	#$c,sp	* clear SQRT(...) from stack

	fmove.l	(sp)+,fpcr	* restore users round prec,mode
	fadd.x	fp0,fp0	* 2 * ATAN( STUFF )
	bra	t_pinx2

ACOSBIG:
	fabs.x	fp0
	fcmp.s	#$3F800000,fp0
	fbgt	t_operr	* cause an operr exception

*--|X| = 1, ACOS(X) = 0 OR PI
	tst.b	(a0)	* is X positive or negative?
	bpl.b	ACOSP1

*--X = -1
*Returns PI and inexact exception
ACOSM1:
	fmove.x	PI(pc),fp0	* load PI
	fmove.l	d0,fpcr	* load round mode,prec
	fadd.s	#$00800000,fp0	* add a small value
	bra	t_pinx2

ACOSP1:
	bra	ld_pzero	* answer is positive zero

	xdef	sacosd
*--ACOS(X) = PI/2 FOR DENORMALIZED X
sacosd:
	fmove.l	d0,fpcr	* load user's rnd mode/prec
	fmove.x	PIBY2(pc),fp0
	bra	t_pinx2

**-------------------------------------------------------------------------------------------------
* setox():    computes the exponential for a normalized input
* setoxd():   computes the exponential for a denormalized input	* 
* setoxm1():  computes the exponential minus 1 for a normalized input
* setoxm1d(): computes the exponential minus 1 for a denormalized input
*		
* INPUT	*************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = exp(X) or exp(X)-1	
*		
* ACCURACY and MONOTONICITY ******************************************* *
*	The returned result is within 0.85 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently *
*	rounded to double precision. The result is provably monotonic 
*	in double precision.	
*		
* ALGORITHM and IMPLEMENTATION **************************************** *
*		
*	setoxd	
*	------	
*	Step 1.	Set ans := 1.0	
*		
*	Step 2.	Return	ans := ans + sign(X)*2^(-126). Exit.
*	Notes:	This will always generate one exception -- inexact.
*		
*		
*	setox	
*	-----	
*		
*	Step 1.	Filter out extreme cases of input argument.
*	1.1	If |X| >= 2^(-65), go to Step 1.3.
*	1.2	Go to Step 7.	
*	1.3	If |X| < 16380 log(2), go to Step 2.
*	1.4	Go to Step 8.	
*	Notes:	The usual case should take the branches 1.1 -> 1.3 -> 2.*
*	To avoid the use of floating-point comparisons, a
*	compact representation of |X| is used. This format is a
*	32-bit integer, the upper (more significant) 16 bits 
*	are the sign and biased exponent field of |X|; the 
*	lower 16 bits are the 16 most significant fraction
*	(including the explicit bit) bits of |X|. Consequently,
*	the comparisons in Steps 1.1 and 1.3 can be performed
*	by integer comparison. Note also that the constant
*	16380 log(2) used in Step 1.3 is also in the compact
*	form. Thus taking the branch to Step 2 guarantees 
*	|X| < 16380 log(2). There is no harm to have a small
*	number of cases where |X| is less than,	but close to,
*	16380 log(2) and the branch to Step 9 is taken.
*		
*	Step 2.	Calculate N = round-to-nearest-int( X * 64/log2 ).
*	2.1	Set AdjFlag := 0 (indicates the branch 1.3 -> 2 *
*	was taken)	
*	2.2	N := round-to-nearest-integer( X * 64/log2 ).
*	2.3	Calculate	J = N mod 64; so J = 0,1,2,..., *
*	or 63.	
*	2.4	Calculate	M = (N - J)/64; so N = 64M + J.
*	2.5	Calculate the address of the stored value of 
*	2^(J/64).	
*	2.6	Create the value Scale = 2^M.
*	Notes:	The calculation in 2.2 is really performed by
*	Z := X * constant
*	N := round-to-nearest-integer(Z)
*	where	
*	constant := single-precision( 64/log 2 ).
*		
*	Using a single-precision constant avoids memory 
*	access. Another effect of using a single-precision
*	"constant" is that the calculated value Z is 
*		
*	Z = X*(64/log2)*(1+eps), |eps| <= 2^(-24).
*		
*	This error has to be considered later in Steps 3 and 4.
*		
*	Step 3.	Calculate X - N*log2/64.
*	3.1	R := X + N*L1, 	
*	where L1 := single-precision(-log2/64).
*	3.2	R := R + N*L2, 	
*	L2 := extended-precision(-log2/64 - L1).*
*	Notes:	a) The way L1 and L2 are chosen ensures L1+L2 
*	approximate the value -log2/64 to 88 bits of accuracy.
*	b) N*L1 is exact because N is no longer than 22 bits
*	and L1 is no longer than 24 bits.
*	c) The calculation X+N*L1 is also exact due to 
*	cancellation. Thus, R is practically X+N(L1+L2) to full
*	64 bits. 	
*	d) It is important to estimate how large can |R| be
*	after Step 3.2.	
*		
*	N = rnd-to-int( X*64/log2 (1+eps) ), |eps|<=2^(-24)
*	X*64/log2 (1+eps)	=	N + f,	|f| <= 0.5
*	X*64/log2 - N	=	f - eps*X 64/log2
*	X - N*log2/64	=	f*log2/64 - eps*X
*		
*		
*	Now |X| <= 16446 log2, thus
*		
*	|X - N*log2/64| <= (0.5 + 16446/2^(18))*log2/64
*		<= 0.57 log2/64.
*	 This bound will be used in Step 4.
*		
*	Step 4.	Approximate exp(R)-1 by a polynomial
*	p = R + R*R*(A1 + R*(A2 + R*(A3 + R*(A4 + R*A5))))
*	Notes:	a) In order to reduce memory access, the coefficients 
*	are made as "dc.w" as possible: A1 (which is 1/2), A4
*	and A5 are single precision; A2 and A3 are double
*	precision. 	
*	b) Even with the restrictions above, 
*	   |p - (exp(R)-1)| < 2^(-68.8) for all |R| <= 0.0062.
*	Note that 0.0062 is slightly bigger than 0.57 log2/64.
*	c) To fully utilize the pipeline, p is separated into
*	two independent pieces of roughly equal complexities
*	p = [ R + R*S*(A2 + S*A4) ]	+
*	[ S*(A1 + S*(A3 + S*A5)) ]
*	where S = R*R.	
*		
*	Step 5.	Compute 2^(J/64)*exp(R) = 2^(J/64)*(1+p) by
*	ans := T + ( T*p + t)
*	where T and t are the stored values for 2^(J/64).
*	Notes:	2^(J/64) is stored as T and t where T+t approximates
*	2^(J/64) to roughly 85 bits; T is in extended precision
*	and t is in single precision. Note also that T is 
*	rounded to 62 bits so that the last two bits of T are 
*	zero. The reason for such a special form is that T-1, 
*	T-2, and T-8 will all be exact --- a property that will
*	give much more accurate computation of the function 
*	EXPM1.	
*		
*	Step 6.	Reconstruction of exp(X)
*	exp(X) = 2^M * 2^(J/64) * exp(R).
*	6.1	If AdjFlag = 0, go to 6.3
*	6.2	ans := ans * AdjScale
*	6.3	Restore the user FPCR
*	6.4	Return ans := ans * Scale. Exit.
*	Notes:	If AdjFlag = 0, we have X = Mlog2 + Jlog2/64 + R,
*	|M| <= 16380, and Scale = 2^M. Moreover, exp(X) will
*	neither overflow nor underflow. If AdjFlag = 1, that
*	means that	
*	X = (M1+M)log2 + Jlog2/64 + R, |M1+M| >= 16380.
*	Hence, exp(X) may overflow or underflow or neither.
*	When that is the case, AdjScale = 2^(M1) where M1 is
*	approximately M. Thus 6.2 will never cause 
*	over/underflow. Possible exception in 6.4 is overflow
*	or underflow. The inexact exception is not generated in
*	6.4. Although one can argue that the inexact flag
*	should always be raised, to simulate that exception 
*	cost to much than the flag is worth in practical uses.
*		
*	Step 7.	Return 1 + X.	
*	7.1	ans := X	
*	7.2	Restore user FPCR.
*	7.3	Return ans := 1 + ans. Exit
*	Notes:	For non-zero X, the inexact exception will always be
*	raised by 7.3. That is the only exception raised by 7.3.*
*	Note also that we use the FMOVEM instruction to move X
*	in Step 7.1 to avoid unnecessary trapping. (Although
*	the FMOVEM may not seem relevant since X is normalized,
*	the precaution will be useful in the library version of
*	this code where the separate entry for denormalized 
*	inputs will be done away with.)
*		
*	Step 8.	Handle exp(X) where |X| >= 16380log2.
*	8.1	If |X| > 16480 log2, go to Step 9.
*	(mimic 2.2 - 2.6)	
*	8.2	N := round-to-integer( X * 64/log2 )
*	8.3	Calculate J = N mod 64, J = 0,1,...,63
*	8.4	K := (N-J)/64, M1 := truncate(K/2), M = K-M1, 
*	AdjFlag := 1.	
*	8.5	Calculate the address of the stored value 
*	2^(J/64).	
*	8.6	Create the values Scale = 2^M, AdjScale = 2^M1.
*	8.7	Go to Step 3.	
*	Notes:	Refer to notes for 2.2 - 2.6.
*		
*	Step 9.	Handle exp(X), |X| > 16480 log2.
*	9.1	If X < 0, go to 9.3
*	9.2	ans := Huge, go to 9.4
*	9.3	ans := Tiny.	
*	9.4	Restore user FPCR.
*	9.5	Return ans := ans * ans. Exit.
*	Notes:	Exp(X) will surely overflow or underflow, depending on
*	X's sign. "Huge" and "Tiny" are respectively large/tiny
*	extended-precision numbers whose square over/underflow
*	with an inexact result. Thus, 9.5 always raises the
*	inexact together with either overflow or underflow.
*		
*	setoxm1d	
*	--------	
*		
*	Step 1.	Set ans := 0	
*		
*	Step 2.	Return	ans := X + ans. Exit.
*	Notes:	This will return X with the appropriate rounding
*	 precision prescribed by the user FPCR.
*		
*	setoxm1	
*	-------	
*		
*	Step 1.	Check |X|	
*	1.1	If |X| >= 1/4, go to Step 1.3.
*	1.2	Go to Step 7.	
*	1.3	If |X| < 70 log(2), go to Step 2.
*	1.4	Go to Step 10.	
*	Notes:	The usual case should take the branches 1.1 -> 1.3 -> 2.*
*	However, it is conceivable |X| can be small very often
*	because EXPM1 is intended to evaluate exp(X)-1 
*	accurately when |X| is small. For further details on 
*	the comparisons, see the notes on Step 1 of setox.
*		
*	Step 2.	Calculate N = round-to-nearest-int( X * 64/log2 ).
*	2.1	N := round-to-nearest-integer( X * 64/log2 ).
*	2.2	Calculate	J = N mod 64; so J = 0,1,2,..., *
*	or 63.	
*	2.3	Calculate	M = (N - J)/64; so N = 64M + J.
*	2.4	Calculate the address of the stored value of 
*	2^(J/64).	
*	2.5	Create the values Sc = 2^M and 
*	OnebySc := -2^(-M).
*	Notes:	See the notes on Step 2 of setox.
*		
*	Step 3.	Calculate X - N*log2/64.
*	3.1	R := X + N*L1, 	
*	where L1 := single-precision(-log2/64).
*	3.2	R := R + N*L2, 	
*	L2 := extended-precision(-log2/64 - L1).*
*	Notes:	Applying the analysis of Step 3 of setox in this case
*	shows that |R| <= 0.0055 (note that |X| <= 70 log2 in
*	this case).	
*		
*	Step 4.	Approximate exp(R)-1 by a polynomial
*	p = R+R*R*(A1+R*(A2+R*(A3+R*(A4+R*(A5+R*A6)))))
*	Notes:	a) In order to reduce memory access, the coefficients 
*	are made as "dc.w" as possible: A1 (which is 1/2), A5 
*	and A6 are single precision; A2, A3 and A4 are double 
*	precision. 	
*	b) Even with the restriction above,
*	|p - (exp(R)-1)| <	|R| * 2^(-72.7)
*	for all |R| <= 0.0055.	
*	c) To fully utilize the pipeline, p is separated into
*	two independent pieces of roughly equal complexity
*	p = [ R*S*(A2 + S*(A4 + S*A6)) ]	+
*	[ R + S*(A1 + S*(A3 + S*A5)) ]
*	where S = R*R.	
*		
*	Step 5.	Compute 2^(J/64)*p by	
*	p := T*p
*	where T and t are the stored values for 2^(J/64).
*	Notes:	2^(J/64) is stored as T and t where T+t approximates
*	2^(J/64) to roughly 85 bits; T is in extended precision
*	and t is in single precision. Note also that T is 
*	rounded to 62 bits so that the last two bits of T are 
*	zero. The reason for such a special form is that T-1, 
*	T-2, and T-8 will all be exact --- a property that will
*	be exploited in Step 6 below. The total relative error
*	in p is no bigger than 2^(-67.7) compared to the final
*	result.	
*		
*	Step 6.	Reconstruction of exp(X)-1
*	exp(X)-1 = 2^M * ( 2^(J/64) + p - 2^(-M) ).
*	6.1	If M <= 63, go to Step 6.3.
*	6.2	ans := T + (p + (t + OnebySc)). Go to 6.6
*	6.3	If M >= -3, go to 6.5.
*	6.4	ans := (T + (p + t)) + OnebySc. Go to 6.6
*	6.5	ans := (T + OnebySc) + (p + t).
*	6.6	Restore user FPCR.
*	6.7	Return ans := Sc * ans. Exit.
*	Notes:	The various arrangements of the expressions give 
*	accurate evaluations.	
*		
*	Step 7.	exp(X)-1 for |X| < 1/4.	
*	7.1	If |X| >= 2^(-65), go to Step 9.
*	7.2	Go to Step 8.	
*		
*	Step 8.	Calculate exp(X)-1, |X| < 2^(-65).
*	8.1	If |X| < 2^(-16312), goto 8.3
*	8.2	Restore FPCR; return ans := X - 2^(-16382).
*	Exit.	
*	8.3	X := X * 2^(140).
*	8.4	Restore FPCR; ans := ans - 2^(-16382).
*	 Return ans := ans*2^(140). Exit
*	Notes:	The idea is to return "X - tiny" under the user
*	precision and rounding modes. To avoid unnecessary
*	inefficiency, we stay away from denormalized numbers 
*	the best we can. For |X| >= 2^(-16312), the 
*	straightforward 8.2 generates the inexact exception as
*	the case warrants.	
*		
*	Step 9.	Calculate exp(X)-1, |X| < 1/4, by a polynomial
*	p = X + X*X*(B1 + X*(B2 + ... + X*B12))
*	Notes:	a) In order to reduce memory access, the coefficients
*	are made as "dc.w" as possible: B1 (which is 1/2), B9
*	to B12 are single precision; B3 to B8 are double 
*	precision; and B2 is double extended.
*	b) Even with the restriction above,
*	|p - (exp(X)-1)| < |X| 2^(-70.6)
*	for all |X| <= 0.251.	
*	Note that 0.251 is slightly bigger than 1/4.
*	c) To fully preserve accuracy, the polynomial is 
*	computed as	
*	X + ( S*B1 +	Q ) where S = X*X and
*	Q	=	X*S*(B2 + X*(B3 + ... + X*B12))
*	d) To fully utilize the pipeline, Q is separated into
*	two independent pieces of roughly equal complexity
*	Q = [ X*S*(B2 + S*(B4 + ... + S*B12)) ] +
*	[ S*S*(B3 + S*(B5 + ... + S*B11)) ]
*		
*	Step 10. Calculate exp(X)-1 for |X| >= 70 log 2.
*	10.1 If X >= 70log2 , exp(X) - 1 = exp(X) for all 
*	practical purposes. Therefore, go to Step 1 of setox.
*	10.2 If X <= -70log2, exp(X) - 1 = -1 for all practical
*	purposes. 	
*	ans := -1 	
*	Restore user FPCR	
*	Return ans := ans + 2^(-126). Exit.
*	Notes:	10.2 will always create an inexact and return -1 + tiny
*	in the user rounding precision and mode.
*		
**-------------------------------------------------------------------------------------------------

L2:	dc.l	$3FDC0000,$82E30865,$4361C4C6,$00000000

EEXPA3:	dc.l	$3FA55555,$55554CC1
EEXPA2:	dc.l	$3FC55555,$55554A54

EM1A4:	dc.l	$3F811111,$11174385
EM1A3:	dc.l	$3FA55555,$55554F5A

EM1A2:	dc.l	$3FC55555,$55555555,$00000000,$00000000

EM1B8:	dc.l	$3EC71DE3,$A5774682
EM1B7:	dc.l	$3EFA01A0,$19D7CB68

EM1B6:	dc.l	$3F2A01A0,$1A019DF3
EM1B5:	dc.l	$3F56C16C,$16C170E2

EM1B4:	dc.l	$3F811111,$11111111
EM1B3:	dc.l	$3FA55555,$55555555

EM1B2:	dc.l	$3FFC0000,$AAAAAAAA,$AAAAAAAB
	dc.l	$00000000

TWO140:	dc.l	$48B00000,$00000000
TWON140:
	dc.l	$37300000,$00000000

EEXPTBL:
	dc.l	$3FFF0000,$80000000,$00000000,$00000000
	dc.l	$3FFF0000,$8164D1F3,$BC030774,$9F841A9B
	dc.l	$3FFF0000,$82CD8698,$AC2BA1D8,$9FC1D5B9
	dc.l	$3FFF0000,$843A28C3,$ACDE4048,$A0728369
	dc.l	$3FFF0000,$85AAC367,$CC487B14,$1FC5C95C
	dc.l	$3FFF0000,$871F6196,$9E8D1010,$1EE85C9F
	dc.l	$3FFF0000,$88980E80,$92DA8528,$9FA20729
	dc.l	$3FFF0000,$8A14D575,$496EFD9C,$A07BF9AF
	dc.l	$3FFF0000,$8B95C1E3,$EA8BD6E8,$A0020DCF
	dc.l	$3FFF0000,$8D1ADF5B,$7E5BA9E4,$205A63DA
	dc.l	$3FFF0000,$8EA4398B,$45CD53C0,$1EB70051
	dc.l	$3FFF0000,$9031DC43,$1466B1DC,$1F6EB029
	dc.l	$3FFF0000,$91C3D373,$AB11C338,$A0781494
	dc.l	$3FFF0000,$935A2B2F,$13E6E92C,$9EB319B0
	dc.l	$3FFF0000,$94F4EFA8,$FEF70960,$2017457D
	dc.l	$3FFF0000,$96942D37,$20185A00,$1F11D537
	dc.l	$3FFF0000,$9837F051,$8DB8A970,$9FB952DD
	dc.l	$3FFF0000,$99E04593,$20B7FA64,$1FE43087
	dc.l	$3FFF0000,$9B8D39B9,$D54E5538,$1FA2A818
	dc.l	$3FFF0000,$9D3ED9A7,$2CFFB750,$1FDE494D
	dc.l	$3FFF0000,$9EF53260,$91A111AC,$20504890
	dc.l	$3FFF0000,$A0B0510F,$B9714FC4,$A073691C
	dc.l	$3FFF0000,$A2704303,$0C496818,$1F9B7A05
	dc.l	$3FFF0000,$A43515AE,$09E680A0,$A0797126
	dc.l	$3FFF0000,$A5FED6A9,$B15138EC,$A071A140
	dc.l	$3FFF0000,$A7CD93B4,$E9653568,$204F62DA
	dc.l	$3FFF0000,$A9A15AB4,$EA7C0EF8,$1F283C4A
	dc.l	$3FFF0000,$AB7A39B5,$A93ED338,$9F9A7FDC
	dc.l	$3FFF0000,$AD583EEA,$42A14AC8,$A05B3FAC
	dc.l	$3FFF0000,$AF3B78AD,$690A4374,$1FDF2610
	dc.l	$3FFF0000,$B123F581,$D2AC2590,$9F705F90
	dc.l	$3FFF0000,$B311C412,$A9112488,$201F678A
	dc.l	$3FFF0000,$B504F333,$F9DE6484,$1F32FB13
	dc.l	$3FFF0000,$B6FD91E3,$28D17790,$20038B30
	dc.l	$3FFF0000,$B8FBAF47,$62FB9EE8,$200DC3CC
	dc.l	$3FFF0000,$BAFF5AB2,$133E45FC,$9F8B2AE6
	dc.l	$3FFF0000,$BD08A39F,$580C36C0,$A02BBF70
	dc.l	$3FFF0000,$BF1799B6,$7A731084,$A00BF518
	dc.l	$3FFF0000,$C12C4CCA,$66709458,$A041DD41
	dc.l	$3FFF0000,$C346CCDA,$24976408,$9FDF137B
	dc.l	$3FFF0000,$C5672A11,$5506DADC,$201F1568
	dc.l	$3FFF0000,$C78D74C8,$ABB9B15C,$1FC13A2E
	dc.l	$3FFF0000,$C9B9BD86,$6E2F27A4,$A03F8F03
	dc.l	$3FFF0000,$CBEC14FE,$F2727C5C,$1FF4907D
	dc.l	$3FFF0000,$CE248C15,$1F8480E4,$9E6E53E4
	dc.l	$3FFF0000,$D06333DA,$EF2B2594,$1FD6D45C
	dc.l	$3FFF0000,$D2A81D91,$F12AE45C,$A076EDB9
	dc.l	$3FFF0000,$D4F35AAB,$CFEDFA20,$9FA6DE21
	dc.l	$3FFF0000,$D744FCCA,$D69D6AF4,$1EE69A2F
	dc.l	$3FFF0000,$D99D15C2,$78AFD7B4,$207F439F
	dc.l	$3FFF0000,$DBFBB797,$DAF23754,$201EC207
	dc.l	$3FFF0000,$DE60F482,$5E0E9124,$9E8BE175
	dc.l	$3FFF0000,$E0CCDEEC,$2A94E110,$20032C4B
	dc.l	$3FFF0000,$E33F8972,$BE8A5A50,$2004DFF5
	dc.l	$3FFF0000,$E5B906E7,$7C8348A8,$1E72F47A
	dc.l	$3FFF0000,$E8396A50,$3C4BDC68,$1F722F22
	dc.l	$3FFF0000,$EAC0C6E7,$DD243930,$A017E945
	dc.l	$3FFF0000,$ED4F301E,$D9942B84,$1F401A5B
	dc.l	$3FFF0000,$EFE4B99B,$DCDAF5CC,$9FB9A9E3
	dc.l	$3FFF0000,$F281773C,$59FFB138,$20744C05
	dc.l	$3FFF0000,$F5257D15,$2486CC2C,$1F773A19
	dc.l	$3FFF0000,$F7D0DF73,$0AD13BB8,$1FFE90D5
	dc.l	$3FFF0000,$FA83B2DB,$722A033C,$A041ED22
	dc.l	$3FFF0000,$FD3E0C0C,$F486C174,$1F853F3A

ADJFLAG	equ	EXC_LV+L_SCR2
SCALE	equ	EXC_LV+FP_SCR0
ADJSCALE	equ	EXC_LV+FP_SCR1
SC	equ	EXC_LV+FP_SCR0
ONEBYSC	equ	EXC_LV+FP_SCR1

	xdef	setox
setox:
*--entry point for EXP(X), here X is finite, non-zero, and not NaN's

*--Step 1.
	move.l	(a0),d1	* load part of input X
	and.l	#$7FFF0000,d1	* biased expo. of X
	ICMP.l	d1,#$3FBE0000	* 2^(-65)
	bge.b	EXPC1	* normal case
	bra	EXPSM

EXPC1:
*--The case |X| >= 2^(-65)
	move.w	4(a0),d1	* expo. and partial sig. of |X|
	ICMP.l	d1,#$400CB167	* 16380 log2 trunc. 16 bits
	blt.b	EXPMAIN	* normal case
	bra	EEXPBIG

EXPMAIN:
*--Step 2.
*--This is the normal branch:	2^(-65) <= |X| < 16380 log2.
	fmove.x	(a0),fp0	* load input from (a0)

	fmove.x	fp0,fp1
	fmul.s	#$42B8AA3B,fp0	* 64/log2 * X
	fmovem.x	fp2-fp3,-(sp)	* save fp2 {fp2/fp3}
	move.l	#0,ADJFLAG(a6)
	fmove.l	fp0,d1	* N = int( X * 64/log2 )
	lea	EEXPTBL(pc),a1
	fmove.l	d1,fp0	* convert to floating-format

	move.l	d1,EXC_LV+L_SCR1(a6)	* save N temporarily
	and.l	#$3F,d1	* D0 is J = N mod 64
	lsl.l	#4,d1
	add.l	d1,a1	* address of 2^(J/64)
	move.l	EXC_LV+L_SCR1(a6),d1
	asr.l	#6,d1	* D0 is M
	add.w	#$3FFF,d1	* biased expo. of 2^(M)
	move.w	L2(pc),EXC_LV+L_SCR1(a6)	* prefetch L2, no need in CB

EXPCONT1:
*--Step 3.
*--fp1,fp2 saved on the stack. fp0 is N, fp1 is X,
*--a0 points to 2^(J/64), D0 is biased expo. of 2^(M)
	fmove.x	fp0,fp2
	fmul.s	#$BC317218,fp0	* N * L1, L1 = lead(-log2/64)
	fmul.x	L2(pc),fp2	* N * L2, L1+L2 = -log2/64
	fadd.x	fp1,fp0	* X + N*L1
	fadd.x	fp2,fp0	* fp0 is R, reduced arg.

*--Step 4.
*--WE NOW COMPUTE EXP(R)-1 BY A POLYNOMIAL
*-- R + R*R*(A1 + R*(A2 + R*(A3 + R*(A4 + R*A5))))
*--TO FULLY UTILIZE THE PIPELINE, WE COMPUTE S = R*R
*--[R+R*S*(A2+S*A4)] + [S*(A1+S*(A3+S*A5))]

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* fp1 IS S = R*R

	fmove.s	#$3AB60B70,fp2	* fp2 IS A5

	fmul.x	fp1,fp2	* fp2 IS S*A5
	fmove.x	fp1,fp3
	fmul.s	#$3C088895,fp3	* fp3 IS S*A4

	fadd.d	EEXPA3(pc),fp2	* fp2 IS A3+S*A5
	fadd.d	EEXPA2(pc),fp3	* fp3 IS A2+S*A4

	fmul.x	fp1,fp2	* fp2 IS S*(A3+S*A5)
	move.w	d1,SCALE(a6)	* SCALE is 2^(M) in extended
	move.l	#$80000000,SCALE+4(a6)
	clr.l	SCALE+8(a6)

	fmul.x	fp1,fp3	* fp3 IS S*(A2+S*A4)

	fadd.s	#$3F000000,fp2	* fp2 IS A1+S*(A3+S*A5)
	fmul.x	fp0,fp3	* fp3 IS R*S*(A2+S*A4)

	fmul.x	fp1,fp2	* fp2 IS S*(A1+S*(A3+S*A5))
	fadd.x	fp3,fp0	* fp0 IS R+R*S*(A2+S*A4),

	fmove.x	(a1)+,fp1	* fp1 is lead. pt. of 2^(J/64)
	fadd.x	fp2,fp0	* fp0 is EXP(R) - 1

*--Step 5
*--final reconstruction process
*--EXP(X) = 2^M * ( 2^(J/64) + 2^(J/64)*(EXP(R)-1) )

	fmul.x	fp1,fp0	* 2^(J/64)*(Exp(R)-1)
	fmovem.x	(sp)+,fp2-fp3	* fp2 restored {fp2/fp3}
	fadd.s	(a1),fp0	* accurate 2^(J/64)

	fadd.x	fp1,fp0	* 2^(J/64) + 2^(J/64)*...
	move.l	ADJFLAG(a6),d1

*--Step 6
	tst.l	d1
	beq.b	NORMAL
ADJUST:
	fmul.x	ADJSCALE(a6),fp0
NORMAL:
	fmove.l	d0,fpcr	* restore user FPCR
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	SCALE(a6),fp0	* multiply 2^(M)
	bra	t_catch

EXPSM:
*--Step 7
	fmovem.x	(a0),fp0	* load X
	fmove.l	d0,fpcr
	fadd.s	#$3F800000,fp0	* 1+X in user mode
	bra	t_pinx2

EEXPBIG:
*--Step 8
	ICMP.l	d1,#$400CB27C	* 16480 log2
	bgt.b	EXP2BIG
*--Steps 8.2 -- 8.6
	fmove.x	(a0),fp0	* load input from (a0)

	fmove.x	fp0,fp1
	fmul.s	#$42B8AA3B,fp0	* 64/log2 * X
	fmovem.x	fp2-fp3,-(sp)	* save fp2 {fp2/fp3}
	move.l	#1,ADJFLAG(a6)
	fmove.l	fp0,d1	* N = int( X * 64/log2 )
	lea	EEXPTBL(pc),a1
	fmove.l	d1,fp0	* convert to floating-format
	move.l	d1,EXC_LV+L_SCR1(a6)	* save N temporarily
	and.l	#$3F,d1	* D0 is J = N mod 64
	lsl.l	#4,d1
	add.l	d1,a1	* address of 2^(J/64)
	move.l	EXC_LV+L_SCR1(a6),d1
	asr.l	#6,d1	* D0 is K
	move.l	d1,EXC_LV+L_SCR1(a6)	* save K temporarily
	asr.l	#1,d1	* D0 is M1
	sub.l	d1,EXC_LV+L_SCR1(a6)	* a1 is M
	add.w	#$3FFF,d1	* biased expo. of 2^(M1)
	move.w	d1,ADJSCALE(a6)	* ADJSCALE := 2^(M1)
	move.l	#$80000000,ADJSCALE+4(a6)
	clr.l	ADJSCALE+8(a6)
	move.l	EXC_LV+L_SCR1(a6),d1	* D0 is M
	add.w	#$3FFF,d1	* biased expo. of 2^(M)
	bra.w	EXPCONT1	* go back to Step 3

EXP2BIG:
*--Step 9
	tst.b	(a0)	* is X positive or negative?
	bmi	t_unfl2
	bra	t_ovfl2

	xdef	setoxd
setoxd:
*--entry point for EXP(X), X is denormalized
	move.l	(a0),-(sp)
	andi.l	#$80000000,(sp)
	ori.l	#$00800000,(sp)	* sign(X)*2^(-126)

	fmove.s	#$3F800000,fp0

	fmove.l	d0,fpcr
	fadd.s	(sp)+,fp0
	bra	t_pinx2

	xdef	setoxm1
setoxm1:
*--entry point for EXPM1(X), here X is finite, non-zero, non-NaN

*--Step 1.
*--Step 1.1
	move.l	(a0),d1	* load part of input X
	and.l	#$7FFF0000,d1	* biased expo. of X
	ICMP.l	d1,#$3FFD0000	* 1/4
	bge.b	EM1CON1	* |X| >= 1/4
	bra	EM1SM

EM1CON1:
*--Step 1.3
*--The case |X| >= 1/4
	move.w	4(a0),d1	* expo. and partial sig. of |X|
	ICMP.l	d1,#$4004C215	* 70log2 rounded up to 16 bits
	ble.b	EM1MAIN	* 1/4 <= |X| <= 70log2
	bra	EM1BIG

EM1MAIN:
*--Step 2.
*--This is the case:	1/4 <= |X| <= 70 log2.
	fmove.x	(a0),fp0	* load input from (a0)

	fmove.x	fp0,fp1
	fmul.s	#$42B8AA3B,fp0	* 64/log2 * X
	fmovem.x	fp2-fp3,-(sp)	* save fp2 {fp2/fp3}
	fmove.l	fp0,d1	* N = int( X * 64/log2 )
	lea	EEXPTBL(pc),a1
	fmove.l	d1,fp0	* convert to floating-format

	move.l	d1,EXC_LV+L_SCR1(a6)	* save N temporarily
	and.l	#$3F,d1	* D0 is J = N mod 64
	lsl.l	#4,d1
	add.l	d1,a1	* address of 2^(J/64)
	move.l	EXC_LV+L_SCR1(a6),d1
	asr.l	#6,d1	* D0 is M
	move.l	d1,EXC_LV+L_SCR1(a6)	* save a copy of M

*--Step 3.
*--fp1,fp2 saved on the stack. fp0 is N, fp1 is X,
*--a0 points to 2^(J/64), D0 and a1 both contain M
	fmove.x	fp0,fp2
	fmul.s	#$BC317218,fp0	* N * L1, L1 = lead(-log2/64)
	fmul.x	L2(pc),fp2	* N * L2, L1+L2 = -log2/64
	fadd.x	fp1,fp0	* X + N*L1
	fadd.x	fp2,fp0	* fp0 is R, reduced arg.
	add.w	#$3FFF,d1	* D0 is biased expo. of 2^M

*--Step 4.
*--WE NOW COMPUTE EXP(R)-1 BY A POLYNOMIAL
*-- R + R*R*(A1 + R*(A2 + R*(A3 + R*(A4 + R*(A5 + R*A6)))))
*--TO FULLY UTILIZE THE PIPELINE, WE COMPUTE S = R*R
*--[R*S*(A2+S*(A4+S*A6))] + [R+S*(A1+S*(A3+S*A5))]

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* fp1 IS S = R*R

	fmove.s	#$3950097B,fp2	* fp2 IS a6

	fmul.x	fp1,fp2	* fp2 IS S*A6
	fmove.x	fp1,fp3
	fmul.s	#$3AB60B6A,fp3	* fp3 IS S*A5

	fadd.d	EM1A4(pc),fp2	* fp2 IS A4+S*A6
	fadd.d	EM1A3(pc),fp3	* fp3 IS A3+S*A5
	move.w	d1,SC(a6)	* SC is 2^(M) in extended
	move.l	#$80000000,SC+4(a6)
	clr.l	SC+8(a6)

	fmul.x	fp1,fp2	* fp2 IS S*(A4+S*A6)
	move.l	EXC_LV+L_SCR1(a6),d1	* D0 is	M
	neg.w	d1	* D0 is -M
	fmul.x	fp1,fp3	* fp3 IS S*(A3+S*A5)
	add.w	#$3FFF,d1	* biased expo. of 2^(-M)
	fadd.d	EM1A2(pc),fp2	* fp2 IS A2+S*(A4+S*A6)
	fadd.s	#$3F000000,fp3	* fp3 IS A1+S*(A3+S*A5)

	fmul.x	fp1,fp2	* fp2 IS S*(A2+S*(A4+S*A6))
	or.w	#$8000,d1	* signed/expo. of -2^(-M)
	move.w	d1,ONEBYSC(a6)	* OnebySc is -2^(-M)
	move.l	#$80000000,ONEBYSC+4(a6)
	clr.l	ONEBYSC+8(a6)
	fmul.x	fp3,fp1	* fp1 IS S*(A1+S*(A3+S*A5))

	fmul.x	fp0,fp2	* fp2 IS R*S*(A2+S*(A4+S*A6))
	fadd.x	fp1,fp0	* fp0 IS R+S*(A1+S*(A3+S*A5))

	fadd.x	fp2,fp0	* fp0 IS EXP(R)-1

	fmovem.x	(sp)+,fp2-fp3	* fp2 restored {fp2/fp3}

*--Step 5
*--Compute 2^(J/64)*p

	fmul.x	(a1),fp0	* 2^(J/64)*(Exp(R)-1)

*--Step 6
*--Step 6.1
	move.l	EXC_LV+L_SCR1(a6),d1	* retrieve M
	ICMP.l	d1,#63
	ble.b	MLE63
*--Step 6.2	M >= 64
	fmove.s	12(a1),fp1	* fp1 is t
	fadd.x	ONEBYSC(a6),fp1	* fp1 is t+OnebySc
	fadd.x	fp1,fp0	* p+(t+OnebySc), fp1 released
	fadd.x	(a1),fp0	* T+(p+(t+OnebySc))
	bra	EM1SCALE
MLE63:
*--Step 6.3	M <= 63
	ICMP.l	d1,#-3
	bge.b	MGEN3
MLTN3:
*--Step 6.4	M <= -4
	fadd.s	12(a1),fp0	* p+t
	fadd.x	(a1),fp0	* T+(p+t)
	fadd.x	ONEBYSC(a6),fp0	* OnebySc + (T+(p+t))
	bra	EM1SCALE
MGEN3:
*--Step 6.5	-3 <= M <= 63
	fmove.x	(a1)+,fp1	* fp1 is T
	fadd.s	(a1),fp0	* fp0 is p+t
	fadd.x	ONEBYSC(a6),fp1	* fp1 is T+OnebySc
	fadd.x	fp1,fp0	* (T+OnebySc)+(p+t)

EM1SCALE:
*--Step 6.6
	fmove.l	d0,fpcr
	fmul.x	SC(a6),fp0
	bra	t_inx2

EM1SM:
*--Step 7	|X| < 1/4.
	ICMP.l	d1,#$3FBE0000	* 2^(-65)
	bge.b	EM1POLY

EM1TINY:
*--Step 8	|X| < 2^(-65)
	ICMP.l	d1,#$00330000	* 2^(-16312)
	blt.b	EM12TINY
*--Step 8.2
	move.l	#$80010000,SC(a6)	* SC is -2^(-16382)
	move.l	#$80000000,SC+4(a6)
	clr.l	SC+8(a6)
	fmove.x	(a0),fp0
	fmove.l	d0,fpcr
	move.b	#FADD_OP,d1	* last inst is ADD
	fadd.x	SC(a6),fp0
	bra	t_catch

EM12TINY:
*--Step 8.3
	fmove.x	(a0),fp0
	fmul.d	TWO140(pc),fp0
	move.l	#$80010000,SC(a6)
	move.l	#$80000000,SC+4(a6)
	clr.l	SC+8(a6)
	fadd.x	SC(a6),fp0
	fmove.l	d0,fpcr
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.d	TWON140(pc),fp0
	bra	t_catch

EM1POLY:
*--Step 9	exp(X)-1 by a simple polynomial
	fmove.x	(a0),fp0	* fp0 is X
	fmul.x	fp0,fp0	* fp0 is S := X*X
	fmovem.x	fp2-fp3,-(sp)	* save fp2 {fp2/fp3}
	fmove.s	#$2F30CAA8,fp1	* fp1 is B12
	fmul.x	fp0,fp1	* fp1 is S*B12
	fmove.s	#$310F8290,fp2	* fp2 is B11
	fadd.s	#$32D73220,fp1	* fp1 is B10+S*B12

	fmul.x	fp0,fp2	* fp2 is S*B11
	fmul.x	fp0,fp1	* fp1 is S*(B10 + ...

	fadd.s	#$3493F281,fp2	* fp2 is B9+S*...
	fadd.d	EM1B8(pc),fp1	* fp1 is B8+S*...

	fmul.x	fp0,fp2	* fp2 is S*(B9+...
	fmul.x	fp0,fp1	* fp1 is S*(B8+...

	fadd.d	EM1B7(pc),fp2	* fp2 is B7+S*...
	fadd.d	EM1B6(pc),fp1	* fp1 is B6+S*...

	fmul.x	fp0,fp2	* fp2 is S*(B7+...
	fmul.x	fp0,fp1	* fp1 is S*(B6+...

	fadd.d	EM1B5(pc),fp2	* fp2 is B5+S*...
	fadd.d	EM1B4(pc),fp1	* fp1 is B4+S*...

	fmul.x	fp0,fp2	* fp2 is S*(B5+...
	fmul.x	fp0,fp1	* fp1 is S*(B4+...

	fadd.d	EM1B3(pc),fp2	* fp2 is B3+S*...
	fadd.x	EM1B2(pc),fp1	* fp1 is B2+S*...

	fmul.x	fp0,fp2	* fp2 is S*(B3+...
	fmul.x	fp0,fp1	* fp1 is S*(B2+...

	fmul.x	fp0,fp2	* fp2 is S*S*(B3+...)
	fmul.x	(a0),fp1	* fp1 is X*S*(B2...

	fmul.s	#$3F000000,fp0	* fp0 is S*B1
	fadd.x	fp2,fp1	* fp1 is Q

	fmovem.x	(sp)+,fp2-fp3	* fp2 restored {fp2/fp3}

	fadd.x	fp1,fp0	* fp0 is S*B1+Q

	fmove.l	d0,fpcr
	fadd.x	(a0),fp0
	bra	t_inx2

EM1BIG:
*--Step 10	|X| > 70 log2
	move.l	(a0),d1
	ICMP.l	d1,#0
	bgt.w	EXPC1
*--Step 10.2
	fmove.s	#$BF800000,fp0	* fp0 is -1
	fmove.l	d0,fpcr
	fadd.s	#$00800000,fp0	* -1 + 2^(-126)
	bra	t_minx2

	xdef	setoxm1d
setoxm1d:
*--entry point for EXPM1(X), here X is denormalized
*--Step 0.
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* sgetexp():  returns the exponent portion of the input argument.
*	      The exponent bias is removed and the exponent value is
*	      returned as an extended precision number in fp0.
* sgetexpd(): handles denormalized numbers. 
*		
* sgetman():  extracts the mantissa of the input argument. The 
*	      mantissa is converted to an extended precision number w/ 
*	      an exponent of $3fff and is returned in fp0. The range of *
*	      the result is [1.0 - 2.0).
* sgetmand(): handles denormalized numbers.
*		
* INPUT *************************************************************** *
*	a0  = pointer to extended precision input
*		
* OUTPUT ************************************************************** *
*	fp0 = exponent(X) or mantissa(X)
*		
**-------------------------------------------------------------------------------------------------

	xdef	sgetexp
sgetexp:
	move.w	SRC_EX(a0),d0	* get the exponent
	bclr	#$f,d0	* clear the sign bit
	subi.w	#$3fff,d0	* subtract off the bias
	fmove.w	d0,fp0	* return exp in fp0
	blt.b	sgetexpn	* it's negative
	rts

sgetexpn:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

	xdef	sgetexpd
sgetexpd:
	bsr.l	norm	* normalize
	neg.w	d0	* new exp = -(shft amt)
	subi.w	#$3fff,d0	* subtract off the bias
	fmove.w	d0,fp0	* return exp in fp0
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

	xdef	sgetman
sgetman:
	move.w	SRC_EX(a0),d0	* get the exp
	ori.w	#$7fff,d0	* clear old exp
	bclr	#$e,d0	* make it the new exp +-3fff

* here, we build the result in a tmp location so as not to disturb the input
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6) * copy to tmp loc
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6) * copy to tmp loc
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* put new value back in fp0
	bmi.b	sgetmann	* it's negative
	rts

sgetmann:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

*
* For denormalized numbers, shift the mantissa until the j-bit = 1,
* then load the exponent with +/1 $3fff.
*
	xdef	sgetmand
sgetmand:
	bsr.l	norm	* normalize exponent
	bra.b	sgetman

**-------------------------------------------------------------------------------------------------
* scosh():  computes the hyperbolic cosine of a normalized input
* scoshd(): computes the hyperbolic cosine of a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************
*	fp0 = cosh(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic 
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	COSH	
*	1. If |X| > 16380 log2, go to 3.
*		
*	2. (|X| <= 16380 log2) Cosh(X) is obtained by the formulae
*	y = |X|, z = exp(Y), and
*	cosh(X) = (1/2)*( z + 1/z ).
*	Exit.	
*		
*	3. (|X| > 16380 log2). If |X| > 16480 log2, go to 5.
*		
*	4. (16380 log2 < |X| <= 16480 log2)
*	cosh(X) = sign(X) * exp(|X|)/2.
*	However, invoking exp(|X|) may cause premature 
*	overflow. Thus, we calculate sinh(X) as follows:
*	Y	:= |X|	
*	Fact	:=	2**(16380)
*	Y'	:= Y - 16381 log2
*	cosh(X) := Fact * exp(Y').
*	Exit.	
*		
*	5. (|X| > 16480 log2) sinh(X) must overflow. Return
*	Huge*Huge to generate overflow and an infinity with
*	the appropriate sign. Huge is the largest finite number
*	in extended format. Exit.
*		
**-------------------------------------------------------------------------------------------------

TWO16380:
	dc.l	$7FFB0000,$80000000,$00000000,$00000000

	xdef	scosh
scosh:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1,#$400CB167
	bgt.b	COSHBIG

*--THIS IS THE USUAL CASE, |X| < 16380 LOG2
*--COSH(X) = (1/2) * ( EXP(X) + 1/EXP(X) )

	fabs.x	fp0	* |X|

	move.l	d0,-(sp)
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save |X| to stack
	lea	(sp),a0	* pass ptr to |X|
	bsr	setox	* FP0 IS EXP(|X|)
	add.l	#$c,sp	* erase |X| from stack
	fmul.s	#$3F000000,fp0	* (1/2)EXP(|X|)
	move.l	(sp)+,d0

	fmove.s	#$3E800000,fp1	* (1/4)
	fdiv.x	fp0,fp1	* 1/(2 EXP(|X|))

	fmove.l	d0,fpcr
	move.b	#FADD_OP,d1	* last inst is ADD
	fadd.x	fp1,fp0
	bra	t_catch

COSHBIG:
	ICMP.l	d1,#$400CB2B3
	bgt.b	COSHHUGE

	fabs.x	fp0
	fsub.d	T1(pc),fp0	* (|X|-16381LOG2_LEAD)
	fsub.d	T2(pc),fp0	* |X| - 16381 LOG2, ACCURATE

	move.l	d0,-(sp)
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save fp0 to stack
	lea	(sp),a0	* pass ptr to fp0
	bsr	setox
	add.l	#$c,sp	* clear fp0 from stack
	move.l	(sp)+,d0

	fmove.l	d0,fpcr
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	TWO16380(pc),fp0
	bra	t_catch

COSHHUGE:
	bra	t_ovfl2

	xdef	scoshd
*--COSH(X) = 1 FOR DENORMALIZED X
scoshd:
	fmove.s	#$3F800000,fp0

	fmove.l	d0,fpcr
	fadd.s	#$00800000,fp0
	bra	t_pinx2

**-------------------------------------------------------------------------------------------------
* ssinh():  computes the hyperbolic sine of a normalized input
* ssinhd(): computes the hyperbolic sine of a denormalized input
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = sinh(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently *
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM *********************************************************** *
*		
*       SINH	
*       1. If |X| > 16380 log2, go to 3.
*		
*       2. (|X| <= 16380 log2) Sinh(X) is obtained by the formula
*               y = |X|, sgn = sign(X), and z = expm1(Y),
*               sinh(X) = sgn*(1/2)*( z + z/(1+z) ).
*          Exit.	
*		
*       3. If |X| > 16480 log2, go to 5.
*		
*       4. (16380 log2 < |X| <= 16480 log2)
*               sinh(X) = sign(X) * exp(|X|)/2.
*          However, invoking exp(|X|) may cause premature overflow.
*          Thus, we calculate sinh(X) as follows:
*             Y       := |X|	
*             sgn     := sign(X)	
*             sgnFact := sgn * 2**(16380)
*             Y'      := Y - 16381 log2	
*             sinh(X) := sgnFact * exp(Y').
*          Exit.	
*		
*       5. (|X| > 16480 log2) sinh(X) must overflow. Return
*          sign(X)*Huge*Huge to generate overflow and an infinity with
*          the appropriate sign. Huge is the largest finite number in
*          extended format. Exit.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	ssinh
ssinh:
	fmove.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	move.l	d1,a1	* save (compacted) operand
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1,#$400CB167
	bgt.b	SINHBIG

*--THIS IS THE USUAL CASE, |X| < 16380 LOG2
*--Y = |X|, Z = EXPM1(Y), SINH(X) = SIGN(X)*(1/2)*( Z + Z/(1+Z) )

	fabs.x	fp0	* Y = |X|

	movem.l	a1/d0,-(sp)	* {a1/d0}
	fmovem.x	fp0,-(sp)	* save Y on stack
	lea	(sp),a0	* pass ptr to Y
	clr.l	d0
	bsr	setoxm1	* FP0 IS Z = EXPM1(Y)
	add.l	#$c,sp	* clear Y from stack
	fmove.l	#0,fpcr
	movem.l	(sp)+,a1/d0	* {a1/d0}

	fmove.x	fp0,fp1
	fadd.s	#$3F800000,fp1	* 1+Z
	fmove.x	fp0,-(sp)
	fdiv.x	fp1,fp0	* Z/(1+Z)
	move.l	a1,d1
	and.l	#$80000000,d1
	or.l	#$3F000000,d1
	fadd.x	(sp)+,fp0
	move.l	d1,-(sp)

	fmove.l	d0,fpcr
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.s	(sp)+,fp0	* last fp inst - possible exceptions set
	bra	t_catch

SINHBIG:
	ICMP.l	d1,#$400CB2B3
	bgt	t_ovfl
	fabs.x	fp0
	fsub.d	T1(pc),fp0	* (|X|-16381LOG2_LEAD)
	move.l	#0,-(sp)
	move.l	#$80000000,-(sp)
	move.l	a1,d1
	and.l	#$80000000,d1
	or.l	#$7FFB0000,d1
	move.l	d1,-(sp)	* EXTENDED FMT
	fsub.d	T2(pc),fp0	* |X| - 16381 LOG2, ACCURATE

	move.l	d0,-(sp)
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save fp0 on stack
	lea	(sp),a0	* pass ptr to fp0
	bsr	setox
	add.l	#$c,sp	* clear fp0 from stack

	move.l	(sp)+,d0
	fmove.l	d0,fpcr
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	(sp)+,fp0	* possible exception
	bra	t_catch

	xdef	ssinhd
*--SINH(X) = X FOR DENORMALIZED X
ssinhd:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* stanh():  computes the hyperbolic tangent of a normalized input
* stanhd(): computes the hyperbolic tangent of a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************
*	fp0 = tanh(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently *
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	TANH	
*	1. If |X| >= (5/2) log2 or |X| <= 2**(-40), go to 3.
*		
*	2. (2**(-40) < |X| < (5/2) log2) Calculate tanh(X) by
*	sgn := sign(X), y := 2|X|, z := expm1(Y), and
*	tanh(X) = sgn*( z/(2+z) ).
*	Exit.	
*		
*	3. (|X| <= 2**(-40) or |X| >= (5/2) log2). If |X| < 1,
*	go to 7.	
*		
*	4. (|X| >= (5/2) log2) If |X| >= 50 log2, go to 6.
*		
*	5. ((5/2) log2 <= |X| < 50 log2) Calculate tanh(X) by
*	sgn := sign(X), y := 2|X|, z := exp(Y),
*	tanh(X) = sgn - [ sgn*2/(1+z) ].
*	Exit.	
*		
*	6. (|X| >= 50 log2) Tanh(X) = +-1 (round to nearest). Thus, we
*	calculate Tanh(X) by	
*	sgn := sign(X), Tiny := 2**(-126),
*	tanh(X) := sgn - sgn*Tiny.
*	Exit.	
*		
*	7. (|X| < 2**(-40)). Tanh(X) = X.	Exit.
*		
**-------------------------------------------------------------------------------------------------

*X	equ	EXC_LV+FP_SCR0
*XFRAC	equ	X+4
SGN	equ	EXC_LV+L_SCR3
V	equ	EXC_LV+FP_SCR0

	xdef	stanh
stanh:
	fmove.x	(a0),fp0	* LOAD INPUT

	fmove.x	fp0,X(a6)
	move.l	(a0),d1
	move.w	4(a0),d1
	move.l	d1,X(a6)
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1, #$3fd78000	* is |X| < 2^(-40)?
	blt.w	TANHBORS	* yes
	ICMP.l	d1, #$3fffddce	* is |X| > (5/2)LOG2?
	bgt.w	TANHBORS	* yes

*--THIS IS THE USUAL CASE
*--Y = 2|X|, Z = EXPM1(Y), TANH(X) = SIGN(X) * Z / (Z+2).

	move.l	X(a6),d1
	move.l	d1,SGN(a6)
	and.l	#$7FFF0000,d1
	add.l	#$00010000,d1	* EXPONENT OF 2|X|
	move.l	d1,X(a6)
	and.l	#$80000000,SGN(a6)
	fmove.x	X(a6),fp0	* FP0 IS Y = 2|X|

	move.l	d0,-(sp)
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save Y on stack
	lea	(sp),a0	* pass ptr to Y
	bsr	setoxm1	* FP0 IS Z = EXPM1(Y)
	add.l	#$c,sp	* clear Y from stack
	move.l	(sp)+,d0

	fmove.x	fp0,fp1
	fadd.s	#$40000000,fp1	* Z+2
	move.l	SGN(a6),d1
	fmove.x	fp1,V(a6)
	eor.l	d1,V(a6)

	fmove.l	d0,fpcr	* restore users round prec,mode
	fdiv.x	V(a6),fp0
	bra	t_inx2

TANHBORS:
	ICMP.l	d1,#$3FFF8000
	blt.w	TANHSM

	ICMP.l	d1,#$40048AA1
	bgt.w	TANHHUGE

*-- (5/2) LOG2 < |X| < 50 LOG2,
*--TANH(X) = 1 - (2/[EXP(2X)+1]). LET Y = 2|X|, SGN = SIGN(X),
*--TANH(X) = SGN -	SGN*2/[EXP(Y)+1].

	move.l	X(a6),d1
	move.l	d1,SGN(a6)
	and.l	#$7FFF0000,d1
	add.l	#$00010000,d1	* EXPO OF 2|X|
	move.l	d1,X(a6)	* Y = 2|X|
	and.l	#$80000000,SGN(a6)
	move.l	SGN(a6),d1
	fmove.x	X(a6),fp0	* Y = 2|X|

	move.l	d0,-(sp)
	clr.l	d0
	fmovem.x	fp0,-(sp)	* save Y on stack
	lea	(sp),a0	* pass ptr to Y
	bsr	setox	* FP0 IS EXP(Y)
	add.l	#$c,sp	* clear Y from stack
	move.l	(sp)+,d0
	move.l	SGN(a6),d1
	fadd.s	#$3F800000,fp0	* EXP(Y)+1

	eor.l	#$c0000000,d1	* -SIGN(X)*2
	fmove.s	d1,fp1	* -SIGN(X)*2 IN SGL FMT
	fdiv.x	fp0,fp1	* -SIGN(X)2 / [EXP(Y)+1 ]

	move.l	SGN(a6),d1
	or.l	#$3F800000,d1	* SGN
	fmove.s	d1,fp0	* SGN IN SGL FMT

	fmove.l	d0,fpcr	* restore users round prec,mode
	move.b	#FADD_OP,d1	* last inst is ADD
	fadd.x	fp1,fp0
	bra	t_inx2

TANHSM:
	fmove.l	d0,fpcr	* restore users round prec,mode
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	X(a6),fp0	* last inst - possible exception set
	bra	t_catch

*---RETURN SGN(X) - SGN(X)EPS
TANHHUGE:
	move.l	X(a6),d1
	and.l	#$80000000,d1
	or.l	#$3F800000,d1
	fmove.s	d1,fp0
	and.l	#$80000000,d1
	eor.l	#$80800000,d1	* -SIGN(X)*EPS

	fmove.l	d0,fpcr	* restore users round prec,mode
	fadd.s	d1,fp0
	bra	t_inx2

	xdef	stanhd
*--TANH(X) = X FOR DENORMALIZED X
stanhd:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* slogn():    computes the natural logarithm of a normalized input
* slognd():   computes the natural logarithm of a denormalized input
* slognp1():  computes the log(1+X) of a normalized input
* slognp1d(): computes the log(1+X) of a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************
*	fp0 = log(X) or log(1+X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 2 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*	LOGN:	
*	Step 1. If |X-1| < 1/16, approximate log(X) by an odd 
*	polynomial in u, where u = 2(X-1)/(X+1). Otherwise, 
*	move on to Step 2.	
*		
*	Step 2. X = 2**k * Y where 1 <= Y < 2. Define F to be the first
*	seven significant bits of Y plus 2**(-7), i.e. 
*	F = 1.xxxxxx1 in base 2 where the six "x" match those 
*	of Y. Note that |Y-F| <= 2**(-7).
*		
*	Step 3. Define u = (Y-F)/F. Approximate log(1+u) by a 
*	polynomial in u, log(1+u) = poly.
*		
*	Step 4. Reconstruct 	
*	log(X) = log( 2**k * Y ) = k*log(2) + log(F) + log(1+u)
*	by k*log(2) + (log(F) + poly). The values of log(F) are
*	calculated beforehand and stored in the program.
*		
*	lognp1:	
*	Step 1: If |X| < 1/16, approximate log(1+X) by an odd 
*	polynomial in u where u = 2X/(2+X). Otherwise, move on
*	to Step 2.	
*		
*	Step 2: Let 1+X = 2**k * Y, where 1 <= Y < 2. Define F as done
*	in Step 2 of the algorithm for LOGN and compute 
*	log(1+X) as k*log(2) + log(F) + poly where poly 
*	approximates log(1+u), u = (Y-F)/F. 
*		
*	Implementation Notes:	
*	Note 1. There are 64 different possible values for F, thus 64 
*	log(F)'s need to be tabulated. Moreover, the values of
*	1/F are also tabulated so that the division in (Y-F)/F
*	can be performed by a multiplication.
*		
*	Note 2. In Step 2 of lognp1, in order to preserved accuracy, 
*	the value Y-F has to be calculated carefully when 
*	1/2 <= X < 3/2. 	
*		
*	Note 3. To fully exploit the pipeline, polynomials are usually 
*	separated into two parts evaluated independently before
*	being added up.	
*		
**-------------------------------------------------------------------------------------------------
LOGOF2:
	dc.l	$3FFE0000,$B17217F7,$D1CF79AC,$00000000

one:
	dc.l	$3F800000
zero:
	dc.l	$00000000
infty:
	dc.l	$7F800000
negone:
	dc.l	$BF800000

LOGA6:
	dc.l	$3FC2499A,$B5E4040B
LOGA5:
	dc.l	$BFC555B5,$848CB7DB

LOGA4:
	dc.l	$3FC99999,$987D8730
LOGA3:
	dc.l	$BFCFFFFF,$FF6F7E97

LOGA2:
	dc.l	$3FD55555,$555555A4
LOGA1:
	dc.l	$BFE00000,$00000008

LOGB5:
	dc.l	$3F175496,$ADD7DAD6
LOGB4:
	dc.l	$3F3C71C2,$FE80C7E0

LOGB3:
	dc.l	$3F624924,$928BCCFF
LOGB2:
	dc.l	$3F899999,$999995EC

LOGB1:
	dc.l	$3FB55555,$55555555
TWO:
	dc.l	$40000000,$00000000

LTHOLD:
	dc.l	$3f990000,$80000000,$00000000,$00000000

LOGTBL:
	dc.l	$3FFE0000,$FE03F80F,$E03F80FE,$00000000
	dc.l	$3FF70000,$FF015358,$833C47E2,$00000000
	dc.l	$3FFE0000,$FA232CF2,$52138AC0,$00000000
	dc.l	$3FF90000,$BDC8D83E,$AD88D549,$00000000
	dc.l	$3FFE0000,$F6603D98,$0F6603DA,$00000000
	dc.l	$3FFA0000,$9CF43DCF,$F5EAFD48,$00000000
	dc.l	$3FFE0000,$F2B9D648,$0F2B9D65,$00000000
	dc.l	$3FFA0000,$DA16EB88,$CB8DF614,$00000000
	dc.l	$3FFE0000,$EF2EB71F,$C4345238,$00000000
	dc.l	$3FFB0000,$8B29B775,$1BD70743,$00000000
	dc.l	$3FFE0000,$EBBDB2A5,$C1619C8C,$00000000
	dc.l	$3FFB0000,$A8D839F8,$30C1FB49,$00000000
	dc.l	$3FFE0000,$E865AC7B,$7603A197,$00000000
	dc.l	$3FFB0000,$C61A2EB1,$8CD907AD,$00000000
	dc.l	$3FFE0000,$E525982A,$F70C880E,$00000000
	dc.l	$3FFB0000,$E2F2A47A,$DE3A18AF,$00000000
	dc.l	$3FFE0000,$E1FC780E,$1FC780E2,$00000000
	dc.l	$3FFB0000,$FF64898E,$DF55D551,$00000000
	dc.l	$3FFE0000,$DEE95C4C,$A037BA57,$00000000
	dc.l	$3FFC0000,$8DB956A9,$7B3D0148,$00000000
	dc.l	$3FFE0000,$DBEB61EE,$D19C5958,$00000000
	dc.l	$3FFC0000,$9B8FE100,$F47BA1DE,$00000000
	dc.l	$3FFE0000,$D901B203,$6406C80E,$00000000
	dc.l	$3FFC0000,$A9372F1D,$0DA1BD17,$00000000
	dc.l	$3FFE0000,$D62B80D6,$2B80D62C,$00000000
	dc.l	$3FFC0000,$B6B07F38,$CE90E46B,$00000000
	dc.l	$3FFE0000,$D3680D36,$80D3680D,$00000000
	dc.l	$3FFC0000,$C3FD0329,$06488481,$00000000
	dc.l	$3FFE0000,$D0B69FCB,$D2580D0B,$00000000
	dc.l	$3FFC0000,$D11DE0FF,$15AB18CA,$00000000
	dc.l	$3FFE0000,$CE168A77,$25080CE1,$00000000
	dc.l	$3FFC0000,$DE1433A1,$6C66B150,$00000000
	dc.l	$3FFE0000,$CB8727C0,$65C393E0,$00000000
	dc.l	$3FFC0000,$EAE10B5A,$7DDC8ADD,$00000000
	dc.l	$3FFE0000,$C907DA4E,$871146AD,$00000000
	dc.l	$3FFC0000,$F7856E5E,$E2C9B291,$00000000
	dc.l	$3FFE0000,$C6980C69,$80C6980C,$00000000
	dc.l	$3FFD0000,$82012CA5,$A68206D7,$00000000
	dc.l	$3FFE0000,$C4372F85,$5D824CA6,$00000000
	dc.l	$3FFD0000,$882C5FCD,$7256A8C5,$00000000
	dc.l	$3FFE0000,$C1E4BBD5,$95F6E947,$00000000
	dc.l	$3FFD0000,$8E44C60B,$4CCFD7DE,$00000000
	dc.l	$3FFE0000,$BFA02FE8,$0BFA02FF,$00000000
	dc.l	$3FFD0000,$944AD09E,$F4351AF6,$00000000
	dc.l	$3FFE0000,$BD691047,$07661AA3,$00000000
	dc.l	$3FFD0000,$9A3EECD4,$C3EAA6B2,$00000000
	dc.l	$3FFE0000,$BB3EE721,$A54D880C,$00000000
	dc.l	$3FFD0000,$A0218434,$353F1DE8,$00000000
	dc.l	$3FFE0000,$B92143FA,$36F5E02E,$00000000
	dc.l	$3FFD0000,$A5F2FCAB,$BBC506DA,$00000000
	dc.l	$3FFE0000,$B70FBB5A,$19BE3659,$00000000
	dc.l	$3FFD0000,$ABB3B8BA,$2AD362A5,$00000000
	dc.l	$3FFE0000,$B509E68A,$9B94821F,$00000000
	dc.l	$3FFD0000,$B1641795,$CE3CA97B,$00000000
	dc.l	$3FFE0000,$B30F6352,$8917C80B,$00000000
	dc.l	$3FFD0000,$B7047551,$5D0F1C61,$00000000
	dc.l	$3FFE0000,$B11FD3B8,$0B11FD3C,$00000000
	dc.l	$3FFD0000,$BC952AFE,$EA3D13E1,$00000000
	dc.l	$3FFE0000,$AF3ADDC6,$80AF3ADE,$00000000
	dc.l	$3FFD0000,$C2168ED0,$F458BA4A,$00000000
	dc.l	$3FFE0000,$AD602B58,$0AD602B6,$00000000
	dc.l	$3FFD0000,$C788F439,$B3163BF1,$00000000
	dc.l	$3FFE0000,$AB8F69E2,$8359CD11,$00000000
	dc.l	$3FFD0000,$CCECAC08,$BF04565D,$00000000
	dc.l	$3FFE0000,$A9C84A47,$A07F5638,$00000000
	dc.l	$3FFD0000,$D2420487,$2DD85160,$00000000
	dc.l	$3FFE0000,$A80A80A8,$0A80A80B,$00000000
	dc.l	$3FFD0000,$D7894992,$3BC3588A,$00000000
	dc.l	$3FFE0000,$A655C439,$2D7B73A8,$00000000
	dc.l	$3FFD0000,$DCC2C4B4,$9887DACC,$00000000
	dc.l	$3FFE0000,$A4A9CF1D,$96833751,$00000000
	dc.l	$3FFD0000,$E1EEBD3E,$6D6A6B9E,$00000000
	dc.l	$3FFE0000,$A3065E3F,$AE7CD0E0,$00000000
	dc.l	$3FFD0000,$E70D785C,$2F9F5BDC,$00000000
	dc.l	$3FFE0000,$A16B312E,$A8FC377D,$00000000
	dc.l	$3FFD0000,$EC1F392C,$5179F283,$00000000
	dc.l	$3FFE0000,$9FD809FD,$809FD80A,$00000000
	dc.l	$3FFD0000,$F12440D3,$E36130E6,$00000000
	dc.l	$3FFE0000,$9E4CAD23,$DD5F3A20,$00000000
	dc.l	$3FFD0000,$F61CCE92,$346600BB,$00000000
	dc.l	$3FFE0000,$9CC8E160,$C3FB19B9,$00000000
	dc.l	$3FFD0000,$FB091FD3,$8145630A,$00000000
	dc.l	$3FFE0000,$9B4C6F9E,$F03A3CAA,$00000000
	dc.l	$3FFD0000,$FFE97042,$BFA4C2AD,$00000000
	dc.l	$3FFE0000,$99D722DA,$BDE58F06,$00000000
	dc.l	$3FFE0000,$825EFCED,$49369330,$00000000
	dc.l	$3FFE0000,$9868C809,$868C8098,$00000000
	dc.l	$3FFE0000,$84C37A7A,$B9A905C9,$00000000
	dc.l	$3FFE0000,$97012E02,$5C04B809,$00000000
	dc.l	$3FFE0000,$87224C2E,$8E645FB7,$00000000
	dc.l	$3FFE0000,$95A02568,$095A0257,$00000000
	dc.l	$3FFE0000,$897B8CAC,$9F7DE298,$00000000
	dc.l	$3FFE0000,$94458094,$45809446,$00000000
	dc.l	$3FFE0000,$8BCF55DE,$C4CD05FE,$00000000
	dc.l	$3FFE0000,$92F11384,$0497889C,$00000000
	dc.l	$3FFE0000,$8E1DC0FB,$89E125E5,$00000000
	dc.l	$3FFE0000,$91A2B3C4,$D5E6F809,$00000000
	dc.l	$3FFE0000,$9066E68C,$955B6C9B,$00000000
	dc.l	$3FFE0000,$905A3863,$3E06C43B,$00000000
	dc.l	$3FFE0000,$92AADE74,$C7BE59E0,$00000000
	dc.l	$3FFE0000,$8F1779D9,$FDC3A219,$00000000
	dc.l	$3FFE0000,$94E9BFF6,$15845643,$00000000
	dc.l	$3FFE0000,$8DDA5202,$37694809,$00000000
	dc.l	$3FFE0000,$9723A1B7,$20134203,$00000000
	dc.l	$3FFE0000,$8CA29C04,$6514E023,$00000000
	dc.l	$3FFE0000,$995899C8,$90EB8990,$00000000
	dc.l	$3FFE0000,$8B70344A,$139BC75A,$00000000
	dc.l	$3FFE0000,$9B88BDAA,$3A3DAE2F,$00000000
	dc.l	$3FFE0000,$8A42F870,$5669DB46,$00000000
	dc.l	$3FFE0000,$9DB4224F,$FFE1157C,$00000000
	dc.l	$3FFE0000,$891AC73A,$E9819B50,$00000000
	dc.l	$3FFE0000,$9FDADC26,$8B7A12DA,$00000000
	dc.l	$3FFE0000,$87F78087,$F78087F8,$00000000
	dc.l	$3FFE0000,$A1FCFF17,$CE733BD4,$00000000
	dc.l	$3FFE0000,$86D90544,$7A34ACC6,$00000000
	dc.l	$3FFE0000,$A41A9E8F,$5446FB9F,$00000000
	dc.l	$3FFE0000,$85BF3761,$2CEE3C9B,$00000000
	dc.l	$3FFE0000,$A633CD7E,$6771CD8B,$00000000
	dc.l	$3FFE0000,$84A9F9C8,$084A9F9D,$00000000
	dc.l	$3FFE0000,$A8489E60,$0B435A5E,$00000000
	dc.l	$3FFE0000,$83993052,$3FBE3368,$00000000
	dc.l	$3FFE0000,$AA59233C,$CCA4BD49,$00000000
	dc.l	$3FFE0000,$828CBFBE,$B9A020A3,$00000000
	dc.l	$3FFE0000,$AC656DAE,$6BCC4985,$00000000
	dc.l	$3FFE0000,$81848DA8,$FAF0D277,$00000000
	dc.l	$3FFE0000,$AE6D8EE3,$60BB2468,$00000000
	dc.l	$3FFE0000,$80808080,$80808081,$00000000
	dc.l	$3FFE0000,$B07197A2,$3C46C654,$00000000

ADJK	equ	EXC_LV+L_SCR1

*X	equ	EXC_LV+FP_SCR0
*XDCARE	equ	X+2
*XFRAC	equ	X+4

F	equ	EXC_LV+FP_SCR1
FFRAC	equ	F+4

KLOG2	equ	EXC_LV+FP_SCR0

SAVEU	equ	EXC_LV+FP_SCR0

	xdef	slogn
*--ENTRY POINT FOR LOG(X) FOR X FINITE, NON-ZERO, NOT NAN'S
slogn:
	fmove.x	(a0),fp0	* LOAD INPUT
	move.l	#$00000000,ADJK(a6)

LOGBGN:
*--FPCR SAVED AND CLEARED, INPUT IS 2^(ADJK)*FP0, FP0 CONTAINS
*--A FINITE, NON-ZERO, NORMALIZED NUMBER.

	move.l	(a0),d1
	move.w	4(a0),d1

	move.l	(a0),X(a6)
	move.l	4(a0),X+4(a6)
	move.l	8(a0),X+8(a6)

	ICMP.l	d1,#0	* CHECK IF X IS NEGATIVE
	blt.w	LOGNEG	* LOG OF NEGATIVE ARGUMENT IS INVALID
* X IS POSITIVE, CHECK IF X IS NEAR 1
	ICMP.l	d1,#$3ffef07d 	* IS X < 15/16?
	blt.b	LOGMAIN	* YES
	ICMP.l	d1,#$3fff8841 	* IS X > 17/16?
	ble.w	LOGNEAR1	* NO

LOGMAIN:
*--THIS SHOULD BE THE USUAL CASE, X NOT VERY CLOSE TO 1

*--X = 2^(K) * Y, 1 <= Y < 2. THUS, Y = 1.XXXXXXXX....XX IN BINARY.
*--WE DEFINE F = 1.XXXXXX1, I.E. FIRST 7 BITS OF Y AND ATTACH A 1.
*--THE IDEA IS THAT LOG(X) = K*LOG2 + LOG(Y)
*--	 = K*LOG2 + LOG(F) + LOG(1 + (Y-F)/F).
*--NOTE THAT U = (Y-F)/F IS VERY SMALL AND THUS APPROXIMATING
*--LOG(1+U) CAN BE VERY EFFICIENT.
*--ALSO NOTE THAT THE VALUE 1/F IS STORED IN A TABLE SO THAT NO
*--DIVISION IS NEEDED TO CALCULATE (Y-F)/F. 

*--GET K, Y, F, AND ADDRESS OF 1/F.
	asr.l	#8,d1
	asr.l	#8,d1	* SHIFTED 16 BITS, BIASED EXPO. OF X
	sub.l	#$3FFF,d1	* THIS IS K
	add.l	ADJK(a6),d1	* ADJUST K, ORIGINAL INPUT MAY BE  DENORM.
	lea	LOGTBL(pc),a0	* BASE ADDRESS OF 1/F AND LOG(F)
	fmove.l	d1,fp1	* CONVERT K TO FLOATING-POINT FORMAT

*--WHILE THE CONVERSION IS GOING ON, WE GET F AND ADDRESS OF 1/F
	move.l	#$3FFF0000,X(a6)	* X IS NOW Y, I.E. 2^(-K)*X
	move.l	XFRAC(a6),FFRAC(a6)
	and.l	#$FE000000,FFRAC(a6)	* FIRST 7 BITS OF Y
	or.l	#$01000000,FFRAC(a6)	* GET F: ATTACH A 1 AT THE EIGHTH BIT
	move.l	FFRAC(a6),d1	* READY TO GET ADDRESS OF 1/F
	and.l	#$7E000000,d1
	asr.l	#8,d1
	asr.l	#8,d1
	asr.l	#4,d1	* SHIFTED 20, D0 IS THE DISPLACEMENT
	add.l	d1,a0	* A0 IS THE ADDRESS FOR 1/F

	fmove.x	X(a6),fp0
	move.l	#$3fff0000,F(a6)
	clr.l	F+8(a6)
	fsub.x	F(a6),fp0	* Y-F
	fmovem.x	fp2-fp3,-(sp)	* SAVE FP2-3 WHILE FP0 IS NOT READY
*--SUMMARY: FP0 IS Y-F, A0 IS ADDRESS OF 1/F, FP1 IS K
*--REGISTERS SAVED: FPCR, FP1, FP2

LP1CONT1:
*--AN RE-ENTRY POINT FOR LOGNP1
	fmul.x	(a0),fp0	* FP0 IS U = (Y-F)/F
	fmul.x	LOGOF2(pc),fp1	* GET K*LOG2 WHILE FP0 IS NOT READY
	fmove.x	fp0,fp2
	fmul.x	fp2,fp2	* FP2 IS V=U*U
	fmove.x	fp1,KLOG2(a6)	* PUT K*LOG2 IN MEMEORY, FREE FP1

*--LOG(1+U) IS APPROXIMATED BY
*--U + V*(A1+U*(A2+U*(A3+U*(A4+U*(A5+U*A6))))) WHICH IS
*--[U + V*(A1+V*(A3+V*A5))]  +  [U*V*(A2+V*(A4+V*A6))]

	fmove.x	fp2,fp3
	fmove.x	fp2,fp1

	fmul.d	LOGA6(pc),fp1	* V*A6
	fmul.d	LOGA5(pc),fp2	* V*A5

	fadd.d	LOGA4(pc),fp1	* A4+V*A6
	fadd.d	LOGA3(pc),fp2	* A3+V*A5

	fmul.x	fp3,fp1	* V*(A4+V*A6)
	fmul.x	fp3,fp2	* V*(A3+V*A5)

	fadd.d	LOGA2(pc),fp1	* A2+V*(A4+V*A6)
	fadd.d	LOGA1(pc),fp2	* A1+V*(A3+V*A5)

	fmul.x	fp3,fp1	* V*(A2+V*(A4+V*A6))
	add.l	#16,a0	* ADDRESS OF LOG(F)
	fmul.x	fp3,fp2	* V*(A1+V*(A3+V*A5))

	fmul.x	fp0,fp1	* U*V*(A2+V*(A4+V*A6))
	fadd.x	fp2,fp0	* U+V*(A1+V*(A3+V*A5))

	fadd.x	(a0),fp1	* LOG(F)+U*V*(A2+V*(A4+V*A6))
	fmovem.x	(sp)+,fp2-fp3	* RESTORE FP2-3
	fadd.x	fp1,fp0	* FP0 IS LOG(F) + LOG(1+U)

	fmove.l	d0,fpcr
	fadd.x	KLOG2(a6),fp0	* FINAL ADD
	bra	t_inx2


LOGNEAR1:

* if the input is exactly equal to one, then exit through ld_pzero.
* if these 2 lines weren't here, the correct answer would be returned
* but the INEX2 bit would be set.
	fcmp.b	#1,fp0	* is it equal to one?
	fbeq.l	ld_pzero	* yes

*--REGISTERS SAVED: FPCR, FP1. FP0 CONTAINS THE INPUT.
	fmove.x	fp0,fp1
	fsub.s	one(pc),fp1	* FP1 IS X-1
	fadd.s	one(pc),fp0	* FP0 IS X+1
	fadd.x	fp1,fp1	* FP1 IS 2(X-1)
*--LOG(X) = LOG(1+U/2)-LOG(1-U/2) WHICH IS AN ODD POLYNOMIAL
*--IN U, U = 2(X-1)/(X+1) = FP1/FP0

LP1CONT2:
*--THIS IS AN RE-ENTRY POINT FOR LOGNP1
	fdiv.x	fp0,fp1	* FP1 IS U
	fmovem.x	fp2-fp3,-(sp)	* SAVE FP2-3
*--REGISTERS SAVED ARE NOW FPCR,FP1,FP2,FP3
*--LET V=U*U, W=V*V, CALCULATE
*--U + U*V*(B1 + V*(B2 + V*(B3 + V*(B4 + V*B5)))) BY
*--U + U*V*(  [B1 + W*(B3 + W*B5)]  +  [V*(B2 + W*B4)]  )
	fmove.x	fp1,fp0
	fmul.x	fp0,fp0	* FP0 IS V
	fmove.x	fp1,SAVEU(a6)	* STORE U IN MEMORY, FREE FP1
	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS W

	fmove.d	LOGB5(pc),fp3
	fmove.d	LOGB4(pc),fp2

	fmul.x	fp1,fp3	* W*B5
	fmul.x	fp1,fp2	* W*B4

	fadd.d	LOGB3(pc),fp3	* B3+W*B5
	fadd.d	LOGB2(pc),fp2	* B2+W*B4

	fmul.x	fp3,fp1	* W*(B3+W*B5), FP3 RELEASED

	fmul.x	fp0,fp2	* V*(B2+W*B4)

	fadd.d	LOGB1(pc),fp1	* B1+W*(B3+W*B5)
	fmul.x	SAVEU(a6),fp0	* FP0 IS U*V

	fadd.x	fp2,fp1	* B1+W*(B3+W*B5) + V*(B2+W*B4), FP2 RELEASED
	fmovem.x	(sp)+,fp2-fp3	* FP2-3 RESTORED

	fmul.x	fp1,fp0	* U*V*( [B1+W*(B3+W*B5)] + [V*(B2+W*B4)] )

	fmove.l	d0,fpcr
	fadd.x	SAVEU(a6),fp0
	bra	t_inx2

*--REGISTERS SAVED FPCR. LOG(-VE) IS INVALID
LOGNEG:
	bra	t_operr

	xdef	slognd
slognd:
*--ENTRY POINT FOR LOG(X) FOR DENORMALIZED INPUT

	move.l	#-100,ADJK(a6)	* INPUT = 2^(ADJK) * FP0

*----normalize the input value by left shifting k bits (k to be determined
*----below), adjusting exponent and storing -k to  ADJK
*----the value TWOTO100 is no longer needed.
*----Note that this code assumes the denormalized input is NON-ZERO.

	movem.l	d2-d7,-(sp)	* save some registers  {d2-d7}
	move.l	(a0),d3	* D3 is exponent of smallest norm. *
	move.l	4(a0),d4
	move.l	8(a0),d5	* (D4,D5) is (Hi_X,Lo_X)
	clr.l	d2	* D2 used for holding K

	tst.l	d4
	bne.b	Hi_not0

Hi_0:
	move.l	d5,d4
	clr.l	d5
	move.l	#32,d2
	clr.l	d6
	bfffo	d4{0:32},d6
	lsl.l	d6,d4
	add.l	d6,d2	* (D3,D4,D5) is normalized

	move.l	d3,X(a6)
	move.l	d4,XFRAC(a6)
	move.l	d5,XFRAC+4(a6)
	neg.l	d2
	move.l	d2,ADJK(a6)
	fmove.x	X(a6),fp0
	movem.l	(sp)+,d2-d7	* restore registers {d2-d7}
	lea	X(a6),a0
	bra.w	LOGBGN	* begin regular log(X)

Hi_not0:
	clr.l	d6
	bfffo	d4{0:32},d6	* find first 1
	move.l	d6,d2	* get k
	lsl.l	d6,d4
	move.l	d5,d7	* a copy of D5
	lsl.l	d6,d5
	neg.l	d6
	add.l	#32,d6
	lsr.l	d6,d7
	or.l	d7,d4	* (D3,D4,D5) normalized

	move.l	d3,X(a6)
	move.l	d4,XFRAC(a6)
	move.l	d5,XFRAC+4(a6)
	neg.l	d2
	move.l	d2,ADJK(a6)
	fmove.x	X(a6),fp0
	movem.l	(sp)+,d2-d7	* restore registers {d2-d7}
	lea	X(a6),a0
	bra.w	LOGBGN	* begin regular log(X)

	xdef	slognp1
*--ENTRY POINT FOR LOG(1+X) FOR X FINITE, NON-ZERO, NOT NAN'S
slognp1:
	fmove.x	(a0),fp0	* LOAD INPUT
	fabs.x	fp0	* test magnitude
	fcmp.x	LTHOLD(pc),fp0	* compare with min threshold
	fbgt.w	LP1REAL	* if greater, continue
	fmove.l	d0,fpcr
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	(a0),fp0	* return signed argument
	bra	t_catch

LP1REAL:
	fmove.x	(a0),fp0	* LOAD INPUT
	move.l	#$00000000,ADJK(a6)
	fmove.x	fp0,fp1	* FP1 IS INPUT Z
	fadd.s	one(pc),fp0	* X := ROUND(1+Z)
	fmove.x	fp0,X(a6)
	move.w	XFRAC(a6),XDCARE(a6)
	move.l	X(a6),d1
	ICMP.l	d1,#0
	ble.w	LP1NEG0	* LOG OF ZERO OR -VE
	ICMP.l	d1,#$3ffe8000 	* IS BOUNDS [1/2,3/2]?
	blt.w	LOGMAIN
	ICMP.l	d1,#$3fffc000
	bgt.w	LOGMAIN 
*--IF 1+Z > 3/2 OR 1+Z < 1/2, THEN X, WHICH IS ROUNDING 1+Z,
*--CONTAINS AT LEAST 63 BITS OF INFORMATION OF Z. IN THAT CASE,
*--SIMPLY INVOKE LOG(X) FOR LOG(1+Z).

LP1NEAR1:
*--NEXT SEE IF EXP(-1/16) < X < EXP(1/16)
	ICMP.l	d1,#$3ffef07d
	blt.w	LP1CARE
	ICMP.l	d1,#$3fff8841
	bgt.w	LP1CARE

LP1ONE16:
*--EXP(-1/16) < X < EXP(1/16). LOG(1+Z) = LOG(1+U/2) - LOG(1-U/2)
*--WHERE U = 2Z/(2+Z) = 2Z/(1+X).
	fadd.x	fp1,fp1	* FP1 IS 2Z
	fadd.s	one(pc),fp0	* FP0 IS 1+X
*--U = FP1/FP0
	bra.w	LP1CONT2

LP1CARE:
*--HERE WE USE THE USUAL TABLE DRIVEN APPROACH. CARE HAS TO BE
*--TAKEN BECAUSE 1+Z CAN HAVE 67 BITS OF INFORMATION AND WE MUST
*--PRESERVE ALL THE INFORMATION. BECAUSE 1+Z IS IN [1/2,3/2],
*--THERE ARE ONLY TWO CASES.
*--CASE 1: 1+Z < 1, THEN K = -1 AND Y-F = (2-F) + 2Z
*--CASE 2: 1+Z > 1, THEN K = 0  AND Y-F = (1-F) + Z
*--ON RETURNING TO LP1CONT1, WE MUST HAVE K IN FP1, ADDRESS OF
*--(1/F) IN A0, Y-F IN FP0, AND FP2 SAVED.

	move.l	XFRAC(a6),FFRAC(a6)
	and.l	#$FE000000,FFRAC(a6)
	or.l	#$01000000,FFRAC(a6)	* F OBTAINED
	ICMP.l	d1,#$3FFF8000	* SEE IF 1+Z > 1
	bge.b	KISZERO

KISNEG1:
	fmove.s	TWO(pc),fp0
	move.l	#$3fff0000,F(a6)
	clr.l	F+8(a6)
	fsub.x	F(a6),fp0	* 2-F
	move.l	FFRAC(a6),d1
	and.l	#$7E000000,d1
	asr.l	#8,d1
	asr.l	#8,d1
	asr.l	#4,d1	* D0 CONTAINS DISPLACEMENT FOR 1/F
	fadd.x	fp1,fp1	* GET 2Z
	fmovem.x	fp2-fp3,-(sp)	* SAVE FP2  {fp2/fp3}
	fadd.x	fp1,fp0	* FP0 IS Y-F = (2-F)+2Z
	lea	LOGTBL(pc),a0	* A0 IS ADDRESS OF 1/F
	add.l	d1,a0
	fmove.s	negone(pc),fp1	* FP1 IS K = -1
	bra.w	LP1CONT1

KISZERO:
	fmove.s	one(pc),fp0
	move.l	#$3fff0000,F(a6)
	clr.l	F+8(a6)
	fsub.x	F(a6),fp0	* 1-F
	move.l	FFRAC(a6),d1
	and.l	#$7E000000,d1
	asr.l	#8,d1
	asr.l	#8,d1
	asr.l	#4,d1
	fadd.x	fp1,fp0	* FP0 IS Y-F
	fmovem.x	fp2-fp3,-(sp)	* FP2 SAVED {fp2/fp3}
	lea	LOGTBL(pc),a0
	add.l	d1,a0	* A0 IS ADDRESS OF 1/F
	fmove.s	zero(pc),fp1	* FP1 IS K = 0
	bra.w	LP1CONT1

LP1NEG0:
*--FPCR SAVED. D0 IS X IN COMPACT FORM.
	ICMP.l	d1,#0
	blt.b	LP1NEG
LP1ZERO:
	fmove.s	negone(pc),fp0

	fmove.l	d0,fpcr
	bra	t_dz

LP1NEG:
	fmove.s	zero(pc),fp0

	fmove.l	d0,fpcr
	bra	t_operr

	xdef	slognp1d
*--ENTRY POINT FOR LOG(1+Z) FOR DENORMALIZED INPUT
* Simply return the denorm
slognp1d:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* satanh():  computes the inverse hyperbolic tangent of a norm input
* satanhd(): computes the inverse hyperbolic tangent of a denorm input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************	* 
*	fp0 = arctanh(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 3 ulps in	64 significant bit,
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	ATANH	
*	1. If |X| >= 1, go to 3.	
*		
*	2. (|X| < 1) Calculate atanh(X) by
*	sgn := sign(X)	
*	y := |X|	
*	z := 2y/(1-y)	
*	atanh(X) := sgn * (1/2) * logp1(z)
*	Exit.	
*		
*	3. If |X| > 1, go to 5.	
*		
*	4. (|X| = 1) Generate infinity with an appropriate sign and
*	divide-by-zero by	
*	sgn := sign(X)	
*	atan(X) := sgn / (+0).	
*	Exit.	
*		
*	5. (|X| > 1) Generate an invalid operation by 0 * infinity.
*	Exit.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	satanh
satanh:
	move.l	(a0),d1
	move.w	4(a0),d1
	and.l	#$7FFFFFFF,d1
	ICMP.l	d1,#$3FFF8000
	bge.b	ATANHBIG

*--THIS IS THE USUAL CASE, |X| < 1
*--Y = |X|, Z = 2Y/(1-Y), ATANH(X) = SIGN(X) * (1/2) * LOG1P(Z).

	fabs.x	(a0),fp0	* Y = |X|
	fmove.x	fp0,fp1
	fneg.x	fp1	* -Y
	fadd.x	fp0,fp0	* 2Y
	fadd.s	#$3F800000,fp1	* 1-Y
	fdiv.x	fp1,fp0	* 2Y/(1-Y)
	move.l	(a0),d1
	and.l	#$80000000,d1
	or.l	#$3F000000,d1	* SIGN(X)*HALF
	move.l	d1,-(sp)

	move.l	d0,-(sp)	* save rnd prec,mode
	clr.l	d0	* pass ext prec,RN
	fmovem.x	fp0,-(sp)	* save Z on stack
	lea	(sp),a0	* pass ptr to Z
	bsr	slognp1	* LOG1P(Z)
	add.l	#$c,sp	* clear Z from stack

	move.l	(sp)+,d0	* fetch old prec,mode
	fmove.l	d0,fpcr	* load it
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.s	(sp)+,fp0
	bra	t_catch

ATANHBIG:
	fabs.x	(a0),fp0	* |X|
	fcmp.s	#$3F800000,fp0
	fbgt	t_operr
	bra	t_dz

	xdef	satanhd
*--ATANH(X) = X FOR DENORMALIZED X
satanhd:
	bra	t_extdnrm

**-------------------------------------------------------------------------------------------------
* slog10():  computes the base-10 logarithm of a normalized input
* slog10d(): computes the base-10 logarithm of a denormalized input
* slog2():   computes the base-2 logarithm of a normalized input
* slog2d():  computes the base-2 logarithm of a denormalized input
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************
*	fp0 = log_10(X) or log_2(X)	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 1.7 ulps in 64 significant bit,
*	i.e. within 0.5003 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*       slog10d:	
*		
*       Step 0.	If X < 0, create a NaN and raise the invalid operation
*               flag. Otherwise, save FPCR in D1; set FpCR to default.
*       Notes:  Default means round-to-nearest mode, no floating-point
*               traps, and precision control = double extended.
*		
*       Step 1. Call slognd to obtain Y = log(X), the natural log of X.
*       Notes:  Even if X is denormalized, log(X) is always normalized.
*		
*       Step 2.  Compute log_10(X) = log(X) * (1/log(10)).
*            2.1 Restore the user FPCR	
*            2.2 Return ans := Y * INV_L10.
*		
*       slog10: 	
*		
*       Step 0. If X < 0, create a NaN and raise the invalid operation
*               flag. Otherwise, save FPCR in D1; set FpCR to default.
*       Notes:  Default means round-to-nearest mode, no floating-point
*               traps, and precision control = double extended.
*		
*       Step 1. Call sLogN to obtain Y = log(X), the natural log of X.
*		
*       Step 2.   Compute log_10(X) = log(X) * (1/log(10)).
*            2.1  Restore the user FPCR	
*            2.2  Return ans := Y * INV_L10.
*		
*       sLog2d:	
*		
*       Step 0. If X < 0, create a NaN and raise the invalid operation
*               flag. Otherwise, save FPCR in D1; set FpCR to default.
*       Notes:  Default means round-to-nearest mode, no floating-point
*               traps, and precision control = double extended.
*		
*       Step 1. Call slognd to obtain Y = log(X), the natural log of X.
*       Notes:  Even if X is denormalized, log(X) is always normalized.
*		
*       Step 2.   Compute log_10(X) = log(X) * (1/log(2)).
*            2.1  Restore the user FPCR	
*            2.2  Return ans := Y * INV_L2.
*		
*       sLog2:	
*		
*       Step 0. If X < 0, create a NaN and raise the invalid operation
*               flag. Otherwise, save FPCR in D1; set FpCR to default.
*       Notes:  Default means round-to-nearest mode, no floating-point
*               traps, and precision control = double extended.
*		
*       Step 1. If X is not an integer power of two, i.e., X != 2^k,
*               go to Step 3.	
*		
*       Step 2.   Return k.	
*            2.1  Get integer k, X = 2^k.
*            2.2  Restore the user FPCR.
*            2.3  Return ans := convert-to-double-extended(k).
*		
*       Step 3. Call sLogN to obtain Y = log(X), the natural log of X.
*		
*       Step 4.   Compute log_2(X) = log(X) * (1/log(2)).
*            4.1  Restore the user FPCR	
*            4.2  Return ans := Y * INV_L2.
*		
**-------------------------------------------------------------------------------------------------

INV_L10:
	dc.l	$3FFD0000,$DE5BD8A9,$37287195,$00000000

INV_L2:
	dc.l	$3FFF0000,$B8AA3B29,$5C17F0BC,$00000000

	xdef	slog10
*--entry point for Log10(X), X is normalized
slog10:
	fmove.b	#$1,fp0
	fcmp.x	(a0),fp0	* if operand == 1,
	fbeq.l	ld_pzero	* return an EXACT zero

	move.l	(a0),d1
	blt.w	invalid
	move.l	d0,-(sp)
	clr.l	d0
	bsr	slogn	* log(X), X normal.
	fmove.l	(sp)+,fpcr
	fmul.x	INV_L10(pc),fp0
	bra	t_inx2

	xdef	slog10d
*--entry point for Log10(X), X is denormalized
slog10d:
	move.l	(a0),d1
	blt.w	invalid
	move.l	d0,-(sp)
	clr.l	d0
	bsr	slognd	* log(X), X denorm.
	fmove.l	(sp)+,fpcr
	fmul.x	INV_L10(pc),fp0
	bra	t_minx2

	xdef	slog2
*--entry point for Log2(X), X is normalized
slog2:
	move.l	(a0),d1
	blt.w	invalid

	move.l	8(a0),d1
	bne.b	continue	* X is not 2^k

	move.l	4(a0),d1
	and.l	#$7FFFFFFF,d1
	bne.b	continue

*--X = 2^k.
	move.w	(a0),d1
	and.l	#$00007FFF,d1
	sub.l	#$3FFF,d1
	beq.l	ld_pzero
	fmove.l	d0,fpcr
	fmove.l	d1,fp0
	bra	t_inx2

continue:
	move.l	d0,-(sp)
	clr.l	d0
	bsr	slogn	* log(X), X normal.
	fmove.l	(sp)+,fpcr
	fmul.x	INV_L2(pc),fp0
	bra	t_inx2

invalid:
	bra	t_operr

	xdef	slog2d
*--entry point for Log2(X), X is denormalized
slog2d:
	move.l	(a0),d1
	blt.w	invalid
	move.l	d0,-(sp)
	clr.l	d0
	bsr	slognd	* log(X), X denorm.
	fmove.l	(sp)+,fpcr
	fmul.x	INV_L2(pc),fp0
	bra	t_minx2

**-------------------------------------------------------------------------------------------------
* stwotox():  computes 2**X for a normalized input
* stwotoxd(): computes 2**X for a denormalized input
* stentox():  computes 10**X for a normalized input
* stentoxd(): computes 10**X for a denormalized input
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision input
*	d0 = round precision,mode	
*		
* OUTPUT **************************************************************
*	fp0 = 2**X or 10**X	
*		
* ACCURACY and MONOTONICITY *******************************************
*	The returned result is within 2 ulps in 64 significant bit, 
*	i.e. within 0.5001 ulp to 53 bits if the result is subsequently
*	rounded to double precision. The result is provably monotonic
*	in double precision.	
*		
* ALGORITHM ***********************************************************
*		
*	twotox	
*	1. If |X| > 16480, go to ExpBig.
*		
*	2. If |X| < 2**(-70), go to ExpSm.
*		
*	3. Decompose X as X = N/64 + r where |r| <= 1/128. Furthermore
*	decompose N as	
*	 N = 64(M + M') + j,  j = 0,1,2,...,63.
*		
*	4. Overwrite r := r * log2. Then
*	2**X = 2**(M') * 2**(M) * 2**(j/64) * exp(r).
*	Go to expr to compute that expression.
*		
*	tentox	
*	1. If |X| > 16480*log_10(2) (base 10 log of 2), go to ExpBig.
*		
*	2. If |X| < 2**(-70), go to ExpSm.
*		
*	3. Set y := X*log_2(10)*64 (base 2 log of 10). Set
*	N := round-to-int(y). Decompose N as
*	 N = 64(M + M') + j,  j = 0,1,2,...,63.
*		
*	4. Define r as	
*	r := ((X - N*L1)-N*L2) * L10
*	where L1, L2 are the leading and trailing parts of 
*	log_10(2)/64 and L10 is the natural log of 10. Then
*	10**X = 2**(M') * 2**(M) * 2**(j/64) * exp(r).
*	Go to expr to compute that expression.
*		
*	expr	
*	1. Fetch 2**(j/64) from table as Fact1 and Fact2.
*		
*	2. Overwrite Fact1 and Fact2 by	
*	Fact1 := 2**(M) * Fact1	
*	Fact2 := 2**(M) * Fact2	
*	Thus Fact1 + Fact2 = 2**(M) * 2**(j/64).
*		
*	3. Calculate P where 1 + P approximates exp(r):
*	P = r + r*r*(A1+r*(A2+...+r*A5)).
*		
*	4. Let AdjFact := 2**(M'). Return
*	AdjFact * ( Fact1 + ((Fact1*P) + Fact2) ).
*	Exit.	
*		
*	ExpBig	
*	1. Generate overflow by Huge * Huge if X > 0; otherwise, 
*	        generate underflow by Tiny * Tiny.
*		
*	ExpSm	
*	1. Return 1 + X.	
*		
**-------------------------------------------------------------------------------------------------

L2TEN64:
	dc.l	$406A934F,$0979A371	* 64LOG10/LOG2
L10TWO1:
	dc.l	$3F734413,$509F8000	* LOG2/64LOG10

L10TWO2:
	dc.l	$BFCD0000,$C0219DC1,$DA994FD2,$00000000

LOG10:	dc.l	$40000000,$935D8DDD,$AAA8AC17,$00000000

LOG2:	dc.l	$3FFE0000,$B17217F7,$D1CF79AC,$00000000

EXPA5:	dc.l	$3F56C16D,$6F7BD0B2
EXPA4:	dc.l	$3F811112,$302C712C
EXPA3:	dc.l	$3FA55555,$55554CC1
EXPA2:	dc.l	$3FC55555,$55554A54
EXPA1:	dc.l	$3FE00000,$00000000,$00000000,$00000000

TEXPTBL:
	dc.l	$3FFF0000,$80000000,$00000000,$3F738000
	dc.l	$3FFF0000,$8164D1F3,$BC030773,$3FBEF7CA
	dc.l	$3FFF0000,$82CD8698,$AC2BA1D7,$3FBDF8A9
	dc.l	$3FFF0000,$843A28C3,$ACDE4046,$3FBCD7C9
	dc.l	$3FFF0000,$85AAC367,$CC487B15,$BFBDE8DA
	dc.l	$3FFF0000,$871F6196,$9E8D1010,$3FBDE85C
	dc.l	$3FFF0000,$88980E80,$92DA8527,$3FBEBBF1
	dc.l	$3FFF0000,$8A14D575,$496EFD9A,$3FBB80CA
	dc.l	$3FFF0000,$8B95C1E3,$EA8BD6E7,$BFBA8373
	dc.l	$3FFF0000,$8D1ADF5B,$7E5BA9E6,$BFBE9670
	dc.l	$3FFF0000,$8EA4398B,$45CD53C0,$3FBDB700
	dc.l	$3FFF0000,$9031DC43,$1466B1DC,$3FBEEEB0
	dc.l	$3FFF0000,$91C3D373,$AB11C336,$3FBBFD6D
	dc.l	$3FFF0000,$935A2B2F,$13E6E92C,$BFBDB319
	dc.l	$3FFF0000,$94F4EFA8,$FEF70961,$3FBDBA2B
	dc.l	$3FFF0000,$96942D37,$20185A00,$3FBE91D5
	dc.l	$3FFF0000,$9837F051,$8DB8A96F,$3FBE8D5A
	dc.l	$3FFF0000,$99E04593,$20B7FA65,$BFBCDE7B
	dc.l	$3FFF0000,$9B8D39B9,$D54E5539,$BFBEBAAF
	dc.l	$3FFF0000,$9D3ED9A7,$2CFFB751,$BFBD86DA
	dc.l	$3FFF0000,$9EF53260,$91A111AE,$BFBEBEDD
	dc.l	$3FFF0000,$A0B0510F,$B9714FC2,$3FBCC96E
	dc.l	$3FFF0000,$A2704303,$0C496819,$BFBEC90B
	dc.l	$3FFF0000,$A43515AE,$09E6809E,$3FBBD1DB
	dc.l	$3FFF0000,$A5FED6A9,$B15138EA,$3FBCE5EB
	dc.l	$3FFF0000,$A7CD93B4,$E965356A,$BFBEC274
	dc.l	$3FFF0000,$A9A15AB4,$EA7C0EF8,$3FBEA83C
	dc.l	$3FFF0000,$AB7A39B5,$A93ED337,$3FBECB00
	dc.l	$3FFF0000,$AD583EEA,$42A14AC6,$3FBE9301
	dc.l	$3FFF0000,$AF3B78AD,$690A4375,$BFBD8367
	dc.l	$3FFF0000,$B123F581,$D2AC2590,$BFBEF05F
	dc.l	$3FFF0000,$B311C412,$A9112489,$3FBDFB3C
	dc.l	$3FFF0000,$B504F333,$F9DE6484,$3FBEB2FB
	dc.l	$3FFF0000,$B6FD91E3,$28D17791,$3FBAE2CB
	dc.l	$3FFF0000,$B8FBAF47,$62FB9EE9,$3FBCDC3C
	dc.l	$3FFF0000,$BAFF5AB2,$133E45FB,$3FBEE9AA
	dc.l	$3FFF0000,$BD08A39F,$580C36BF,$BFBEAEFD
	dc.l	$3FFF0000,$BF1799B6,$7A731083,$BFBCBF51
	dc.l	$3FFF0000,$C12C4CCA,$66709456,$3FBEF88A
	dc.l	$3FFF0000,$C346CCDA,$24976407,$3FBD83B2
	dc.l	$3FFF0000,$C5672A11,$5506DADD,$3FBDF8AB
	dc.l	$3FFF0000,$C78D74C8,$ABB9B15D,$BFBDFB17
	dc.l	$3FFF0000,$C9B9BD86,$6E2F27A3,$BFBEFE3C
	dc.l	$3FFF0000,$CBEC14FE,$F2727C5D,$BFBBB6F8
	dc.l	$3FFF0000,$CE248C15,$1F8480E4,$BFBCEE53
	dc.l	$3FFF0000,$D06333DA,$EF2B2595,$BFBDA4AE
	dc.l	$3FFF0000,$D2A81D91,$F12AE45A,$3FBC9124
	dc.l	$3FFF0000,$D4F35AAB,$CFEDFA1F,$3FBEB243
	dc.l	$3FFF0000,$D744FCCA,$D69D6AF4,$3FBDE69A
	dc.l	$3FFF0000,$D99D15C2,$78AFD7B6,$BFB8BC61
	dc.l	$3FFF0000,$DBFBB797,$DAF23755,$3FBDF610
	dc.l	$3FFF0000,$DE60F482,$5E0E9124,$BFBD8BE1
	dc.l	$3FFF0000,$E0CCDEEC,$2A94E111,$3FBACB12
	dc.l	$3FFF0000,$E33F8972,$BE8A5A51,$3FBB9BFE
	dc.l	$3FFF0000,$E5B906E7,$7C8348A8,$3FBCF2F4
	dc.l	$3FFF0000,$E8396A50,$3C4BDC68,$3FBEF22F
	dc.l	$3FFF0000,$EAC0C6E7,$DD24392F,$BFBDBF4A
	dc.l	$3FFF0000,$ED4F301E,$D9942B84,$3FBEC01A
	dc.l	$3FFF0000,$EFE4B99B,$DCDAF5CB,$3FBE8CAC
	dc.l	$3FFF0000,$F281773C,$59FFB13A,$BFBCBB3F
	dc.l	$3FFF0000,$F5257D15,$2486CC2C,$3FBEF73A
	dc.l	$3FFF0000,$F7D0DF73,$0AD13BB9,$BFB8B795
	dc.l	$3FFF0000,$FA83B2DB,$722A033A,$3FBEF84B
	dc.l	$3FFF0000,$FD3E0C0C,$F486C175,$BFBEF581

*INT	equ	EXC_LV+L_SCR1

*X	equ	EXC_LV+FP_SCR0
*XDCARE	equ	X+2
*XFRAC	equ	X+4

ADJFACT	equ	EXC_LV+FP_SCR0

FACT1	equ	EXC_LV+FP_SCR0
FACT1HI	equ	FACT1+4
FACT1LOW	equ	FACT1+8

FACT2	equ	EXC_LV+FP_SCR1
FACT2HI	equ	FACT2+4
FACT2LOW	equ	FACT2+8

	xdef	stwotox
*--ENTRY POINT FOR 2**(X), HERE X IS FINITE, NON-ZERO, AND NOT NAN'S
stwotox:
	fmovem.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	fmove.x	fp0,X(a6)
	and.l	#$7FFFFFFF,d1

	ICMP.l	d1,#$3FB98000	* |X| >= 2**(-70)?
	bge.b	TWOOK1
	bra.w	EXPBORS

TWOOK1:
	ICMP.l	d1,#$400D80C0	* |X| > 16480?
	ble.b	TWOMAIN
	bra.w	EXPBORS

TWOMAIN:
*--USUAL CASE, 2^(-70) <= |X| <= 16480

	fmove.x	fp0,fp1
	fmul.s	#$42800000,fp1	* 64 * X
	fmove.l	fp1,INT(a6)	* N = ROUND-TO-INT(64 X)
	move.l	d2,-(sp)
	lea	TEXPTBL(pc),a1	* LOAD ADDRESS OF TABLE OF 2^(J/64)
	fmove.l	INT(a6),fp1	* N --> FLOATING FMT
	move.l	INT(a6),d1
	move.l	d1,d2
	and.l	#$3F,d1	* D0 IS J
	asl.l	#4,d1	* DISPLACEMENT FOR 2^(J/64)
	add.l	d1,a1	* ADDRESS FOR 2^(J/64)
	asr.l	#6,d2	* d2 IS L, N = 64L + J
	move.l	d2,d1
	asr.l	#1,d1	* D0 IS M
	sub.l	d1,d2	* d2 IS M', N = 64(M+M') + J
	add.l	#$3FFF,d2

*--SUMMARY: a1 IS ADDRESS FOR THE LEADING PORTION OF 2^(J/64),
*--D0 IS M WHERE N = 64(M+M') + J. NOTE THAT |M| <= 16140 BY DESIGN.
*--ADJFACT = 2^(M').
*--REGISTERS SAVED SO FAR ARE (IN ORDER) FPCR, D0, FP1, a1, AND FP2.

	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmul.s	#$3C800000,fp1	* (1/64)*N
	move.l	(a1)+,FACT1(a6)
	move.l	(a1)+,FACT1HI(a6)
	move.l	(a1)+,FACT1LOW(a6)
	move.w	(a1)+,FACT2(a6)

	fsub.x	fp1,fp0	* X - (1/64)*INT(64 X)

	move.w	(a1)+,FACT2HI(a6)
	clr.w	FACT2HI+2(a6)
	clr.l	FACT2LOW(a6)
	add.w	d1,FACT1(a6)
	fmul.x	LOG2(pc),fp0	* FP0 IS R
	add.w	d1,FACT2(a6)

	bra.w	expr

EXPBORS:
*--FPCR, D0 SAVED
	ICMP.l	d1,#$3FFF8000
	bgt.b	TEXPBIG

*--|X| IS SMALL, RETURN 1 + X

	fmove.l	d0,fpcr	* restore users round prec,mode
	fadd.s	#$3F800000,fp0	* RETURN 1 + X
	bra	t_pinx2

TEXPBIG:
*--|X| IS LARGE, GENERATE OVERFLOW IF X > 0; ELSE GENERATE UNDERFLOW
*--REGISTERS SAVE SO FAR ARE FPCR AND  D0
	move.l	X(a6),d1
	ICMP.l	d1,#0
	blt.b	EXPNEG

	bra	t_ovfl2	* t_ovfl expects positive value

EXPNEG:
	bra	t_unfl2	* t_unfl expects positive value

	xdef	stwotoxd
stwotoxd:
*--ENTRY POINT FOR 2**(X) FOR DENORMALIZED ARGUMENT

	fmove.l	d0,fpcr	* set user's rounding mode/precision
	fmove.s	#$3F800000,fp0	* RETURN 1 + X
	move.l	(a0),d1
	or.l	#$00800001,d1
	fadd.s	d1,fp0
	bra	t_pinx2

	xdef	stentox
*--ENTRY POINT FOR 10**(X), HERE X IS FINITE, NON-ZERO, AND NOT NAN'S
stentox:
	fmovem.x	(a0),fp0	* LOAD INPUT

	move.l	(a0),d1
	move.w	4(a0),d1
	fmove.x	fp0,X(a6)
	and.l	#$7FFFFFFF,d1

	ICMP.l	d1,#$3FB98000	* |X| >= 2**(-70)?
	bge.b	TENOK1
	bra.w	EXPBORS

TENOK1:
	ICMP.l	d1,#$400B9B07	* |X| <= 16480*log2/log10 ?
	ble.b	TENMAIN
	bra.w	EXPBORS

TENMAIN:
*--USUAL CASE, 2^(-70) <= |X| <= 16480 LOG 2 / LOG 10

	fmove.x	fp0,fp1
	fmul.d	L2TEN64(pc),fp1	* X*64*LOG10/LOG2
	fmove.l	fp1,INT(a6)	* N=INT(X*64*LOG10/LOG2)
	move.l	d2,-(sp)
	lea	TEXPTBL(pc),a1	* LOAD ADDRESS OF TABLE OF 2^(J/64)
	fmove.l	INT(a6),fp1	* N --> FLOATING FMT
	move.l	INT(a6),d1
	move.l	d1,d2
	and.l	#$3F,d1	* D0 IS J
	asl.l	#4,d1	* DISPLACEMENT FOR 2^(J/64)
	add.l	d1,a1	* ADDRESS FOR 2^(J/64)
	asr.l	#6,d2	* d2 IS L, N = 64L + J
	move.l	d2,d1
	asr.l	#1,d1	* D0 IS M
	sub.l	d1,d2	* d2 IS M', N = 64(M+M') + J
	add.l	#$3FFF,d2

*--SUMMARY: a1 IS ADDRESS FOR THE LEADING PORTION OF 2^(J/64),
*--D0 IS M WHERE N = 64(M+M') + J. NOTE THAT |M| <= 16140 BY DESIGN.
*--ADJFACT = 2^(M').
*--REGISTERS SAVED SO FAR ARE (IN ORDER) FPCR, D0, FP1, a1, AND FP2.
	fmovem.x	fp2-fp3,-(sp)	* save fp2/fp3

	fmove.x	fp1,fp2

	fmul.d	L10TWO1(pc),fp1	* N*(LOG2/64LOG10)_LEAD
	move.l	(a1)+,FACT1(a6)

	fmul.x	L10TWO2(pc),fp2	* N*(LOG2/64LOG10)_TRAIL

	move.l	(a1)+,FACT1HI(a6)
	move.l	(a1)+,FACT1LOW(a6)
	fsub.x	fp1,fp0	* X - N L_LEAD
	move.w	(a1)+,FACT2(a6)

	fsub.x	fp2,fp0	* X - N L_TRAIL

	move.w	(a1)+,FACT2HI(a6)
	clr.w	FACT2HI+2(a6)
	clr.l	FACT2LOW(a6)

	fmul.x	LOG10(pc),fp0	* FP0 IS R
	add.w	d1,FACT1(a6)
	add.w	d1,FACT2(a6)

expr:
*--FPCR, FP2, FP3 ARE SAVED IN ORDER AS SHOWN.
*--ADJFACT CONTAINS 2**(M'), FACT1 + FACT2 = 2**(M) * 2**(J/64).
*--FP0 IS R. THE FOLLOWING CODE COMPUTES
*--	2**(M'+M) * 2**(J/64) * EXP(R)

	fmove.x	fp0,fp1
	fmul.x	fp1,fp1	* FP1 IS S = R*R

	fmove.d	EXPA5(pc),fp2	* FP2 IS A5
	fmove.d	EXPA4(pc),fp3	* FP3 IS A4

	fmul.x	fp1,fp2	* FP2 IS S*A5
	fmul.x	fp1,fp3	* FP3 IS S*A4

	fadd.d	EXPA3(pc),fp2	* FP2 IS A3+S*A5
	fadd.d	EXPA2(pc),fp3	* FP3 IS A2+S*A4

	fmul.x	fp1,fp2	* FP2 IS S*(A3+S*A5)
	fmul.x	fp1,fp3	* FP3 IS S*(A2+S*A4)

	fadd.d	EXPA1(pc),fp2	* FP2 IS A1+S*(A3+S*A5)
	fmul.x	fp0,fp3	* FP3 IS R*S*(A2+S*A4)

	fmul.x	fp1,fp2	* FP2 IS S*(A1+S*(A3+S*A5))
	fadd.x	fp3,fp0	* FP0 IS R+R*S*(A2+S*A4)
	fadd.x	fp2,fp0	* FP0 IS EXP(R) - 1

	fmovem.x	(sp)+,fp2-fp3	* restore fp2/fp3

*--FINAL RECONSTRUCTION PROCESS
*--EXP(X) = 2^M*2^(J/64) + 2^M*2^(J/64)*(EXP(R)-1)  -  (1 OR 0)

	fmul.x	FACT1(a6),fp0
	fadd.x	FACT2(a6),fp0
	fadd.x	FACT1(a6),fp0

	fmove.l	d0,fpcr	* restore users round prec,mode
	move.w	d2,ADJFACT(a6)	* INSERT EXPONENT
	move.l	(sp)+,d2
	move.l	#$80000000,ADJFACT+4(a6)
	clr.l	ADJFACT+8(a6)
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	ADJFACT(a6),fp0	* FINAL ADJUSTMENT
	bra	t_catch

	xdef	stentoxd
stentoxd:
*--ENTRY POINT FOR 10**(X) FOR DENORMALIZED ARGUMENT

	fmove.l	d0,fpcr	* set user's rounding mode/precision
	fmove.s	#$3F800000,fp0	* RETURN 1 + X
	move.l	(a0),d1
	or.l	#$00800001,d1
	fadd.s	d1,fp0
	bra	t_pinx2

**-------------------------------------------------------------------------------------------------
* smovcr(): returns the ROM constant at the offset specified in d1
*	    rounded to the mode and precision specified in d0. 
*		
* INPUT	***************************************************************
* 	d0 = rnd prec,mode	
*	d1 = ROM offset	
*		
* OUTPUT **************************************************************
*	fp0 = the ROM constant rounded to the user's rounding mode,prec
*		
**-------------------------------------------------------------------------------------------------

	xdef	smovcr
smovcr:
	move.l	d1,-(sp)	* save rom offset for a sec

	lsr.b	#$4,d0	* shift ctrl bits to lo
	move.l	d0,d1	* make a copy 
	andi.w	#$3,d1	* extract rnd mode
	andi.w	#$c,d0	* extract rnd prec
	swap	d0	* put rnd prec in hi
	move.w	d1,d0	* put rnd mode in lo

	move.l	(sp)+,d1	* get rom offset

*
* check range of offset
*
	tst.b	d1	* if zero, offset is to pi
	beq.b	pi_tbl	* it is pi
	ICMP.b	d1,#$0a	* check range $01 - $0a
	ble.b	z_val	* if in this range, return zero
	ICMP.b	d1,#$0e	* check range $0b - $0e
	ble.b	sm_tbl	* valid constants in this range
	ICMP.b	d1,#$2f	* check range $10 - $2f
	ble.b	z_val	* if in this range, return zero
	ICMP.b	d1,#$3f	* check range $30 - $3f
	ble.b	bg_tbl	* valid constants in this range

z_val:
	bra.l	ld_pzero	* return a zero

*
* the answer is PI rounded to the proper precision.
*
* fetch a pointer to the answer table relating to the proper rounding
* precision.
*
pi_tbl:
	tst.b	d0	* is rmode RN?
	bne.b	pi_not_rn	* no
pi_rn:
	lea.l	PIRN(pc),a0	* yes; load PI RN table addr
	bra.w	set_finx
pi_not_rn:
	ICMP.b	d0,#rp_mode	* is rmode RP?
	beq.b	pi_rp	* yes
pi_rzrm:
	lea.l	PIRZRM(pc),a0	* no; load PI RZ,RM table addr
	bra.b	set_finx
pi_rp:
	lea.l	PIRP(pc),a0	* load PI RP table addr
	bra.b	set_finx

*
* the answer is one of:
*	$0B	log10(2)	(inexact)
*	$0C	e	(inexact)
*	$0D	log2(e)	(inexact)
*	$0E	log10(e)	(exact)
* 
* fetch a pointer to the answer table relating to the proper rounding
* precision.
*
sm_tbl:
	subi.b	#$b,d1	* make offset in 0-4 range
	tst.b	d0	* is rmode RN?
	bne.b	sm_not_rn	* no
sm_rn:
	lea.l	SMALRN(pc),a0	* yes; load RN table addr
sm_tbl_cont:
	ICMP.b	d1,#$2	* is result log10(e)?
	ble.b	set_finx	* no; answer is inexact
	bra.b	no_finx	* yes; answer is exact
sm_not_rn:
	ICMP.b	d0,#rp_mode	* is rmode RP?
	beq.b	sm_rp	* yes
sm_rzrm:
	lea.l	SMALRZRM(pc),a0	* no; load RZ,RM table addr
	bra.b	sm_tbl_cont
sm_rp:
	lea.l	SMALRP(pc),a0	* load RP table addr
	bra.b	sm_tbl_cont

*
* the answer is one of:
*	$30	ln(2)	(inexact)
*	$31	ln(10)	(inexact)
*	$32	10^0	(exact)
*	$33	10^1	(exact)
*	$34	10^2	(exact)
*	$35	10^4	(exact)
*	$36	10^8	(exact)
*	$37	10^16	(exact)
*	$38	10^32	(inexact)
*	$39	10^64	(inexact)
*	$3A	10^128	(inexact)
*	$3B	10^256	(inexact)
*	$3C	10^512	(inexact)
*	$3D	10^1024	(inexact)
*	$3E	10^2048	(inexact)
*	$3F	10^4096	(inexact)
*
* fetch a pointer to the answer table relating to the proper rounding
* precision.
*
bg_tbl:
	subi.b	#$30,d1	* make offset in 0-f range
	tst.b	d0	* is rmode RN?
	bne.b	bg_not_rn	* no
bg_rn:
	lea.l	BIGRN(pc),a0	* yes; load RN table addr
bg_tbl_cont:
	ICMP.b	d1,#$1	* is offset <= $31?
	ble.b	set_finx	* yes; answer is inexact
	ICMP.b	d1,#$7	* is $32 <= offset <= $37?
	ble.b	no_finx	* yes; answer is exact
	bra.b	set_finx	* no; answer is inexact
bg_not_rn:
	ICMP.b	d0,#rp_mode	* is rmode RP?
	beq.b	bg_rp	* yes
bg_rzrm:
	lea.l	BIGRZRM(pc),a0	* no; load RZ,RM table addr
	bra.b	bg_tbl_cont
bg_rp:
	lea.l	BIGRP(pc),a0	* load RP table addr
	bra.b	bg_tbl_cont

* answer is inexact, so set INEX2 and AINEX in the user's FPSR.
set_finx:
	ori.l	#inx2a_mask,EXC_LV+USER_FPSR(a6) * set INEX2/AINEX
no_finx:
	mulu.w	#$c,d1	* offset points into tables
	swap	d0	* put rnd prec in lo word
	tst.b	d0	* is precision extended?

	bne.b	not_ext	* if xprec, do not call round

* Precision is extended
	fmovem.x	(a0,d1.w),fp0	* return result in fp0
	rts

* Precision is single or double
not_ext:
	swap	d0	* rnd prec in upper word

* call round() to round the answer to the proper precision.
* exponents out of range for single or double DO NOT cause underflow 
* or overflow.
	move.w	$0(a0,d1.w),EXC_LV+FP_SCR1_EX(a6) * load first word
	move.l	$4(a0,d1.w),EXC_LV+FP_SCR1_HI(a6) * load second word
	move.l	$8(a0,d1.w),EXC_LV+FP_SCR1_LO(a6) * load third word
	move.l	d0,d1
	clr.l	d0	* clear g,r,s
	lea	EXC_LV+FP_SCR1(a6),a0	* pass ptr to answer
	clr.w	LOCAL_SGN(a0)	* sign always positive
	bsr.l	_round	* round the mantissa

	fmovem.x	(a0),fp0	* return rounded result in fp0
	rts

	cnop	0,$4

PIRN:	dc.l	$40000000,$c90fdaa2,$2168c235	* pi
PIRZRM:	dc.l	$40000000,$c90fdaa2,$2168c234	* pi
PIRP:	dc.l	$40000000,$c90fdaa2,$2168c235	* pi

SMALRN:	dc.l	$3ffd0000,$9a209a84,$fbcff798	* log10(2)
	dc.l	$40000000,$adf85458,$a2bb4a9a	* e
	dc.l	$3fff0000,$b8aa3b29,$5c17f0bc	* log2(e)
	dc.l	$3ffd0000,$de5bd8a9,$37287195	* log10(e)
	dc.l	$00000000,$00000000,$00000000	* 0.0

SMALRZRM:
	dc.l	$3ffd0000,$9a209a84,$fbcff798	* log10(2)
	dc.l	$40000000,$adf85458,$a2bb4a9a	* e
	dc.l	$3fff0000,$b8aa3b29,$5c17f0bb	* log2(e)
	dc.l	$3ffd0000,$de5bd8a9,$37287195	* log10(e)
	dc.l	$00000000,$00000000,$00000000	* 0.0

SMALRP:	dc.l	$3ffd0000,$9a209a84,$fbcff799	* log10(2)
	dc.l	$40000000,$adf85458,$a2bb4a9b	* e
	dc.l	$3fff0000,$b8aa3b29,$5c17f0bc	* log2(e)
	dc.l	$3ffd0000,$de5bd8a9,$37287195	* log10(e)
	dc.l	$00000000,$00000000,$00000000	* 0.0

BIGRN:	dc.l	$3ffe0000,$b17217f7,$d1cf79ac	* ln(2)
	dc.l	$40000000,$935d8ddd,$aaa8ac17	* ln(10)

	dc.l	$3fff0000,$80000000,$00000000	* 10 ^ 0
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59E	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D5	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CE0	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8E	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C7	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C17	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE5	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979B	* 10 ^ 4096

BIGRZRM:
	dc.l	$3ffe0000,$b17217f7,$d1cf79ab	* ln(2)
	dc.l	$40000000,$935d8ddd,$aaa8ac16	* ln(10)

	dc.l	$3fff0000,$80000000,$00000000	* 10 ^ 0
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59D	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D5	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CDF	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8D	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C6	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C17	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE4	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979A	* 10 ^ 4096

BIGRP:
	dc.l	$3ffe0000,$b17217f7,$d1cf79ac	* ln(2)
	dc.l	$40000000,$935d8ddd,$aaa8ac17	* ln(10)

	dc.l	$3fff0000,$80000000,$00000000	* 10 ^ 0
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59E	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D6	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CE0	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8E	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C7	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C18	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE5	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979B	* 10 ^ 4096

**-------------------------------------------------------------------------------------------------
* sscale(): computes the destination operand scaled by the source
*	    operand. If the absoulute value of the source operand is 
*	    >= 2^14, an overflow or underflow is returned.
*		
* INPUT *************************************************************** *
*	a0  = pointer to double-extended source operand X
*	a1  = pointer to double-extended destination operand Y
*		
* OUTPUT ************************************************************** *
*	fp0 =  scale(X,Y)	
*		
**-------------------------------------------------------------------------------------------------

SIGN	equ	EXC_LV+L_SCR1

	xdef	sscale
sscale:
	move.l	d0,-(sp)	* store off ctrl bits for now

	move.w	DST_EX(a1),d1	* get dst exponent
	smi.b	SIGN(a6)	* use SIGN to hold dst sign
	andi.l	#$00007fff,d1	* strip sign from dst exp

	move.w	SRC_EX(a0),d0	* check src bounds
	andi.w	#$7fff,d0	* clr src sign bit
	ICMP.w	d0,#$3fff	* is src ~ ZERO?
	blt.w	src_small	* yes
	ICMP.w	d0,#$400c	* no; is src too big?
	bgt.w	src_out	* yes

*
* Source is within 2^14 range.
*
src_ok:
	fintrz.x	SRC(a0),fp0	* calc int of src
	fmove.l	fp0,d0	* int src to d0
* don't want any accrued bits from the fintrz showing up later since
* we may need to read the fpsr for the last fp op in t_catch2().
	fmove.l	#$0,fpsr

	tst.b	DST_HI(a1)	* is dst denormalized?
	bmi.b	sok_norm

* the dst is a DENORM. normalize the DENORM and add the adjustment to
* the src value. then, jump to the norm part of the routine.
sok_dnrm:
	move.l	d0,-(sp)	* save src for now

	move.w	DST_EX(a1),EXC_LV+FP_SCR0_EX(a6) * make a copy
	move.l	DST_HI(a1),EXC_LV+FP_SCR0_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR0_LO(a6)

	lea	EXC_LV+FP_SCR0(a6),a0	* pass ptr to DENORM
	bsr.l	norm	* normalize the DENORM
	neg.l	d0
	add.l	(sp)+,d0	* add adjustment to src

	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* load normalized DENORM

	ICMP.w	d0,#-$3fff	* is the shft amt really low?
	bge.b	sok_norm2	* thank goodness no

* the multiply factor that we're trying to create should be a denorm
* for the multiply to work. therefore, we're going to actually do a 
* multiply with a denorm which will cause an unimplemented data type
* exception to be put into the machine which will be caught and corrected
* later. we don't do this with the DENORMs above because this method
* is slower. but, don't fret, I don't see it being used much either.
	fmove.l	(sp)+,fpcr	* restore user fpcr
	move.l	#$80000000,d1	* load normalized mantissa
	subi.l	#-$3fff,d0	* how many should we shift?
	neg.l	d0	* make it positive
	ICMP.b	d0,#$20	* is it > 32?
	bge.b	sok_dnrm_32	* yes
	lsr.l	d0,d1	* no; bit stays in upper lw
	clr.l	-(sp)	* insert zero low mantissa
	move.l	d1,-(sp)	* insert new high mantissa
	clr.l	-(sp)	* make zero exponent
	bra.b	sok_norm_cont	
sok_dnrm_32:
	subi.b	#$20,d0	* get shift count
	lsr.l	d0,d1	* make low mantissa longword
	move.l	d1,-(sp)	* insert new low mantissa
	clr.l	-(sp)	* insert zero high mantissa
	clr.l	-(sp)	* make zero exponent
	bra.b	sok_norm_cont
	
* the src will force the dst to a DENORM value or worse. so, let's
* create an fp multiply that will create the result.
sok_norm:
	fmovem.x	DST(a1),fp0	* load fp0 with normalized src
sok_norm2:
	fmove.l	(sp)+,fpcr	* restore user fpcr

	addi.w	#$3fff,d0	* turn src amt into exp value
	swap	d0	* put exponent in high word
	clr.l	-(sp)	* insert new exponent
	move.l	#$80000000,-(sp)	* insert new high mantissa
	move.l	d0,-(sp)	* insert new lo mantissa

sok_norm_cont:
	fmove.l	fpcr,d0	* d0 needs fpcr for t_catch2
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	(sp)+,fp0	* do the multiply
	bra	t_catch2	* catch any exceptions

*
* Source is outside of 2^14 range.  Test the sign and branch
* to the appropriate exception handler.
*
src_out:
	move.l	(sp)+,d0	* restore ctrl bits
	exg	a0,a1	* swap src,dst ptrs
	tst.b	SRC_EX(a1)	* is src negative?
	bmi	t_unfl	* yes; underflow
	bra	t_ovfl_sc	* no; overflow

*
* The source input is below 1, so we check for denormalized numbers
* and set unfl.
*
src_small:
	tst.b	DST_HI(a1)	* is dst denormalized?
	bpl.b	ssmall_done	* yes

	move.l	(sp)+,d0
	fmove.l	d0,fpcr	* no; load control bits
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	DST(a1),fp0	* simply return dest
	bra	t_catch2
ssmall_done:
	move.l	(sp)+,d0	* load control bits into d1
	move.l	a1,a0	* pass ptr to dst
	bra	t_resdnrm

**-------------------------------------------------------------------------------------------------
* smod(): computes the fp MOD of the input values X,Y.
* srem(): computes the fp (IEEE) REM of the input values X,Y.
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision input X
*	a1 = pointer to extended precision input Y
*	d0 = round precision,mode	
*		
* 	The input operands X and Y can be either normalized or 
*	denormalized.	
*		
* OUTPUT ************************************************************** *
*      fp0 = FREM(X,Y) or FMOD(X,Y)	
*		
* ALGORITHM *********************************************************** *
*		
*       Step 1.  Save and strip signs of X and Y: signX := sign(X),
*                signY := sign(Y), X := |X|, Y := |Y|, 
*                signQ := signX EOR signY. Record whether MOD or REM
*                is requested.	
*		
*       Step 2.  Set L := expo(X)-expo(Y), k := 0, Q := 0.
*                If (L < 0) then	
*                   R := X, go to Step 4.
*                else	
*                   R := 2^(-L)X, j := L.
*                endif	
*		
*       Step 3.  Perform MOD(X,Y)	
*            3.1 If R = Y, go to Step 9.
*            3.2 If R > Y, then { R := R - Y, Q := Q + 1}
*            3.3 If j = 0, go to Step 4.
*            3.4 k := k + 1, j := j - 1, Q := 2Q, R := 2R. Go to
*                Step 3.1.	
*		
*       Step 4.  At this point, R = X - QY = MOD(X,Y). Set
*                Last_Subtract := false (used in Step 7 below). If
*                MOD is requested, go to Step 6. 
*		
*       Step 5.  R = MOD(X,Y), but REM(X,Y) is requested.
*            5.1 If R < Y/2, then R = MOD(X,Y) = REM(X,Y). Go to
*                Step 6.	
*            5.2 If R > Y/2, then { set Last_Subtract := true,
*                Q := Q + 1, Y := signY*Y }. Go to Step 6.
*            5.3 This is the tricky case of R = Y/2. If Q is odd,
*                then { Q := Q + 1, signX := -signX }.
*		
*       Step 6.  R := signX*R.	
*		
*       Step 7.  If Last_Subtract = true, R := R - Y.
*		
*       Step 8.  Return signQ, last 7 bits of Q, and R as required.
*		
*       Step 9.  At this point, R = 2^(-j)*X - Q Y = Y. Thus,
*                X = 2^(j)*(Q+1)Y. set Q := 2^(j)*(Q+1),
*                R := 0. Return signQ, last 7 bits of Q, and R.
*		
**-------------------------------------------------------------------------------------------------

Mod_Flag	equ	EXC_LV+L_SCR3
Sc_Flag	equ	EXC_LV+L_SCR3+1

SignY	equ	EXC_LV+L_SCR2
SignX	equ	EXC_LV+L_SCR2+2
SignQ	equ	EXC_LV+L_SCR3+2

Y	equ	EXC_LV+FP_SCR0
Y_Hi	equ	Y+4
Y_Lo	equ	Y+8

R	equ	EXC_LV+FP_SCR1
R_Hi	equ	R+4
R_Lo	equ	R+8

Scale:
	dc.l	$00010000,$80000000,$00000000,$00000000

	xdef	smod
smod:
	clr.b	EXC_LV+FPSR_QBYTE(a6)
	move.l	d0,-(sp)	* save ctrl bits
	clr.b	Mod_Flag(a6)
	bra.b	Mod_Rem

	xdef	srem
srem:
	clr.b	EXC_LV+FPSR_QBYTE(a6)
	move.l	d0,-(sp)	* save ctrl bits
	move.b	#$1,Mod_Flag(a6)

Mod_Rem:
*..Save sign of X and Y
	movem.l	d2-d7,-(sp)	* save data registers
	move.w	SRC_EX(a0),d3
	move.w	d3,SignY(a6)
	and.l	#$00007FFF,d3	* Y := |Y|

*
	move.l	SRC_HI(a0),d4
	move.l	SRC_LO(a0),d5	* (D3,D4,D5) is |Y|

	tst.l	d3
	bne.b	Y_Normal

	move.l	#$00003FFE,d3	* $3FFD + 1
	tst.l	d4
	bne.b	HiY_not0

HiY_0:
	move.l	d5,d4
	clr.l	d5
	sub.l	#32,d3
	clr.l	d6
	bfffo	d4{0:32},d6
	lsl.l	d6,d4
	sub.l	d6,d3	* (D3,D4,D5) is normalized
*	                                        ...with bias $7FFD
	bra.b	Chk_X

HiY_not0:
	clr.l	d6
	bfffo	d4{0:32},d6
	sub.l	d6,d3
	lsl.l	d6,d4
	move.l	d5,d7	* a copy of D5
	lsl.l	d6,d5
	neg.l	d6
	add.l	#32,d6
	lsr.l	d6,d7
	or.l	d7,d4	* (D3,D4,D5) normalized
*                                       ...with bias $7FFD
	bra.b	Chk_X

Y_Normal:
	add.l	#$00003FFE,d3	* (D3,D4,D5) normalized
*                                       ...with bias $7FFD

Chk_X:
	move.w	DST_EX(a1),d0
	move.w	d0,SignX(a6)
	move.w	SignY(a6),d1
	eor.l	d0,d1
	and.l	#$00008000,d1
	move.w	d1,SignQ(a6)	* sign(Q) obtained
	and.l	#$00007FFF,d0
	move.l	DST_HI(a1),d1
	move.l	DST_LO(a1),d2	* (D0,D1,D2) is |X|
	tst.l	d0
	bne.b	X_Normal
	move.l	#$00003FFE,d0
	tst.l	d1
	bne.b	HiX_not0

HiX_0:
	move.l	d2,d1
	clr.l	d2
	sub.l	#32,d0
	clr.l	d6
	bfffo	d1{0:32},d6
	lsl.l	d6,d1
	sub.l	d6,d0	* (D0,D1,D2) is normalized
*                                       ...with bias $7FFD
	bra.b	Init

HiX_not0:
	clr.l	d6
	bfffo	d1{0:32},d6
	sub.l	d6,d0
	lsl.l	d6,d1
	move.l	d2,d7	* a copy of D2
	lsl.l	d6,d2
	neg.l	d6
	add.l	#32,d6
	lsr.l	d6,d7
	or.l	d7,d1	* (D0,D1,D2) normalized
*                                       ...with bias $7FFD
	bra.b	Init

X_Normal:
	add.l	#$00003FFE,d0	* (D0,D1,D2) normalized
*                                       ...with bias $7FFD

Init:
*
	move.l	d3,EXC_LV+L_SCR1(a6)	* save biased exp(Y)
	move.l	d0,-(sp)	* save biased exp(X)
	sub.l	d3,d0	* L := expo(X)-expo(Y)

	clr.l	d6	* D6 := carry <- 0
	clr.l	d3	* D3 is Q
	move.l	#0,a1	* A1 is k; j+k=L, Q=0

*..(Carry,D1,D2) is R
	tst.l	d0
	bge.b	Mod_Loop_pre

*..expo(X) < expo(Y). Thus X = mod(X,Y)
*
	move.l	(sp)+,d0	* restore d0
	bra.w	Get_Mod

Mod_Loop_pre:
	addq.l	#$4,sp	* erase exp(X)
*..At this point  R = 2^(-L)X; Q = 0; k = 0; and  k+j = L
Mod_Loop:
	tst.l	d6	* test carry bit
	bgt.b	R_GT_Y

*..At this point carry = 0, R = (D1,D2), Y = (D4,D5)
	ICMP.l	d1,d4	* compare hi(R) and hi(Y)
	bne.b	R_NE_Y
	ICMP.l	d2,d5	* compare lo(R) and lo(Y)
	bne.b	R_NE_Y

*..At this point, R = Y
	bra.w	Rem_is_0

R_NE_Y:
*..use the borrow of the previous compare
	bcs.b	R_LT_Y	* borrow is set iff R < Y

R_GT_Y:
*..If Carry is set, then Y < (Carry,D1,D2) < 2Y. Otherwise, Carry = 0
*..and Y < (D1,D2) < 2Y. Either way, perform R - Y
	sub.l	d5,d2	* lo(R) - lo(Y)
	subx.l	d4,d1	* hi(R) - hi(Y)
	clr.l	d6	* clear carry
	addq.l	#1,d3	* Q := Q + 1

R_LT_Y:
*..At this point, Carry=0, R < Y. R = 2^(k-L)X - QY; k+j = L; j >= 0.
	tst.l	d0	* see if j = 0.
	beq.b	PostLoop

	add.l	d3,d3	* Q := 2Q
	add.l	d2,d2	* lo(R) = 2lo(R)
	roxl.l	#1,d1	* hi(R) = 2hi(R) + carry
	scs	d6	* set Carry if 2(R) overflows
	addq.l	#1,a1	* k := k+1
	subq.l	#1,d0	* j := j - 1
*..At this point, R=(Carry,D1,D2) = 2^(k-L)X - QY, j+k=L, j >= 0, R < 2Y.

	bra.b	Mod_Loop

PostLoop:
*..k = L, j = 0, Carry = 0, R = (D1,D2) = X - QY, R < Y.

*..normalize R.
	move.l	EXC_LV+L_SCR1(a6),d0	* new biased expo of R
	tst.l	d1
	bne.b	HiR_not0

HiR_0:
	move.l	d2,d1
	clr.l	d2
	sub.l	#32,d0
	clr.l	d6
	bfffo	d1{0:32},d6
	lsl.l	d6,d1
	sub.l	d6,d0	* (D0,D1,D2) is normalized
*                                       ...with bias $7FFD
	bra.b	Get_Mod

HiR_not0:
	clr.l	d6
	bfffo	d1{0:32},d6
	bmi.b	Get_Mod	* already normalized
	sub.l	d6,d0
	lsl.l	d6,d1
	move.l	d2,d7	* a copy of D2
	lsl.l	d6,d2
	neg.l	d6
	add.l	#32,d6
	lsr.l	d6,d7
	or.l	d7,d1	* (D0,D1,D2) normalized

*
Get_Mod:
	ICMP.l	d0,#$000041FE
	bge.b	No_Scale
Do_Scale:
	move.w	d0,R(a6)
	move.l	d1,R_Hi(a6)
	move.l	d2,R_Lo(a6)
	move.l	EXC_LV+L_SCR1(a6),d6
	move.w	d6,Y(a6)
	move.l	d4,Y_Hi(a6)
	move.l	d5,Y_Lo(a6)
	fmove.x	R(a6),fp0	* no exception
	move.b	#1,Sc_Flag(a6)
	bra.b	ModOrRem
No_Scale:
	move.l	d1,R_Hi(a6)
	move.l	d2,R_Lo(a6)
	sub.l	#$3FFE,d0
	move.w	d0,R(a6)
	move.l	EXC_LV+L_SCR1(a6),d6
	sub.l	#$3FFE,d6
	move.l	d6,EXC_LV+L_SCR1(a6)
	fmove.x	R(a6),fp0
	move.w	d6,Y(a6)
	move.l	d4,Y_Hi(a6)
	move.l	d5,Y_Lo(a6)
	clr.b	Sc_Flag(a6)

*
ModOrRem:
	tst.b	Mod_Flag(a6)
	beq.b	Fix_Sign

	move.l	EXC_LV+L_SCR1(a6),d6	* new biased expo(Y)
	subq.l	#1,d6	* biased expo(Y/2)
	ICMP.l	d0,d6
	blt.b	Fix_Sign
	bgt.b	Last_Sub

	ICMP.l	d1,d4
	bne.b	Not_EQ
	ICMP.l	d2,d5
	bne.b	Not_EQ
	bra.w	Tie_Case

Not_EQ:
	bcs.b	Fix_Sign

Last_Sub:
*
	fsub.x	Y(a6),fp0	* no exceptions
	addq.l	#1,d3	* Q := Q + 1

*
Fix_Sign:
*..Get sign of X
	move.w	SignX(a6),d6
	bge.b	Get_Q
	fneg.x	fp0

*..Get Q
*
Get_Q:
	clr.l	d6
	move.w	SignQ(a6),d6	* D6 is sign(Q)
	move.l	#8,d7
	lsr.l	d7,d6
	and.l	#$0000007F,d3	* 7 bits of Q
	or.l	d6,d3	* sign and bits of Q
*	swap	d3
*	fmove.l	fpsr,d6
*	and.l	#$FF00FFFF,d6
*	or.l	d3,d6
*	fmove.l	d6,fpsr	* put Q in fpsr
	move.b	d3,EXC_LV+FPSR_QBYTE(a6)	* put Q in fpsr

*
Restore:
	movem.l	(sp)+,d2-d7	*  {d2-d7}
	move.l	(sp)+,d0
	fmove.l	d0,fpcr
	tst.b	Sc_Flag(a6)
	beq.b	Finish
	move.b	#FMUL_OP,d1	* last inst is MUL
	fmul.x	Scale(pc),fp0	* may cause underflow
	bra	t_catch2
* the '040 package did this apparently to see if the dst operand for the 
* preceding fmul was a denorm. but, it better not have been since the 
* algorithm just got done playing with fp0 and expected no exceptions
* as a result. trust me...
*	bra	t_avoid_unsupp	* check for denorm as a
*		;result of the scaling

Finish:
	move.b	#FMOV_OP,d1	* last inst is MOVE
	fmove.x	fp0,fp0	* capture exceptions # round
	bra	t_catch2

Rem_is_0:
*..R = 2^(-j)X - Q Y = Y, thus R = 0 and quotient = 2^j (Q+1)
	addq.l	#1,d3
	ICMP.l	d0,#8	* D0 is j 
	bge.b	Q_Big

	lsl.l	d0,d3
	bra.b	Set_R_0

Q_Big:
	clr.l	d3

Set_R_0:
	fmove.s	#$00000000,fp0
	clr.b	Sc_Flag(a6)
	bra.w	Fix_Sign

Tie_Case:
*..Check parity of Q
	move.l	d3,d6
	and.l	#$00000001,d6
	tst.l	d6
	beq.w	Fix_Sign	* Q is even

*..Q is odd, Q := Q + 1, signX := -signX
	addq.l	#1,d3
	move.w	SignX(a6),d6
	eor.l	#$00008000,d6
	move.w	d6,SignX(a6)
	bra.w	Fix_Sign

qnan:	dc.l	$7fff0000, $ffffffff, $ffffffff

**-------------------------------------------------------------------------------------------------
* XDEF **
*	t_dz(): Handle DZ exception during transcendental emulation.
*	        Sets N bit according to sign of source operand.
*	t_dz2(): Handle DZ exception during transcendental emulation.
*	 Sets N bit always.	
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0 = pointer to source operand	
* 		
* OUTPUT **************************************************************
*	fp0 = default result	
*		
* ALGORITHM ***********************************************************
*	- Store properly signed INF into fp0.
*	- Set FPSR exception status dz bit, ccode inf bit, and 
*	  accrued dz bit.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	t_dz
t_dz:
	tst.b	SRC_EX(a0) 	* no; is src negative?
	bmi.b	t_dz2	* yes

dz_pinf:
	fmove.s	#$7f800000,fp0	* return +INF in fp0
	ori.l	#dzinf_mask,EXC_LV+USER_FPSR(a6) * set I/DZ/ADZ
	rts

	xdef	t_dz2
t_dz2:
	fmove.s	#$ff800000,fp0	* return -INF in fp0
	ori.l	#dzinf_mask+neg_mask,EXC_LV+USER_FPSR(a6) * set N/I/DZ/ADZ
	rts

***
* OPERR exception:	
*	- set FPSR exception status operr bit, condition code 
*	  nan bit; Store default NAN into fp0
***
	xdef	t_operr
t_operr:
	ori.l	#opnan_mask,EXC_LV+USER_FPSR(a6) * set NaN/OPERR/AIOP
	fmovem.x	qnan(pc),fp0	* return default NAN in fp0
	rts

***
* Extended DENORM:	
* 	- For all functions that have a denormalized input and
*	  that f(x)=x, this is the entry point.
*	- we only return the EXOP here if either underflow or
*	  inexact is enabled.	
***

* Entry point for scale w/ extended denorm. The function does
* NOT set INEX2/AUNFL/AINEX.
	xdef	t_resdnrm
t_resdnrm:
	ori.l	#unfl_mask,EXC_LV+USER_FPSR(a6) * set UNFL
	bra.b	xdnrm_con

	xdef	t_extdnrm
t_extdnrm:
	ori.l	#unfinx_mask,EXC_LV+USER_FPSR(a6) * set UNFL/INEX2/AUNFL/AINEX

xdnrm_con:
	move.l	a0,a1	* make copy of src ptr
	move.l	d0,d1	* make copy of rnd prec,mode
	andi.b	#$c0,d1	* extended precision?
	bne.b	xdnrm_sd	* no

* result precision is extended.
	tst.b	LOCAL_EX(a0)	* is denorm negative?
	bpl.b	xdnrm_exit	* no

	bset	#neg_bit,EXC_LV+FPSR_CC(a6)	* yes; set 'N' ccode bit
	bra.b	xdnrm_exit

* result precision is single or double
xdnrm_sd:
	move.l	a1,-(sp)
	tst.b	LOCAL_EX(a0)	* is denorm pos or neg?
	smi.b	d1	* set d0 accodingly
	bsr.l	unf_sub
	move.l	(sp)+,a1
xdnrm_exit:
	fmovem.x	(a0),fp0	* return default result in fp0

	move.b	EXC_LV+FPCR_ENABLE(a6),d0
	andi.b	#$0a,d0	* is UNFL or INEX enabled?
	bne.b	xdnrm_ena	* yes
	rts

****************
* unfl enabled *
****************
* we have a DENORM that needs to be converted into an EXOP.
* so, normalize the mantissa, add $6000 to the new exponent,
* and return the result in fp1.
xdnrm_ena:
	move.w	LOCAL_EX(a1),EXC_LV+FP_SCR0_EX(a6)
	move.l	LOCAL_HI(a1),EXC_LV+FP_SCR0_HI(a6)
	move.l	LOCAL_LO(a1),EXC_LV+FP_SCR0_LO(a6)

	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm	* normalize mantissa
	addi.l	#$6000,d0	* add extra bias
	andi.w	#$8000,EXC_LV+FP_SCR0_EX(a6)	* keep old sign
	or.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent

	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

***
* UNFL exception:	
* 	- This routine is for cases where even an EXOP isn't
*  	  large enough to hold the range of this result.
*	  In such a case, the EXOP equals zero.
*  	- Return the default result to the proper precision 
*	  with the sign of this result being the same as that
*	  of the src operand.	
* 	- t_unfl2() is provided to force the result sign to 
*	  positive which is the desired result for fetox().
***
	xdef	t_unfl
t_unfl:
	ori.l	#unfinx_mask,EXC_LV+USER_FPSR(a6) * set UNFL/INEX2/AUNFL/AINEX

	tst.b	(a0)	* is result pos or neg?
	smi.b	d1	* set d1 accordingly
	bsr.l	unf_sub	* calc default unfl result
	fmovem.x	(a0),fp0	* return default result in fp0

	fmove.s	#$00000000,fp1	* return EXOP in fp1
	rts

* t_unfl2 ALWAYS tells unf_sub to create a positive result
	xdef	t_unfl2
t_unfl2:
	ori.l	#unfinx_mask,EXC_LV+USER_FPSR(a6) * set UNFL/INEX2/AUNFL/AINEX

	sf.b	d1	* set d0 to represent positive
	bsr.l	unf_sub	* calc default unfl result
	fmovem.x	(a0),fp0	* return default result in fp0

	fmove.s	#$0000000,fp1	* return EXOP in fp1
	rts

***
* OVFL exception:	
* 	- This routine is for cases where even an EXOP isn't
*  	  large enough to hold the range of this result.
* 	- Return the default result to the proper precision 
*	  with the sign of this result being the same as that 
*	  of the src operand.	
* 	- t_ovfl2() is provided to force the result sign to 
*	  positive which is the desired result for fcosh().
* 	- t_ovfl_sc() is provided for scale() which only sets 
*	  the inexact bits if the number is inexact for the 
*	  precision indicated.	
***

	xdef	t_ovfl_sc
t_ovfl_sc:
	ori.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set OVFL/AOVFL/AINEX

	move.b	d0,d1	* fetch rnd mode/prec
	andi.b	#$c0,d1	* extract rnd prec
	beq.b	ovfl_work	* prec is extended

	tst.b	LOCAL_HI(a0)	* is dst a DENORM?
	bmi.b	ovfl_sc_norm	* no

* dst op is a DENORM. we have to normalize the mantissa to see if the
* result would be inexact for the given precision. make a copy of the
* dst so we don't screw up the version passed to us.
	move.w	LOCAL_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	LOCAL_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	LOCAL_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	lea	EXC_LV+FP_SCR0(a6),a0	* pass ptr to EXC_LV+FP_SCR0
	movem.l	d0-d1/a0,-(sp)	* save d0-d1/a0
	bsr.l	norm	* normalize mantissa
	movem.l	(sp)+,d0-d1/a0	* restore d0-d1/a0

ovfl_sc_norm:
	ICMP.b	d1,#$40	* is prec dbl?
	bne.b	ovfl_sc_dbl	* no; sgl
ovfl_sc_sgl:
	tst.l	LOCAL_LO(a0)	* is lo lw of sgl set?
	bne.b	ovfl_sc_inx	* yes
	tst.b	3+LOCAL_HI(a0)	* is lo byte of hi lw set?
	bne.b	ovfl_sc_inx	* yes
	bra.b	ovfl_work	* don't set INEX2
ovfl_sc_dbl:
	move.l	LOCAL_LO(a0),d1	* are any of lo 11 bits of
	andi.l	#$7ff,d1	* dbl mantissa set?
	beq.b	ovfl_work	* no; don't set INEX2
ovfl_sc_inx:
	ori.l	#inex2_mask,EXC_LV+USER_FPSR(a6) * set INEX2
	bra.b	ovfl_work	* continue

	xdef	t_ovfl
t_ovfl:
	ori.l	#ovfinx_mask,EXC_LV+USER_FPSR(a6) * set OVFL/INEX2/AOVFL/AINEX

ovfl_work:
	tst.b	LOCAL_EX(a0)	* what is the sign?
	smi.b	d1	* set d1 accordingly
	bsr.l	ovf_res	* calc default ovfl result
	move.b	d0,EXC_LV+FPSR_CC(a6)	* insert new ccodes
	fmovem.x	(a0),fp0	* return default result in fp0

	fmove.s	#$00000000,fp1	* return EXOP in fp1
	rts

* t_ovfl2 ALWAYS tells ovf_res to create a positive result
	xdef	t_ovfl2
t_ovfl2:
	ori.l	#ovfinx_mask,EXC_LV+USER_FPSR(a6) * set OVFL/INEX2/AOVFL/AINEX

	sf.b	d1	* clear sign flag for positive
	bsr.l	ovf_res	* calc default ovfl result
	move.b	d0,EXC_LV+FPSR_CC(a6)	* insert new ccodes
	fmovem.x	(a0),fp0	* return default result in fp0

	fmove.s	#$00000000,fp1	* return EXOP in fp1
	rts

***
* t_catch(): 	
*	- the last operation of a transcendental emulation
* 	  routine may have caused an underflow or overflow. 
* 	  we find out if this occurred by doing an fsave and 
*	  checking the exception bit. if one did occur, then we
*	  jump to fgen_except() which creates the default
*	  result and EXOP for us.
***
	xdef	t_catch
t_catch:

	fsave	-(sp)
	tst.b	$2(sp)
	bmi.b	catch
	add.l	#$c,sp

***
* INEX2 exception:	
*	- The inex2 and ainex bits are set.
***
	xdef	t_inx2
t_inx2:
	fblt.w	t_minx2
	fbeq.w	inx2_zero

	xdef	t_pinx2
t_pinx2:
	ori.w	#inx2a_mask,2+EXC_LV+USER_FPSR(a6) * set INEX2/AINEX
	rts

	xdef	t_minx2
t_minx2:
	ori.l	#inx2a_mask+neg_mask,EXC_LV+USER_FPSR(a6) * set N/INEX2/AINEX
	rts

inx2_zero:
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)
	ori.w	#inx2a_mask,2+EXC_LV+USER_FPSR(a6) * set INEX2/AINEX
	rts

* an underflow or overflow exception occurred.
* we must set INEX/AINEX since the fmul/fdiv/fmov emulation may not!
catch:
	ori.w	#inx2a_mask,EXC_LV+FPSR_EXCEPT(a6)
catch2:
	bsr.l	fgen_except
	add.l	#$c,sp
	rts

	xdef	t_catch2
t_catch2:

	fsave	-(sp)

	tst.b	$2(sp)
	bmi.b	catch2
	add.l	#$c,sp

	fmove.l	fpsr,d0
	or.l	d0,EXC_LV+USER_FPSR(a6)

	rts

**-------------------------------------------------------------------------------------------------

**-------------------------------------------------------------------------------------------------
* unf_res(): underflow default result calculation for transcendentals
*		
* INPUT:	
* 	d0   : rnd mode,precision	
* 	d1.b : sign bit of result ('11111111 = (-) ; '00000000 = (+))
* OUTPUT:	
*	a0   : points to result (in instruction memory)
**-------------------------------------------------------------------------------------------------
unf_sub:
	ori.l	#unfinx_mask,EXC_LV+USER_FPSR(a6)

	andi.w	#$10,d1	* keep sign bit in 4th spot

	lsr.b	#$4,d0	* shift rnd prec,mode to lo bits
	andi.b	#$f,d0	* strip hi rnd mode bit
	or.b	d1,d0	* concat {sgn,mode,prec}

	move.l	d0,d1	* make a copy
	lsl.b	#$1,d1	* mult index 2 by 2

	move.b	((tbl_unf_cc).b,pc,d0.w*1),EXC_LV+FPSR_CC(a6) * insert ccode bits
	lea	((tbl_unf_result).b,pc,d1.w*8),a0 * grab result ptr
	rts

tbl_unf_cc:
	dc.b	$4, $4, $4, $0
	dc.b	$4, $4, $4, $0
	dc.b	$4, $4, $4, $0
	dc.b	$0, $0, $0, $0
	dc.b	$8+$4, $8+$4, $8, $8+$4
	dc.b	$8+$4, $8+$4, $8, $8+$4
	dc.b	$8+$4, $8+$4, $8, $8+$4

tbl_unf_result:
	dc.l	$00000000, $00000000, $00000000, $0 * ZERO;ext
	dc.l	$00000000, $00000000, $00000000, $0 * ZERO;ext
	dc.l	$00000000, $00000000, $00000000, $0 * ZERO;ext
	dc.l	$00000000, $00000000, $00000001, $0 * MIN; ext

	dc.l	$3f810000, $00000000, $00000000, $0 * ZERO;sgl
	dc.l	$3f810000, $00000000, $00000000, $0 * ZERO;sgl
	dc.l	$3f810000, $00000000, $00000000, $0 * ZERO;sgl
	dc.l	$3f810000, $00000100, $00000000, $0 * MIN; sgl

	dc.l	$3c010000, $00000000, $00000000, $0 * ZERO;dbl
	dc.l	$3c010000, $00000000, $00000000, $0 * ZER0;dbl
	dc.l	$3c010000, $00000000, $00000000, $0 * ZERO;dbl
	dc.l	$3c010000, $00000000, $00000800, $0 * MIN; dbl

	dc.l	$0,$0,$0,$0
	dc.l	$0,$0,$0,$0
	dc.l	$0,$0,$0,$0
	dc.l	$0,$0,$0,$0
	
	dc.l	$80000000, $00000000, $00000000, $0 * ZERO;ext
	dc.l	$80000000, $00000000, $00000000, $0 * ZERO;ext
	dc.l	$80000000, $00000000, $00000001, $0 * MIN; ext
	dc.l	$80000000, $00000000, $00000000, $0 * ZERO;ext

	dc.l	$bf810000, $00000000, $00000000, $0 * ZERO;sgl
	dc.l	$bf810000, $00000000, $00000000, $0 * ZERO;sgl
	dc.l	$bf810000, $00000100, $00000000, $0 * MIN; sgl
	dc.l	$bf810000, $00000000, $00000000, $0 * ZERO;sgl

	dc.l	$bc010000, $00000000, $00000000, $0 * ZERO;dbl
	dc.l	$bc010000, $00000000, $00000000, $0 * ZERO;dbl
	dc.l	$bc010000, $00000000, $00000800, $0 * MIN; dbl
	dc.l	$bc010000, $00000000, $00000000, $0 * ZERO;dbl

************************************************************

**-------------------------------------------------------------------------------------------------
* src_zero(): Return signed zero according to sign of src operand.
**-------------------------------------------------------------------------------------------------
	xdef	src_zero
src_zero:
	tst.b	SRC_EX(a0)	* get sign of src operand
	bmi.b	ld_mzero	* if neg, load neg zero

*
* ld_pzero(): return a positive zero.
*
	xdef	ld_pzero
ld_pzero:
	fmove.s	#$00000000,fp0	* load +0
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts

* ld_mzero(): return a negative zero.
	xdef	ld_mzero
ld_mzero:
	fmove.s	#$80000000,fp0	* load -0
	move.b	#neg_bmask+z_bmask,EXC_LV+FPSR_CC(a6) * set 'N','Z' ccode bits
	rts

**-------------------------------------------------------------------------------------------------
* dst_zero(): Return signed zero according to sign of dst operand.
**-------------------------------------------------------------------------------------------------
	xdef	dst_zero
dst_zero:
	tst.b	DST_EX(a1) 	* get sign of dst operand
	bmi.b	ld_mzero	* if neg, load neg zero
	bra.b	ld_pzero	* load positive zero

**-------------------------------------------------------------------------------------------------
* src_inf(): Return signed inf according to sign of src operand.
**-------------------------------------------------------------------------------------------------
	xdef	src_inf
src_inf:
	tst.b	SRC_EX(a0) 	* get sign of src operand
	bmi.b	ld_minf	* if negative branch

*
* ld_pinf(): return a positive infinity.
*
	xdef	ld_pinf
ld_pinf:
	fmove.s	#$7f800000,fp0	* load +INF
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'INF' ccode bit
	rts

*
* ld_minf():return a negative infinity.
*
	xdef	ld_minf
ld_minf:
	fmove.s	#$ff800000,fp0	* load -INF
	move.b	#neg_bmask+inf_bmask,EXC_LV+FPSR_CC(a6) * set 'N','I' ccode bits
	rts

**-------------------------------------------------------------------------------------------------
* dst_inf(): Return signed inf according to sign of dst operand.
**-------------------------------------------------------------------------------------------------
	xdef	dst_inf
dst_inf:
	tst.b	DST_EX(a1) 	* get sign of dst operand
	bmi.b	ld_minf	* if negative branch
	bra.b	ld_pinf

	xdef	szr_inf
***
* szr_inf(): Return +ZERO for a negative src operand or
*	            +INF for a positive src operand.
*	     Routine used for fetox, ftwotox, and ftentox.
***
szr_inf:
	tst.b	SRC_EX(a0)	* check sign of source
	bmi.b	ld_pzero
	bra.b	ld_pinf

**-------------------------------------------------------------------------------------------------
* sopr_inf(): Return +INF for a positive src operand or
*	      jump to operand error routine for a negative src operand.
*	      Routine used for flogn, flognp1, flog10, and flog2.
**-------------------------------------------------------------------------------------------------
	xdef	sopr_inf
sopr_inf:
	tst.b	SRC_EX(a0)	* check sign of source
	bmi.w	t_operr
	bra.b	ld_pinf

***
* setoxm1i(): Return minus one for a negative src operand or
*	      positive infinity for a positive src operand.
*	      Routine used for fetoxm1.
***
	xdef	setoxm1i
setoxm1i:
	tst.b	SRC_EX(a0)	* check sign of source
	bmi.b	ld_mone
	bra.b	ld_pinf

**-------------------------------------------------------------------------------------------------
* src_one(): Return signed one according to sign of src operand.
**-------------------------------------------------------------------------------------------------
	xdef	src_one
src_one:
	tst.b	SRC_EX(a0) 	* check sign of source
	bmi.b	ld_mone

*
* ld_pone(): return positive one.
*
	xdef	ld_pone
ld_pone:
	fmove.s	#$3f800000,fp0	* load +1
	clr.b	EXC_LV+FPSR_CC(a6)
	rts

*
* ld_mone(): return negative one.
*
	xdef	ld_mone
ld_mone:
	fmove.s	#$bf800000,fp0	* load -1
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

ppiby2:	dc.l	$3fff0000, $c90fdaa2, $2168c235
mpiby2:	dc.l	$bfff0000, $c90fdaa2, $2168c235

***
* spi_2(): Return signed PI/2 according to sign of src operand.
***
	xdef	spi_2
spi_2:
	tst.b	SRC_EX(a0) 	* check sign of source
	bmi.b	ld_mpi2

*
* ld_ppi2(): return positive PI/2.
*
	xdef	ld_ppi2
ld_ppi2:
	fmove.l	d0,fpcr
	fmove.x	ppiby2(pc),fp0	* load +pi/2
	bra.w	t_pinx2	* set INEX2

*
* ld_mpi2(): return negative PI/2.
*
	xdef	ld_mpi2
ld_mpi2:
	fmove.l	d0,fpcr
	fmove.x	mpiby2(pc),fp0	* load -pi/2
	bra.w	t_minx2	* set INEX2

****************************************************
* The following routines give support for fsincos. *
****************************************************

*
* ssincosz(): When the src operand is ZERO, store a one in the
* 	      cosine register and return a ZERO in fp0 w/ the same sign
*	      as the src operand.
*
	xdef	ssincosz
ssincosz:
	fmove.s	#$3f800000,fp1
	tst.b	SRC_EX(a0)	* test sign
	bpl.b	sincoszp
	fmove.s	#$80000000,fp0	* return sin result in fp0
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6)
	bra.b	sto_cos	* store cosine result
sincoszp:
	fmove.s	#$00000000,fp0	* return sin result in fp0
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)
	bra.b	sto_cos	* store cosine result

*
* ssincosi(): When the src operand is INF, store a QNAN in the cosine
*	      register and jump to the operand error routine for negative
*	      src operands.
*
	xdef	ssincosi
ssincosi:
	fmove.x	qnan(pc),fp1	* load NAN
	bsr.l	sto_cos	* store cosine result
	bra.w	t_operr

*
* ssincosqnan(): When the src operand is a QNAN, store the QNAN in the cosine
* 	 register and branch to the src QNAN routine.
*
	xdef	ssincosqnan
ssincosqnan:
	fmove.x	LOCAL_EX(a0),fp1
	bsr.l	sto_cos
	bra.w	src_qnan

*
* ssincossnan(): When the src operand is an SNAN, store the SNAN w/ the SNAN bit set
*	 in the cosine register and branch to the src SNAN routine.
*
	xdef	ssincossnan
ssincossnan:
	fmove.x	LOCAL_EX(a0),fp1
	bsr.l	sto_cos
	bra.w	src_snan

**********

**-------------------------------------------------------------------------------------------------
* sto_cos(): store fp1 to the fpreg designated by the CMDREG dst field.
*	     fp1 holds the result of the cosine portion of ssincos().
*	     the value in fp1 will not take any exceptions when moved.
* INPUT:	
*	fp1 : fp value to store	
* MODIFIED:	
*	d0	
**-------------------------------------------------------------------------------------------------
	xdef	sto_cos
sto_cos:
	move.b	1+EXC_LV+EXC_CMDREG(a6),d0
	andi.w	#$7,d0
	move.w	((tbl_sto_cos).b,pc,d0.w*2),d0
	jmp	((tbl_sto_cos).b,pc,d0.w*1)

tbl_sto_cos:
	dc.w	sto_cos_0 - tbl_sto_cos
	dc.w	sto_cos_1 - tbl_sto_cos
	dc.w	sto_cos_2 - tbl_sto_cos
	dc.w	sto_cos_3 - tbl_sto_cos
	dc.w	sto_cos_4 - tbl_sto_cos
	dc.w	sto_cos_5 - tbl_sto_cos
	dc.w	sto_cos_6 - tbl_sto_cos
	dc.w	sto_cos_7 - tbl_sto_cos

sto_cos_0:
	fmovem.x	fp1,EXC_LV+EXC_FP0(a6)
	rts
sto_cos_1:
	fmovem.x	fp1,EXC_LV+EXC_FP1(a6)
	rts
sto_cos_2:
	fmove.x 	fp1,fp2
	rts
sto_cos_3:
	fmove.x	fp1,fp3
	rts
sto_cos_4:
	fmove.x	fp1,fp4
	rts
sto_cos_5:
	fmove.x	fp1,fp5
	rts
sto_cos_6:
	fmove.x	fp1,fp6
	rts
sto_cos_7:
	fmove.x	fp1,fp7
	rts

****
	xdef	smod_sdnrm
	xdef	smod_snorm
smod_sdnrm:
smod_snorm:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	smod
	ICMP.b	d1,#ZERO
	beq.w	smod_zro
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	smod
	ICMP.b	d1,#SNAN
	beq.l	dst_snan
	bra.l	dst_qnan

	xdef	smod_szero
smod_szero:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	t_operr
	ICMP.b	d1,#ZERO
	beq.l	t_operr
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	t_operr
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

	xdef	smod_sinf
smod_sinf:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	smod_fpn
	ICMP.b	d1,#ZERO
	beq.l	smod_zro
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	smod_fpn
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

smod_zro:
srem_zro:
	move.b	SRC_EX(a0),d1	* get src sign
	move.b	DST_EX(a1),d0	* get dst sign
	eor.b	d0,d1	* get qbyte sign
	andi.b	#$80,d1
	move.b	d1,EXC_LV+FPSR_QBYTE(a6)
	tst.b	d0
	bpl.w	ld_pzero
	bra.w	ld_mzero

smod_fpn:
srem_fpn:
	clr.b	EXC_LV+FPSR_QBYTE(a6)
	move.l	d0,-(sp)
	move.b	SRC_EX(a0),d1	* get src sign
	move.b	DST_EX(a1),d0	* get dst sign
	eor.b	d0,d1	* get qbyte sign
	andi.b	#$80,d1
	move.b	d1,EXC_LV+FPSR_QBYTE(a6)
	ICMP.b	EXC_LV+DTAG(a6),#DENORM
	bne.b	smod_nrm
	lea	DST(a1),a0
	move.l	(sp)+,d0
	bra	t_resdnrm
smod_nrm:
	fmove.l	(sp)+,fpcr
	fmove.x	DST(a1),fp0
	tst.b	DST_EX(a1)
	bmi.b	smod_nrm_neg
	rts

smod_nrm_neg:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode
	rts

**-------------------------------------------------------------------------------------------------
	xdef	srem_snorm
	xdef	srem_sdnrm
srem_sdnrm:
srem_snorm:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	srem
	ICMP.b	d1,#ZERO
	beq.w	srem_zro
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	srem
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

	xdef	srem_szero
srem_szero:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	t_operr
	ICMP.b	d1,#ZERO
	beq.l	t_operr
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	t_operr
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

	xdef	srem_sinf
srem_sinf:
	move.b	EXC_LV+DTAG(a6),d1
	beq.w	srem_fpn
	ICMP.b	d1,#ZERO
	beq.w	srem_zro
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	srem_fpn
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

**-------------------------------------------------------------------------------------------------
	xdef	sscale_snorm
	xdef	sscale_sdnrm
sscale_snorm:
sscale_sdnrm:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	sscale
	ICMP.b	d1,#ZERO
	beq.l	dst_zero
	ICMP.b	d1,#INF
	beq.l	dst_inf
	ICMP.b	d1,#DENORM
	beq.l	sscale
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

	xdef	sscale_szero
sscale_szero:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	sscale
	ICMP.b	d1,#ZERO
	beq.l	dst_zero
	ICMP.b	d1,#INF
	beq.l	dst_inf
	ICMP.b	d1,#DENORM
	beq.l	sscale
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	bra.l	dst_snan

	xdef	sscale_sinf
sscale_sinf:
	move.b	EXC_LV+DTAG(a6),d1
	beq.l	t_operr
	ICMP.b	d1,#QNAN
	beq.l	dst_qnan
	ICMP.b	d1,#SNAN
	beq.l	dst_snan
	bra.l	t_operr

**********

*
* sop_sqnan(): The src op for frem/fmod/fscale was a QNAN.
*
	xdef	sop_sqnan
sop_sqnan:
	move.b	EXC_LV+DTAG(a6),d1
	ICMP.b	d1,#QNAN
	beq.b	dst_qnan
	ICMP.b	d1,#SNAN
	beq.b	dst_snan
	bra.b	src_qnan

*
* sop_ssnan(): The src op for frem/fmod/fscale was an SNAN.
*
	xdef	sop_ssnan
sop_ssnan:
	move.b	EXC_LV+DTAG(a6),d1
	ICMP.b	d1,#QNAN
	beq.b	dst_qnan_src_snan
	ICMP.b	d1,#SNAN
	beq.b	dst_snan
	bra.b	src_snan

dst_qnan_src_snan:
	ori.l	#snaniop_mask,EXC_LV+USER_FPSR(a6) * set NAN/SNAN/AIOP
	bra.b	dst_qnan

*
* dst_qnan(): Return the dst SNAN w/ the SNAN bit set.
*
	xdef	dst_snan
dst_snan:
	fmove.x	DST(a1),fp0	* the fmove sets the SNAN bit
	fmove.l	fpsr,d0	* catch resulting status
	or.l	d0,EXC_LV+USER_FPSR(a6)	* store status
	rts

*
* dst_qnan(): Return the dst QNAN.
*
	xdef	dst_qnan
dst_qnan:
	fmove.x	DST(a1),fp0	* return the non-signalling nan
	tst.b	DST_EX(a1)	* set ccodes according to QNAN sign
	bmi.b	dst_qnan_m
dst_qnan_p:
	move.b	#nan_bmask,EXC_LV+FPSR_CC(a6)
	rts
dst_qnan_m:
	move.b	#neg_bmask+nan_bmask,EXC_LV+FPSR_CC(a6)
	rts

*
* src_snan(): Return the src SNAN w/ the SNAN bit set.
*
	xdef	src_snan
src_snan:
	fmove.x	SRC(a0),fp0	* the fmove sets the SNAN bit
	fmove.l	fpsr,d0	* catch resulting status
	or.l	d0,EXC_LV+USER_FPSR(a6)	* store status
	rts

*
* src_qnan(): Return the src QNAN.
*
	xdef	src_qnan
src_qnan:
	fmove.x	SRC(a0),fp0	* return the non-signalling nan
	tst.b	SRC_EX(a0)	* set ccodes according to QNAN sign
	bmi.b	dst_qnan_m
src_qnan_p:
	move.b	#nan_bmask,EXC_LV+FPSR_CC(a6)
	rts
src_qnan_m:
	move.b	#neg_bmask+nan_bmask,EXC_LV+FPSR_CC(a6)
	rts

*
* fkern2.s:
*	These entry points are used by the exception handler
* routines where an instruction is selected by an index into
* a large jump table corresponding to a given instruction which 
* has been decoded. Flow continues here where we now decode 
* further accoding to the source operand type.
*

	xdef	fsinh
fsinh:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	ssinh
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	src_inf
	ICMP.b	d1,#DENORM
	beq.l	ssinhd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	flognp1
flognp1:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	slognp1
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	sopr_inf
	ICMP.b	d1,#DENORM
	beq.l	slognp1d
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fetoxm1
fetoxm1:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	setoxm1
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	setoxm1i
	ICMP.b	d1,#DENORM
	beq.l	setoxm1d
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	ftanh
ftanh:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	stanh
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	src_one
	ICMP.b	d1,#DENORM
	beq.l	stanhd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fatan
fatan:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	satan
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	spi_2
	ICMP.b	d1,#DENORM
	beq.l	satand
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fasin
fasin:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	sasin
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	sasind
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fatanh
fatanh:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	satanh
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	satanhd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fsine
fsine:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	ssin
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	ssind
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	ftan
ftan:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	stan
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	stand
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fetox
fetox:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	setox
	ICMP.b	d1,#ZERO
	beq.l	ld_pone
	ICMP.b	d1,#INF
	beq.l	szr_inf
	ICMP.b	d1,#DENORM
	beq.l	setoxd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	ftwotox
ftwotox:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	stwotox
	ICMP.b	d1,#ZERO
	beq.l	ld_pone
	ICMP.b	d1,#INF
	beq.l	szr_inf
	ICMP.b	d1,#DENORM
	beq.l	stwotoxd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	ftentox
ftentox:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	stentox
	ICMP.b	d1,#ZERO
	beq.l	ld_pone
	ICMP.b	d1,#INF
	beq.l	szr_inf
	ICMP.b	d1,#DENORM
	beq.l	stentoxd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	flogn
flogn:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	slogn
	ICMP.b	d1,#ZERO
	beq.l	t_dz2
	ICMP.b	d1,#INF
	beq.l	sopr_inf
	ICMP.b	d1,#DENORM
	beq.l	slognd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	flog10
flog10:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	slog10
	ICMP.b	d1,#ZERO
	beq.l	t_dz2
	ICMP.b	d1,#INF
	beq.l	sopr_inf
	ICMP.b	d1,#DENORM
	beq.l	slog10d
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	flog2
flog2:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	slog2
	ICMP.b	d1,#ZERO
	beq.l	t_dz2
	ICMP.b	d1,#INF
	beq.l	sopr_inf
	ICMP.b	d1,#DENORM
	beq.l	slog2d
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fcosh
fcosh:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	scosh
	ICMP.b	d1,#ZERO
	beq.l	ld_pone
	ICMP.b	d1,#INF
	beq.l	ld_pinf
	ICMP.b	d1,#DENORM
	beq.l	scoshd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	facos
facos:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	sacos
	ICMP.b	d1,#ZERO
	beq.l	ld_ppi2
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	sacosd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fcos
fcos:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	scos
	ICMP.b	d1,#ZERO
	beq.l	ld_pone
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	scosd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fgetexp
fgetexp:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	sgetexp
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	sgetexpd
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fgetman
fgetman:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	sgetman
	ICMP.b	d1,#ZERO
	beq.l	src_zero
	ICMP.b	d1,#INF
	beq.l	t_operr
	ICMP.b	d1,#DENORM
	beq.l	sgetmand
	ICMP.b	d1,#QNAN
	beq.l	src_qnan
	bra.l	src_snan

	xdef	fsincos
fsincos:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	ssincos
	ICMP.b	d1,#ZERO
	beq.l	ssincosz
	ICMP.b	d1,#INF
	beq.l	ssincosi
	ICMP.b	d1,#DENORM
	beq.l	ssincosd
	ICMP.b	d1,#QNAN
	beq.l	ssincosqnan
	bra.l	ssincossnan

	xdef	fmod
fmod:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	smod_snorm
	ICMP.b	d1,#ZERO
	beq.l	smod_szero
	ICMP.b	d1,#INF
	beq.l	smod_sinf
	ICMP.b	d1,#DENORM
	beq.l	smod_sdnrm
	ICMP.b	d1,#QNAN
	beq.l	sop_sqnan
	bra.l	sop_ssnan

	xdef	frem
frem:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	srem_snorm
	ICMP.b	d1,#ZERO
	beq.l	srem_szero
	ICMP.b	d1,#INF
	beq.l	srem_sinf
	ICMP.b	d1,#DENORM
	beq.l	srem_sdnrm
	ICMP.b	d1,#QNAN
	beq.l	sop_sqnan
	bra.l	sop_ssnan

	xdef	fscale
fscale:
	move.b	EXC_LV+STAG(a6),d1
	beq.l	sscale_snorm
	ICMP.b	d1,#ZERO
	beq.l	sscale_szero
	ICMP.b	d1,#INF
	beq.l	sscale_sinf
	ICMP.b	d1,#DENORM
	beq.l	sscale_sdnrm
	ICMP.b	d1,#QNAN
	beq.l	sop_sqnan
	bra.l	sop_ssnan

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fgen_except(): catch an exception during transcendental 
*	       emulation	
*		
* xdef **
*	fmul() - emulate a multiply instruction	* 
*	fadd() - emulate an add instruction
*	fin() - emulate an fmove instruction
*		
* INPUT ***************************************************************
*	fp0 = destination operand	
*	d0  = type of instruction that took exception
*	fsave frame = source operand	
* 		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP	
*		
* ALGORITHM ***********************************************************
* 	An exception occurred on the last instruction of the 
* transcendental emulation. hopefully, this won't be happening much 
* because it will be VERY slow.	
* 	The only exceptions capable of passing through here are
* Overflow, Underflow, and Unsupported Data Type.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fgen_except
fgen_except:
	ICMP.b	$3(sp),#$7	* is exception UNSUPP?
	beq.b	fge_unsupp	* yes

	move.b	#NORM,EXC_LV+STAG(a6)

fge_cont:
	move.b	#NORM,EXC_LV+DTAG(a6)

* ok, I have a problem with putting the dst op at EXC_LV+FP_DST. the emulation
* routines aren't supposed to alter the operands but we've just squashed
* EXC_LV+FP_DST here...

* 8/17/93 - this turns out to be more of a "cleanliness" standpoint
* then a potential bug. to begin with, only the dyadic functions
* frem,fmod, and fscale would get the dst trashed here. But, for
* the 060SP, the EXC_LV+FP_DST is never used again anyways.

	fmovem.x	fp0,EXC_LV+FP_DST(a6)	* dst op is in fp0

	lea	$4(sp),a0	* pass: ptr to src op
	lea	EXC_LV+FP_DST(a6),a1	* pass: ptr to dst op

	ICMP.b	d1,#FMOV_OP
	beq.b	fge_fin	* it was an "fmov"
	ICMP.b	d1,#FADD_OP
	beq.b	fge_fadd	* it was an "fadd"
fge_fmul:
	bsr.l	fmul
	rts
fge_fadd:
	bsr.l	fadd
	rts
fge_fin:
	bsr.l	fin
	rts

fge_unsupp:
	move.b	#DENORM,EXC_LV+STAG(a6)
	bra.b	fge_cont

*
* This table holds the offsets of the emulation routines for each individual
* math operation relative to the address of this table. Included are
* routines like fadd/fmul/fabs as well as the transcendentals.
* The location within the table is determined by the extension bits of the
* operation longword.
*

	illegal
	dc.w 	$109
tbl_unsupp:
	dc.l	fin	 	- tbl_unsupp	* 00: fmove
	dc.l	fint	 	- tbl_unsupp	* 01: fint
	dc.l	fsinh	 	- tbl_unsupp	* 02: fsinh
	dc.l	fintrz	 	- tbl_unsupp	* 03: fintrz
	dc.l	fsqrt	 	- tbl_unsupp	* 04: fsqrt
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	flognp1	- tbl_unsupp	* 06: flognp1
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fetoxm1	- tbl_unsupp	* 08: fetoxm1
	dc.l	ftanh	- tbl_unsupp	* 09: ftanh
	dc.l	fatan	- tbl_unsupp	* 0a: fatan
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fasin	- tbl_unsupp	* 0c: fasin
	dc.l	fatanh	- tbl_unsupp	* 0d: fatanh
	dc.l	fsine	- tbl_unsupp	* 0e: fsin
	dc.l	ftan	- tbl_unsupp	* 0f: ftan
	dc.l	fetox	- tbl_unsupp	* 10: fetox
	dc.l	ftwotox	- tbl_unsupp	* 11: ftwotox
	dc.l	ftentox	- tbl_unsupp	* 12: ftentox
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	flogn	- tbl_unsupp	* 14: flogn
	dc.l	flog10	- tbl_unsupp	* 15: flog10
	dc.l	flog2	- tbl_unsupp	* 16: flog2
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fabs	- tbl_unsupp 	* 18: fabs
	dc.l	fcosh	- tbl_unsupp	* 19: fcosh
	dc.l	fneg	- tbl_unsupp 	* 1a: fneg
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	facos	- tbl_unsupp	* 1c: facos
	dc.l	fcos	- tbl_unsupp	* 1d: fcos
	dc.l	fgetexp	- tbl_unsupp	* 1e: fgetexp
	dc.l	fgetman	- tbl_unsupp	* 1f: fgetman
	dc.l	fdiv	- tbl_unsupp 	* 20: fdiv
	dc.l	fmod	- tbl_unsupp	* 21: fmod
	dc.l	fadd	- tbl_unsupp 	* 22: fadd
	dc.l	fmul	- tbl_unsupp 	* 23: fmul
	dc.l	fsgldiv	- tbl_unsupp 	* 24: fsgldiv
	dc.l	frem	- tbl_unsupp	* 25: frem
	dc.l	fscale	- tbl_unsupp	* 26: fscale
	dc.l	fsglmul	- tbl_unsupp 	* 27: fsglmul
	dc.l	fsub	- tbl_unsupp 	* 28: fsub
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsincos	- tbl_unsupp	* 30: fsincos
	dc.l	fsincos	- tbl_unsupp	* 31: fsincos
	dc.l	fsincos	- tbl_unsupp	* 32: fsincos
	dc.l	fsincos	- tbl_unsupp	* 33: fsincos
	dc.l	fsincos	- tbl_unsupp	* 34: fsincos
	dc.l	fsincos	- tbl_unsupp	* 35: fsincos
	dc.l	fsincos	- tbl_unsupp	* 36: fsincos
	dc.l	fsincos	- tbl_unsupp	* 37: fsincos
	dc.l	fcmp	- tbl_unsupp 	* 38: fcmp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	ftst	- tbl_unsupp 	* 3a: ftst
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsin	- tbl_unsupp 	* 40: fsmove
	dc.l	fssqrt	- tbl_unsupp 	* 41: fssqrt
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fdin	- tbl_unsupp	* 44: fdmove
	dc.l	fdsqrt	- tbl_unsupp 	* 45: fdsqrt
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsabs	- tbl_unsupp 	* 58: fsabs
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsneg	- tbl_unsupp 	* 5a: fsneg
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fdabs	- tbl_unsupp	* 5c: fdabs
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fdneg	- tbl_unsupp 	* 5e: fdneg
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsdiv	- tbl_unsupp	* 60: fsdiv
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fsadd	- tbl_unsupp	* 62: fsadd
	dc.l	fsmul	- tbl_unsupp	* 63: fsmul
	dc.l	fddiv	- tbl_unsupp 	* 64: fddiv
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fdadd	- tbl_unsupp	* 66: fdadd
	dc.l	fdmul	- tbl_unsupp 	* 67: fdmul
	dc.l	fssub	- tbl_unsupp	* 68: fssub
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	tbl_unsupp	- tbl_unsupp
	dc.l	fdsub	- tbl_unsupp 	* 6c: fdsub

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fmul(): emulates the fmul instruction
*	fsmul(): emulates the fsmul instruction
*	fdmul(): emulates the fdmul instruction
*		
* xdef **
*	scale_to_zero_src() - scale src exponent to zero
*	scale_to_zero_dst() - scale dst exponent to zero
*	unf_res() - return default underflow result
*	ovf_res() - return default overflow result
* 	res_qnan() - return QNAN result	
* 	res_snan() - return SNAN result	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	a1 = pointer to extended precision destination operand
*	d0  rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms/denorms into ext/sgl/dbl precision.
*	For norms/denorms, scale the exponents such that a multiply
* instruction won't cause an exception. Use the regular fmul to
* compute a result. Check if the regular operands would have taken
* an exception. If so, return the default overflow/underflow result
* and return the EXOP if exceptions are enabled. Else, scale the 
* result operand to the proper exponent.
*		
**-------------------------------------------------------------------------------------------------

	cnop	0,$10
tbl_fmul_ovfl:
	dc.l	$3fff - $7ffe	* ext_max
	dc.l	$3fff - $407e	* sgl_max
	dc.l	$3fff - $43fe	* dbl_max
tbl_fmul_unfl:
	dc.l	$3fff + $0001	* ext_unfl
	dc.l	$3fff - $3f80	* sgl_unfl
	dc.l	$3fff - $3c00	* dbl_unfl

	xdef	fsmul
fsmul:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl prec
	bra.b	fmul

	xdef	fdmul
fdmul:
	andi.b	#$30,d0
	ori.b	#d_mode*$10,d0	* insert dbl prec

	xdef	fmul
fmul:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1	* combine src tags
	bne.w	fmul_not_norm	* optimize on non-norm input

fmul_norm:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_to_zero_src	* scale src exponent
	move.l	d0,-(sp)	* save scale factor 1

	bsr.l	scale_to_zero_dst	* scale dst exponent

	add.l	d0,(sp)	* SCALE_FACTOR = scale1 + scale2

	move.w	2+EXC_LV+L_SCR3(a6),d1	* fetch precision
	lsr.b	#$6,d1	* shift to lo bits
	move.l	(sp)+,d0	* load S.F.
	ICMP.l	d0,(tbl_fmul_ovfl.w,pc,d1.w*4) * would result ovfl?
	beq.w	fmul_may_ovfl	* result may rnd to overflow
	blt.w	fmul_ovfl	* result will overflow

	ICMP.l	d0,(tbl_fmul_unfl.w,pc,d1.w*4) * would result unfl?
	beq.w	fmul_may_unfl	* result may rnd to no unfl
	bgt.w	fmul_unfl	* result will underflow

*
* NORMAL:
* - the result of the multiply operation will neither overflow nor underflow.
* - do the multiply to the proper precision and rounding mode. 
* - scale the result exponent using the scale factor. if both operands were
* normalized then we really don't need to go through this scaling. but for now,
* this will do.
*
fmul_normal:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply	

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fmul_normal_exit:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts

*
* OVERFLOW:
* - the result of the multiply operation is an overflow.
* - do the multiply to the proper precision and rounding mode in order to
* set the inexact bits.
* - calculate the default result and return it in fp0.
* - if overflow or inexact is enabled, we need a multiply result rounded to
* extended precision. if the original operation was extended, then we have this
* result. if the original operation was single or double, we have to do another
* multiply using extended precision and the correct rounding mode. the result
* of this operation then has its exponent scaled by -$6000 to create the
* exceptional operand.
*
fmul_ovfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply	

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

* save setting this until now because this is where fmul_may_ovfl may jump in
fmul_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fmul_ovfl_ena	* yes

* calculate the default result
fmul_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass rnd prec,mode
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

*
* OVFL is enabled; Create EXOP:
* - if precision is extended, then we have the EXOP. simply bias the exponent
* with an extra -$6000. if the precision is single or double, we need to
* calculate a result rounded to extended precision.
*
fmul_ovfl_ena:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* test the rnd prec
	bne.b	fmul_ovfl_ena_sd	* it's sgl or dbl

fmul_ovfl_ena_cont:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* move result to stack

	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.w	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1	* clear sign bit
	andi.w	#$8000,d2	* keep old sign
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fmul_ovfl_dis

fmul_ovfl_ena_sd:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* keep rnd mode only
	fmove.l	d1,fpcr	* set FPCR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply

	fmove.l	#$0,fpcr	* clear FPCR
	bra.b	fmul_ovfl_ena_cont

*
* may OVERFLOW:
* - the result of the multiply operation MAY overflow.
* - do the multiply to the proper precision and rounding mode in order to
* set the inexact bits.
* - calculate the default result and return it in fp0.
*
fmul_may_ovfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply
	
	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#$2,fp1	* is |result| >= 2.b?
	fbge.w	fmul_ovfl_tst	* yes; overflow has occurred
	
* no, it didn't overflow; we have correct result
	bra.w	fmul_normal_exit

*
* UNDERFLOW:
* - the result of the multiply operation is an underflow.
* - do the multiply to the proper precision and rounding mode in order to
* set the inexact bits.
* - calculate the default result and return it in fp0.
* - if overflow or inexact is enabled, we need a multiply result rounded to
* extended precision. if the original operation was extended, then we have this
* result. if the original operation was single or double, we have to do another
* multiply using extended precision and the correct rounding mode. the result
* of this operation then has its exponent scaled by -$6000 to create the
* exceptional operand.
*
fmul_unfl:	
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

* for fun, let's use only extended precision, round to zero. then, let
* the unf_res() routine figure out all the rest.
* will we get the correct answer.
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fmul_unfl_ena	* yes

fmul_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* unf_res2 may have set 'Z'
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts

*
* UNFL is enabled. 
*
fmul_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fmul_unfl_ena_sd	* no, sgl or dbl

* if the rnd mode is anything but RZ, then we have to re-do the above
* multiplication becuase we used RZ for all.
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

fmul_unfl_ena_cont:
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp1	* execute multiply	

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* save result to stack
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	addi.l	#$6000,d1	* add bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.w	fmul_unfl_dis

fmul_unfl_ena_sd:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* use only rnd mode
	fmove.l	d1,fpcr	* set FPCR

	bra.b	fmul_unfl_ena_cont

* MAY UNDERFLOW:
* -use the correct rounding mode and precision. this code favors operations
* that do not underflow.
fmul_may_unfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute multiply	

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#$2,fp1	* is |result| > 2.b?
	fbgt.w	fmul_normal_exit	* no; no underflow occurred
	fblt.w	fmul_unfl	* yes; underflow occurred

*
* we still don't know if underflow occurred. result is ~ equal to 2. but,
* we don't know if the result was an underflow that rounded up to a 2 or
* a normalized number that rounded down to a 2. so, redo the entire operation
* using RZ as the rounding mode to see what the pre-rounded result is.
* this case should be relatively rare.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst operand

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* keep rnd prec
	ori.b	#rz_mode*$10,d1	* insert RZ

	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmul.x	EXC_LV+FP_SCR0(a6),fp1	* execute multiply

	fmove.l	#$0,fpcr	* clear FPCR
	fabs.x	fp1	* make absolute value
	fcmp.b	#$2,fp1	* is |result| < 2.b?
	fbge.w	fmul_normal_exit	* no; no underflow occurred
	bra.w	fmul_unfl	* yes, underflow occurred

**-------------------------------------------------------------------------------------------------*******

*
* Multiply: inputs are not both normalized; what are they?
*
fmul_not_norm:
	move.w	((tbl_fmul_op).b,pc,d1.w*2),d1
	jmp	((tbl_fmul_op).b,pc,d1.w)

	illegal
	dc.w	$48
tbl_fmul_op:
	dc.w	fmul_norm	- tbl_fmul_op * NORM x NORM
	dc.w	fmul_zero	- tbl_fmul_op * NORM x ZERO
	dc.w	fmul_inf_src	- tbl_fmul_op * NORM x INF
	dc.w	fmul_res_qnan	- tbl_fmul_op * NORM x QNAN
	dc.w	fmul_norm	- tbl_fmul_op * NORM x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * NORM x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

	dc.w	fmul_zero	- tbl_fmul_op * ZERO x NORM
	dc.w	fmul_zero	- tbl_fmul_op * ZERO x ZERO
	dc.w	fmul_res_operr	- tbl_fmul_op * ZERO x INF
	dc.w	fmul_res_qnan	- tbl_fmul_op * ZERO x QNAN
	dc.w	fmul_zero	- tbl_fmul_op * ZERO x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * ZERO x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

	dc.w	fmul_inf_dst	- tbl_fmul_op * INF x NORM
	dc.w	fmul_res_operr	- tbl_fmul_op * INF x ZERO
	dc.w	fmul_inf_dst	- tbl_fmul_op * INF x INF
	dc.w	fmul_res_qnan	- tbl_fmul_op * INF x QNAN
	dc.w	fmul_inf_dst	- tbl_fmul_op * INF x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * INF x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

	dc.w	fmul_res_qnan	- tbl_fmul_op * QNAN x NORM
	dc.w	fmul_res_qnan	- tbl_fmul_op * QNAN x ZERO
	dc.w	fmul_res_qnan	- tbl_fmul_op * QNAN x INF
	dc.w	fmul_res_qnan	- tbl_fmul_op * QNAN x QNAN
	dc.w	fmul_res_qnan	- tbl_fmul_op * QNAN x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * QNAN x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

	dc.w	fmul_norm	- tbl_fmul_op * NORM x NORM
	dc.w	fmul_zero	- tbl_fmul_op * NORM x ZERO
	dc.w	fmul_inf_src	- tbl_fmul_op * NORM x INF
	dc.w	fmul_res_qnan	- tbl_fmul_op * NORM x QNAN
	dc.w	fmul_norm	- tbl_fmul_op * NORM x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * NORM x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x NORM
	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x ZERO
	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x INF
	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x QNAN
	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x DENORM
	dc.w	fmul_res_snan	- tbl_fmul_op * SNAN x SNAN
	dc.w	tbl_fmul_op	- tbl_fmul_op *
	dc.w	tbl_fmul_op	- tbl_fmul_op *

fmul_res_operr:
	bra.l	res_operr
fmul_res_snan:
	bra.l	res_snan
fmul_res_qnan:
	bra.l	res_qnan

*
* Multiply: (Zero x Zero) || (Zero x norm) || (Zero x denorm)
*
	xdef	fmul_zero	* xdef for fsglmul
fmul_zero:
	move.b	SRC_EX(a0),d0	* exclusive or the signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bpl.b	fmul_zero_p	* result ZERO is pos.
fmul_zero_n:
	fmove.s	#$80000000,fp0	* load -ZERO
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set Z/N
	rts
fmul_zero_p:
	fmove.s	#$00000000,fp0	* load +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts

*
* Multiply: (inf x inf) || (inf x norm) || (inf x denorm)
*
* Note: The j-bit for an infinity is a don't-care. However, to be
* strictly compatible w/ the 68881/882, we make sure to return an
* INF w/ the j-bit set if the input INF j-bit was set. Destination
* INFs take priority.
*
	xdef	fmul_inf_dst	* xdef for fsglmul
fmul_inf_dst:
	fmovem.x	DST(a1),fp0	* return INF result in fp0
	move.b	SRC_EX(a0),d0	* exclusive or the signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bpl.b	fmul_inf_dst_p	* result INF is pos.
fmul_inf_dst_n:
	fabs.x	fp0	* clear result sign
	fneg.x	fp0	* set result sign
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set INF/N
	rts
fmul_inf_dst_p:
	fabs.x	fp0	* clear result sign
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set INF
	rts

	xdef	fmul_inf_src	* xdef for fsglmul
fmul_inf_src:
	fmovem.x	SRC(a0),fp0	* return INF result in fp0
	move.b	SRC_EX(a0),d0	* exclusive or the signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bpl.b	fmul_inf_dst_p	* result INF is pos.
	bra.b	fmul_inf_dst_n

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fin(): emulates the fmove instruction
*	fsin(): emulates the fsmove instruction
*	fdin(): emulates the fdmove instruction
*		
* xdef **
*	norm() - normalize mantissa for EXOP on denorm
*	scale_to_zero_src() - scale src exponent to zero
*	ovf_res() - return default overflow result
* 	unf_res() - return default underflow result
*	res_qnan_1op() - return QNAN result
*	res_snan_1op() - return SNAN result
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0 = round prec/mode	
* 		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
* 	Handle NANs, infinities, and zeroes as special cases. Divide
* norms into extended, single, and double precision.
* 	Norms can be emulated w/ a regular fmove instruction. For
* sgl/dbl, must scale exponent and perform an "fmove". Check to see
* if the result would have overflowed/underflowed. If so, use unf_res()
* or ovf_res() to return the default result. Also return EXOP if
* exception is enabled. If no exception, return the default result.
*	Unnorms don't pass through here.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsin
fsin:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl precision
	bra.b	fin

	xdef	fdin
fdin:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl precision

	xdef	fin
fin:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	move.b	EXC_LV+STAG(a6),d1	* fetch src optype tag
	bne.w	fin_not_norm	* optimize on non-norm input
	
*
* FP MOVE IN: NORMs and DENORMs ONLY!
*
fin_norm:
	andi.b	#$c0,d0	* is precision extended?
	bne.w	fin_not_ext	* no, so go handle dbl or sgl

*
* precision selected is extended. so...we cannot get an underflow
* or overflow because of rounding to the correct precision. so...
* skip the scaling and unscaling...
*
	tst.b	SRC_EX(a0)	* is the operand negative?
	bpl.b	fin_norm_done	* no
	bset	#neg_bit,EXC_LV+FPSR_CC(a6)	* yes, so set 'N' ccode bit
fin_norm_done:
	fmovem.x	SRC(a0),fp0	* return result in fp0
	rts

*
* for an extended precision DENORM, the UNFL exception bit is set
* the accrued bit is NOT set in this instance(no inexactness!)
*
fin_denorm:
	andi.b	#$c0,d0	* is precision extended?
	bne.w	fin_not_ext	* no, so go handle dbl or sgl

	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit
	tst.b	SRC_EX(a0)	* is the operand negative?
	bpl.b	fin_denorm_done	* no
	bset	#neg_bit,EXC_LV+FPSR_CC(a6)	* yes, so set 'N' ccode bit
fin_denorm_done:
	fmovem.x	SRC(a0),fp0	* return result in fp0
	btst	#unfl_bit,EXC_LV+FPCR_ENABLE(a6) * is UNFL enabled?
	bne.b	fin_denorm_unfl_ena	* yes
	rts

*
* the input is an extended DENORM and underflow is enabled in the FPCR.
* normalize the mantissa and add the bias of $6000 to the resulting negative
* exponent and insert back into the operand.
*
fin_denorm_unfl_ena:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	bsr.l	norm	* normalize result
	neg.w	d0	* new exponent = -(shft val)
	addi.w	#$6000,d0	* add new bias to exponent
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch old sign,exp
	andi.w	#$8000,d1	* keep old sign
	andi.w	#$7fff,d0	* clear sign position
	or.w	d1,d0	* concat new exo,old sign
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

*
* operand is to be rounded to single or double precision
*	
fin_not_ext:
	ICMP.b	d0,#s_mode*$10 	* separate sgl/dbl prec
	bne.b	fin_dbl

*
* operand is to be rounded to single precision
*
fin_sgl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3f80	* will move in underflow?
	bge.w	fin_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$407e	* will move in overflow?
	beq.w	fin_sd_may_ovfl	* maybe; go check
	blt.w	fin_sd_ovfl	* yes; go handle overflow

*
* operand will NOT overflow or underflow when moved into the fp reg file
*
fin_sd_normal:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* perform move

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fin_sd_normal_exit:
	move.l	d2,-(sp)	* save d2
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load {sgn,exp}
	move.w	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	andi.w	#$8000,d2	* keep old sign
	or.w	d1,d2	* concat old sign,new exponent
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* operand is to be rounded to double precision
*
fin_dbl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3c00	* will move in underflow?
	bge.w	fin_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$43fe	* will move in overflow?
	beq.w	fin_sd_may_ovfl	* maybe; go check
	blt.w	fin_sd_ovfl	* yes; go handle overflow
	bra.w	fin_sd_normal	* no; ho handle normalized op

*
* operand WILL underflow when moved in to the fp register file
*
fin_sd_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	tst.b	EXC_LV+FP_SCR0_EX(a6)	* is operand negative?
	bpl.b	fin_sd_unfl_tst
	bset	#neg_bit,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit

* if underflow or inexact is enabled, then go calculate the EXOP first.
fin_sd_unfl_tst:
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fin_sd_unfl_ena	* yes

fin_sd_unfl_dis:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* unf_res may have set 'Z'
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts	

*
* operand will underflow AND underflow or inexact is enabled. 
* therefore, we must return the result rounded to extended precision.
*
fin_sd_unfl_ena:
	move.l	EXC_LV+FP_SCR0_HI(a6),EXC_LV+FP_SCR1_HI(a6)
	move.l	EXC_LV+FP_SCR0_LO(a6),EXC_LV+FP_SCR1_LO(a6)
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load current exponent

	move.l	d2,-(sp)	* save d2
	move.w	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* subtract scale factor
	andi.w	#$8000,d2	* extract old sign
	addi.l	#$6000,d1	* add new bias
	andi.w	#$7fff,d1
	or.w	d1,d2	* concat old sign,new exp
	move.w	d2,EXC_LV+FP_SCR1_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fin_sd_unfl_dis

*
* operand WILL overflow.
*
fin_sd_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* perform move

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save FPSR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fin_sd_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fin_sd_ovfl_ena	* yes

*
* OVFL is not enabled; therefore, we must create the default result by
* calling ovf_res().
*
fin_sd_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: prec,mode
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

*
* OVFL is enabled.
* the INEX2 bit has already been updated by the round to the correct precision.
* now, round to extended(and don't alter the FPSR).
*
fin_sd_ovfl_ena:
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	sub.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1
	or.w	d2,d1
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fin_sd_ovfl_dis

*
* the move in MAY overflow. so...
*
fin_sd_may_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* perform the move

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#2,fp1	* is |result| >= 2.b?
	fbge.w	fin_sd_ovfl_tst	* yes; overflow has occurred

* no, it didn't overflow; we have correct result
	bra.w	fin_sd_normal_exit

**-------------------------------------------------------------------------------------------------*

*
* operand is not a NORM: check its optype and branch accordingly
*
fin_not_norm:
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.w	fin_denorm
	ICMP.b	d1,#SNAN	* weed out SNANs
	beq.l	res_snan_1op
	ICMP.b	d1,#QNAN	* weed out QNANs
	beq.l	res_qnan_1op

*
* do the fmove in; at this point, only possible ops are ZERO and INF.
* use fmov to determine ccodes.
* prec:mode should be zero at this point but it won't affect answer anyways.
*
	fmove.x	SRC(a0),fp0	* do fmove in
	fmove.l	fpsr,d0	* no exceptions possible
	rol.l	#$8,d0	* put ccodes in lo byte
	move.b	d0,EXC_LV+FPSR_CC(a6)	* insert correct ccodes
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fdiv(): emulates the fdiv instruction
*	fsdiv(): emulates the fsdiv instruction
*	fddiv(): emulates the fddiv instruction
*		
* xdef **
*	scale_to_zero_src() - scale src exponent to zero
*	scale_to_zero_dst() - scale dst exponent to zero
*	unf_res() - return default underflow result
*	ovf_res() - return default overflow result
* 	res_qnan() - return QNAN result	
* 	res_snan() - return SNAN result	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	a1 = pointer to extended precision destination operand
*	d0  rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms/denorms into ext/sgl/dbl precision.
*	For norms/denorms, scale the exponents such that a divide
* instruction won't cause an exception. Use the regular fdiv to
* compute a result. Check if the regular operands would have taken
* an exception. If so, return the default overflow/underflow result
* and return the EXOP if exceptions are enabled. Else, scale the 
* result operand to the proper exponent.
*		
**-------------------------------------------------------------------------------------------------

	cnop	0,$10
tbl_fdiv_unfl:
	dc.l	$3fff - 0	* ext_unfl
	dc.l	$3fff - $3f81	* sgl_unfl
	dc.l	$3fff - $3c01	* dbl_unfl

tbl_fdiv_ovfl:
	dc.l	$3fff - $7ffe	* ext overflow exponent
	dc.l	$3fff - $407e	* sgl overflow exponent
	dc.l	$3fff - $43fe	* dbl overflow exponent

	xdef	fsdiv
fsdiv:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl prec
	bra.b	fdiv

	xdef	fddiv
fddiv:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl prec

	xdef	fdiv
fdiv:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1	* combine src tags

	bne.w	fdiv_not_norm	* optimize on non-norm input
	
*
* DIVIDE: NORMs and DENORMs ONLY!
*
fdiv_norm:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_to_zero_src	* scale src exponent
	move.l	d0,-(sp)	* save scale factor 1

	bsr.l	scale_to_zero_dst	* scale dst exponent

	neg.l	(sp)	* SCALE FACTOR = scale1 - scale2
	add.l	d0,(sp)

	move.w	2+EXC_LV+L_SCR3(a6),d1	* fetch precision
	lsr.b	#$6,d1	* shift to lo bits
	move.l	(sp)+,d0	* load S.F.
	ICMP.l	d0,((tbl_fdiv_ovfl).b,pc,d1.w*4) * will result overflow?
	ble.w	fdiv_may_ovfl	* result will overflow

	ICMP.l	d0,(tbl_fdiv_unfl.w,pc,d1.w*4) * will result underflow?
	beq.w	fdiv_may_unfl	* maybe
	bgt.w	fdiv_unfl	* yes; go handle underflow

fdiv_normal:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* save FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp0	* perform divide

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fdiv_normal_exit:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store result on stack
	move.l	d2,-(sp)	* store d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

tbl_fdiv_ovfl2:
	dc.l	$7fff
	dc.l	$407f
	dc.l	$43ff

fdiv_no_ovfl:
	move.l	(sp)+,d0	* restore scale factor
	bra.b	fdiv_normal_exit
	
fdiv_may_ovfl:
	move.l	d0,-(sp)	* save scale factor

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* set FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute divide

	fmove.l	fpsr,d0
	fmove.l	#$0,fpcr

	or.l	d0,EXC_LV+USER_FPSR(a6)	* save INEX,N

	fmovem.x	fp7,-(sp)	* save result to stack
	move.w	(sp),d0	* fetch new exponent
	add.l	#$c,sp	* clear result from stack
	andi.l	#$7fff,d0	* strip sign
	sub.l	(sp),d0	* add scale factor
	ICMP.l	d0,((tbl_fdiv_ovfl2).b,pc,d1.w*4)
	blt.b	fdiv_no_ovfl
	move.l	(sp)+,d0

fdiv_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fdiv_ovfl_ena	* yes

fdiv_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6) 	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass prec:rnd
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

fdiv_ovfl_ena:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fdiv_ovfl_ena_sd	* no, do sgl or dbl

fdiv_ovfl_ena_cont:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* move result to stack

	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.w	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1	* clear sign bit
	andi.w	#$8000,d2	* keep old sign
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fdiv_ovfl_dis

fdiv_ovfl_ena_sd:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst operand

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* keep rnd mode
	fmove.l	d1,fpcr	* set FPCR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute divide

	fmove.l	#$0,fpcr	* clear FPCR
	bra.b	fdiv_ovfl_ena_cont

fdiv_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute divide

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fdiv_unfl_ena	* yes

fdiv_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* 'Z' may have been set
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts

*
* UNFL is enabled. 
*
fdiv_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fdiv_unfl_ena_sd	* no, sgl or dbl

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

fdiv_unfl_ena_cont:
	fmove.l	#$0,fpsr	* clear FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp1	* execute divide

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* save result to stack
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factoer
	addi.l	#$6000,d1	* add bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exp
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.w	fdiv_unfl_dis

fdiv_unfl_ena_sd:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* use only rnd mode
	fmove.l	d1,fpcr	* set FPCR

	bra.b	fdiv_unfl_ena_cont

*
* the divide operation MAY underflow:
*
fdiv_may_unfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute divide

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#1,fp1	* is |result| > 1.b?
	fbgt.w	fdiv_normal_exit	* no; no underflow occurred
	fblt.w	fdiv_unfl	* yes; underflow occurred

*
* we still don't know if underflow occurred. result is ~ equal to 1. but,
* we don't know if the result was an underflow that rounded up to a 1
* or a normalized number that rounded down to a 1. so, redo the entire 
* operation using RZ as the rounding mode to see what the pre-rounded 
* result is. this case should be relatively rare.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op into fp1

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* keep rnd prec
	ori.b	#rz_mode*$10,d1	* insert RZ

	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fdiv.x	EXC_LV+FP_SCR0(a6),fp1	* execute divide

	fmove.l	#$0,fpcr	* clear FPCR
	fabs.x	fp1	* make absolute value
	fcmp.b	#1,fp1	* is |result| < 1.b?
	fbge.w	fdiv_normal_exit	* no; no underflow occurred
	bra.w	fdiv_unfl	* yes; underflow occurred

**-------------------------------------------------------------------------------------------------***

*
* Divide: inputs are not both normalized; what are they?
*
fdiv_not_norm:
	move.w	((tbl_fdiv_op).b,pc,d1.w*2),d1
	jmp	((tbl_fdiv_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fdiv_op:
	dc.w	fdiv_norm	- tbl_fdiv_op * NORM / NORM
	dc.w	fdiv_inf_load	- tbl_fdiv_op * NORM / ZERO
	dc.w	fdiv_zero_load	- tbl_fdiv_op * NORM / INF
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * NORM / QNAN
	dc.w	fdiv_norm	- tbl_fdiv_op * NORM / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * NORM / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

	dc.w	fdiv_zero_load	- tbl_fdiv_op * ZERO / NORM
	dc.w	fdiv_res_operr	- tbl_fdiv_op * ZERO / ZERO
	dc.w	fdiv_zero_load	- tbl_fdiv_op * ZERO / INF
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * ZERO / QNAN
	dc.w	fdiv_zero_load	- tbl_fdiv_op * ZERO / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * ZERO / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

	dc.w	fdiv_inf_dst	- tbl_fdiv_op * INF / NORM
	dc.w	fdiv_inf_dst	- tbl_fdiv_op * INF / ZERO
	dc.w	fdiv_res_operr	- tbl_fdiv_op * INF / INF
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * INF / QNAN
	dc.w	fdiv_inf_dst	- tbl_fdiv_op * INF / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * INF / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

	dc.w	fdiv_res_qnan	- tbl_fdiv_op * QNAN / NORM
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * QNAN / ZERO
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * QNAN / INF
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * QNAN / QNAN
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * QNAN / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * QNAN / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

	dc.w	fdiv_norm	- tbl_fdiv_op * DENORM / NORM
	dc.w	fdiv_inf_load	- tbl_fdiv_op * DENORM / ZERO
	dc.w	fdiv_zero_load	- tbl_fdiv_op * DENORM / INF
	dc.w	fdiv_res_qnan	- tbl_fdiv_op * DENORM / QNAN
	dc.w	fdiv_norm	- tbl_fdiv_op * DENORM / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * DENORM / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / NORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / ZERO
	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / INF
	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / QNAN
	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / DENORM
	dc.w	fdiv_res_snan	- tbl_fdiv_op * SNAN / SNAN
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *
	dc.w	tbl_fdiv_op	- tbl_fdiv_op *

fdiv_res_qnan:
	bra.l	res_qnan
fdiv_res_snan:
	bra.l	res_snan
fdiv_res_operr:
	bra.l	res_operr

	xdef	fdiv_zero_load	* xdef for fsgldiv
fdiv_zero_load:
	move.b	SRC_EX(a0),d0	* result sign is exclusive
	move.b	DST_EX(a1),d1	* or of input signs.
	eor.b	d0,d1
	bpl.b	fdiv_zero_load_p	* result is positive
	fmove.s	#$80000000,fp0	* load a -ZERO
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6)	* set Z/N
	rts
fdiv_zero_load_p:
	fmove.s	#$00000000,fp0	* load a +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts

*
* The destination was In Range and the source was a ZERO. The result,
* therefore, is an INF w/ the proper sign.
* So, determine the sign and return a new INF (w/ the j-bit cleared).
*
	xdef	fdiv_inf_load	* xdef for fsgldiv
fdiv_inf_load:
	ori.w	#dz_mask+adz_mask,2+EXC_LV+USER_FPSR(a6) * no; set DZ/ADZ
	move.b	SRC_EX(a0),d0	* load both signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bpl.b	fdiv_inf_load_p	* result is positive
	fmove.s	#$ff800000,fp0	* make result -INF
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set INF/N
	rts
fdiv_inf_load_p:
	fmove.s	#$7f800000,fp0	* make result +INF
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set INF
	rts

*
* The destination was an INF w/ an In Range or ZERO source, the result is 
* an INF w/ the proper sign. 
* The 68881/882 returns the destination INF w/ the new sign(if the j-bit of the
* dst INF is set, then then j-bit of the result INF is also set).
*
	xdef	fdiv_inf_dst	* xdef for fsgldiv
fdiv_inf_dst:
	move.b	DST_EX(a1),d0	* load both signs
	move.b	SRC_EX(a0),d1
	eor.b	d0,d1
	bpl.b	fdiv_inf_dst_p	* result is positive

	fmovem.x	DST(a1),fp0	* return result in fp0
	fabs.x	fp0	* clear sign bit
	fneg.x	fp0	* set sign bit
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set INF/NEG
	rts

fdiv_inf_dst_p:
	fmovem.x	DST(a1),fp0	* return result in fp0
	fabs.x	fp0	* return positive INF
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6) * set INF
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fneg(): emulates the fneg instruction
*	fsneg(): emulates the fsneg instruction
*	fdneg(): emulates the fdneg instruction
*		
* xdef **
* 	norm() - normalize a denorm to provide EXOP
*	scale_to_zero_src() - scale sgl/dbl source exponent
*	ovf_res() - return default overflow result
*	unf_res() - return default underflow result
* 	res_qnan_1op() - return QNAN result
*	res_snan_1op() - return SNAN result
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0 = rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, zeroes, and infinities as special cases. Separate
* norms/denorms into ext/sgl/dbl precisions. Extended precision can be
* emulated by simply setting sign bit. Sgl/dbl operands must be scaled
* and an actual fneg performed to see if overflow/underflow would have
* occurred. If so, return default underflow/overflow result. Else,
* scale the result exponent and return result. FPSR gets set based on
* the result value.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsneg
fsneg:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl precision
	bra.b	fneg

	xdef	fdneg
fdneg:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl prec

	xdef	fneg
fneg:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info
	move.b	EXC_LV+STAG(a6),d1
	bne.w	fneg_not_norm	* optimize on non-norm input
	
*
* NEGATE SIGN : norms and denorms ONLY!
*
fneg_norm:
	andi.b	#$c0,d0	* is precision extended?
	bne.w	fneg_not_ext	* no; go handle sgl or dbl

*
* precision selected is extended. so...we can not get an underflow
* or overflow because of rounding to the correct precision. so...
* skip the scaling and unscaling...
*
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.w	SRC_EX(a0),d0
	eori.w	#$8000,d0	* negate sign
	bpl.b	fneg_norm_load	* sign is positive
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
fneg_norm_load:
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* for an extended precision DENORM, the UNFL exception bit is set
* the accrued bit is NOT set in this instance(no inexactness!)
*
fneg_denorm:
	andi.b	#$c0,d0	* is precision extended?
	bne.b	fneg_not_ext	* no; go handle sgl or dbl

	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.w	SRC_EX(a0),d0
	eori.w	#$8000,d0	* negate sign
	bpl.b	fneg_denorm_done	* no
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* yes, set 'N' ccode bit
fneg_denorm_done:
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0

	btst	#unfl_bit,EXC_LV+FPCR_ENABLE(a6) * is UNFL enabled?
	bne.b	fneg_ext_unfl_ena	* yes
	rts

*
* the input is an extended DENORM and underflow is enabled in the FPCR.
* normalize the mantissa and add the bias of $6000 to the resulting negative
* exponent and insert back into the operand.
*
fneg_ext_unfl_ena:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	bsr.l	norm	* normalize result
	neg.w	d0	* new exponent = -(shft val)
	addi.w	#$6000,d0	* add new bias to exponent
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch old sign,exp
	andi.w	#$8000,d1	 	* keep old sign
	andi.w	#$7fff,d0	* clear sign position
	or.w	d1,d0	* concat old sign, new exponent
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

*
* operand is either single or double
*
fneg_not_ext:
	ICMP.b	d0,#s_mode*$10	* separate sgl/dbl prec
	bne.b	fneg_dbl

*
* operand is to be rounded to single precision
*
fneg_sgl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3f80	* will move in underflow?
	bge.w	fneg_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$407e	* will move in overflow?
	beq.w	fneg_sd_may_ovfl	* maybe; go check
	blt.w	fneg_sd_ovfl	* yes; go handle overflow

*
* operand will NOT overflow or underflow when moved in to the fp reg file
*
fneg_sd_normal:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fneg.x	EXC_LV+FP_SCR0(a6),fp0	* perform negation

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fneg_sd_normal_exit:
	move.l	d2,-(sp)	* save d2
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load sgn,exp
	move.w	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	andi.w	#$8000,d2	* keep old sign
	or.w	d1,d2	* concat old sign,new exp
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* operand is to be rounded to double precision
*
fneg_dbl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3c00	* will move in underflow?
	bge.b	fneg_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$43fe	* will move in overflow?
	beq.w	fneg_sd_may_ovfl	* maybe; go check
	blt.w	fneg_sd_ovfl	* yes; go handle overflow
	bra.w	fneg_sd_normal	* no; ho handle normalized op

*
* operand WILL underflow when moved in to the fp register file
*
fneg_sd_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	eori.b	#$80,EXC_LV+FP_SCR0_EX(a6)	* negate sign
	bpl.b	fneg_sd_unfl_tst
	bset	#neg_bit,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit

* if underflow or inexact is enabled, go calculate EXOP first.
fneg_sd_unfl_tst:
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fneg_sd_unfl_ena	* yes

fneg_sd_unfl_dis:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* unf_res may have set 'Z'
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts	

*
* operand will underflow AND underflow is enabled. 
* therefore, we must return the result rounded to extended precision.
*
fneg_sd_unfl_ena:
	move.l	EXC_LV+FP_SCR0_HI(a6),EXC_LV+FP_SCR1_HI(a6)
	move.l	EXC_LV+FP_SCR0_LO(a6),EXC_LV+FP_SCR1_LO(a6)
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load current exponent

	move.l	d2,-(sp)	* save d2
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* subtract scale factor
	addi.l	#$6000,d1	* add new bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat new sign,new exp
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)	* insert new exp
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fneg_sd_unfl_dis

*
* operand WILL overflow.
*
fneg_sd_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fneg.x	EXC_LV+FP_SCR0(a6),fp0	* perform negation

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save FPSR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fneg_sd_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fneg_sd_ovfl_ena	* yes

*
* OVFL is not enabled; therefore, we must create the default result by
* calling ovf_res().
*
fneg_sd_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: prec,mode
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

*
* OVFL is enabled.
* the INEX2 bit has already been updated by the round to the correct precision.
* now, round to extended(and don't alter the FPSR).
*
fneg_sd_ovfl_ena:
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat sign,exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fneg_sd_ovfl_dis

*
* the move in MAY underflow. so...
*
fneg_sd_may_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fneg.x	EXC_LV+FP_SCR0(a6),fp0	* perform negation

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#2,fp1	* is |result| >= 2.b?
	fbge.w	fneg_sd_ovfl_tst	* yes; overflow has occurred

* no, it didn't overflow; we have correct result
	bra.w	fneg_sd_normal_exit

**-------------------------------------------------------------------------------------------------*

*
* input is not normalized; what is it?
*
fneg_not_norm:
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.w	fneg_denorm
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	ICMP.b	d1,#QNAN	* weed out QNAN
	beq.l	res_qnan_1op

*
* do the fneg; at this point, only possible ops are ZERO and INF.
* use fneg to determine ccodes.
* prec:mode should be zero at this point but it won't affect answer anyways.
*
	fneg.x	SRC_EX(a0),fp0	* do fneg
	fmove.l	fpsr,d0
	rol.l	#$8,d0	* put ccodes in lo byte
	move.b	d0,EXC_LV+FPSR_CC(a6)	* insert correct ccodes
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	ftst(): emulates the ftst instruction
*		
* xdef **
* 	res{s,q}nan_1op() - set NAN result for monadic instruction
*		
* INPUT ***************************************************************
* 	a0 = pointer to extended precision source operand
*		
* OUTPUT **************************************************************
*	none	
*		
* ALGORITHM ***********************************************************
* 	Check the source operand tag (EXC_LV+STAG) and set the FPCR according
* to the operand type and sign.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	ftst
ftst:
	move.b	EXC_LV+STAG(a6),d1
	bne.b	ftst_not_norm	* optimize on non-norm input
	
*
* Norm:
*
ftst_norm:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.b	ftst_norm_m	* yes
	rts
ftst_norm_m:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

*
* input is not normalized; what is it?
*
ftst_not_norm:
	ICMP.b	d1,#ZERO	* weed out ZERO
	beq.b	ftst_zero
	ICMP.b	d1,#INF	* weed out INF
	beq.b	ftst_inf
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	ICMP.b	d1,#QNAN	* weed out QNAN
	beq.l	res_qnan_1op

*
* Denorm:
*
ftst_denorm:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.b	ftst_denorm_m	* yes
	rts
ftst_denorm_m:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts

*
* Infinity:
*
ftst_inf:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.b	ftst_inf_m	* yes
ftst_inf_p:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'I' ccode bit
	rts
ftst_inf_m:
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set 'I','N' ccode bits
	rts
	
*
* Zero:
*
ftst_zero:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.b	ftst_zero_m	* yes
ftst_zero_p:
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'N' ccode bit
	rts
ftst_zero_m:
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z','N' ccode bits
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fint(): emulates the fint instruction
*		
* xdef **
*	res_{s,q}nan_1op() - set NAN result for monadic operation
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0 = round precision/mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*		
* ALGORITHM ***********************************************************
* 	Separate according to operand type. Unnorms don't pass through 
* here. For norms, load the rounding mode/prec, execute a "fint", then 
* store the resulting FPSR bits.	
* 	For denorms, force the j-bit to a one and do the same as for
* norms. Denorms are so low that the answer will either be a zero or a 
* one.		
* 	For zeroes/infs/NANs, return the same while setting the FPSR
* as appropriate.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fint
fint:
	move.b	EXC_LV+STAG(a6),d1
	bne.b	fint_not_norm	* optimize on non-norm input
	
*
* Norm:
*
fint_norm:
	andi.b	#$30,d0	* set prec = ext

	fmove.l	d0,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fint.x 	SRC(a0),fp0	* execute fint

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d0	* save FPSR
	or.l	d0,EXC_LV+USER_FPSR(a6)	* set exception bits

	rts

*
* input is not normalized; what is it?
*
fint_not_norm:
	ICMP.b	d1,#ZERO	* weed out ZERO
	beq.b	fint_zero
	ICMP.b	d1,#INF	* weed out INF
	beq.b	fint_inf
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.b	fint_denorm
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	bra.l	res_qnan_1op	* weed out QNAN

*
* Denorm:
*
* for DENORMs, the result will be either (+/-)ZERO or (+/-)1.
* also, the INEX2 and AINEX exception bits will be set.
* so, we could either set these manually or force the DENORM
* to a very small NORM and ship it to the NORM routine.
* I do the latter.
*
fint_denorm:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6) * copy sign, zero exp
	move.b	#$80,EXC_LV+FP_SCR0_HI(a6)	* force DENORM ==> small NORM
	lea	EXC_LV+FP_SCR0(a6),a0
	bra.b	fint_norm

*
* Zero:
*
fint_zero:
	tst.b	SRC_EX(a0)	* is ZERO negative?
	bmi.b	fint_zero_m	* yes
fint_zero_p:
	fmove.s	#$00000000,fp0	* return +ZERO in fp0
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts
fint_zero_m:
	fmove.s	#$80000000,fp0	* return -ZERO in fp0
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set 'Z','N' ccode bits
	rts

*
* Infinity:
*
fint_inf:
	fmovem.x	SRC(a0),fp0	* return result in fp0
	tst.b	SRC_EX(a0)	* is INF negative?
	bmi.b	fint_inf_m	* yes
fint_inf_p:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'I' ccode bit
	rts
fint_inf_m:
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set 'N','I' ccode bits
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fintrz(): emulates the fintrz instruction
*		
* xdef **
*	res_{s,q}nan_1op() - set NAN result for monadic operation
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0 = round precision/mode	
*		
* OUTPUT **************************************************************
* 	fp0 = result	
*		
* ALGORITHM ***********************************************************
*	Separate according to operand type. Unnorms don't pass through
* here. For norms, load the rounding mode/prec, execute a "fintrz", 
* then store the resulting FPSR bits.	
* 	For denorms, force the j-bit to a one and do the same as for
* norms. Denorms are so low that the answer will either be a zero or a
* one.		
* 	For zeroes/infs/NANs, return the same while setting the FPSR
* as appropriate.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fintrz
fintrz:
	move.b	EXC_LV+STAG(a6),d1
	bne.b	fintrz_not_norm	* optimize on non-norm input
	
*
* Norm:
*
fintrz_norm:
	fmove.l	#$0,fpsr	* clear FPSR

	fintrz.x	SRC(a0),fp0	* execute fintrz

	fmove.l	fpsr,d0	* save FPSR
	or.l	d0,EXC_LV+USER_FPSR(a6)	* set exception bits

	rts

*
* input is not normalized; what is it?
*
fintrz_not_norm:
	ICMP.b	d1,#ZERO	* weed out ZERO
	beq.b	fintrz_zero
	ICMP.b	d1,#INF	* weed out INF
	beq.b	fintrz_inf
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.b	fintrz_denorm
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	bra.l	res_qnan_1op	* weed out QNAN

*
* Denorm:
*
* for DENORMs, the result will be (+/-)ZERO.
* also, the INEX2 and AINEX exception bits will be set.
* so, we could either set these manually or force the DENORM
* to a very small NORM and ship it to the NORM routine.
* I do the latter.
*
fintrz_denorm:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6) * copy sign, zero exp
	move.b	#$80,EXC_LV+FP_SCR0_HI(a6)	* force DENORM ==> small NORM
	lea	EXC_LV+FP_SCR0(a6),a0
	bra.b	fintrz_norm

*
* Zero:
*
fintrz_zero:
	tst.b	SRC_EX(a0)	* is ZERO negative?
	bmi.b	fintrz_zero_m	* yes
fintrz_zero_p:
	fmove.s	#$00000000,fp0	* return +ZERO in fp0
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts
fintrz_zero_m:
	fmove.s	#$80000000,fp0	* return -ZERO in fp0
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set 'Z','N' ccode bits
	rts

*
* Infinity:
*
fintrz_inf:
	fmovem.x	SRC(a0),fp0	* return result in fp0
	tst.b	SRC_EX(a0)	* is INF negative?
	bmi.b	fintrz_inf_m	* yes
fintrz_inf_p:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'I' ccode bit
	rts
fintrz_inf_m:
	move.b	#inf_bmask+neg_bmask,EXC_LV+FPSR_CC(a6) * set 'N','I' ccode bits
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fabs():  emulates the fabs instruction
*	fsabs(): emulates the fsabs instruction
*	fdabs(): emulates the fdabs instruction
*		
* xdef ** *
*	norm() - normalize denorm mantissa to provide EXOP
*	scale_to_zero_src() - make exponent. = 0; get scale factor
*	unf_res() - calculate underflow result
*	ovf_res() - calculate overflow result
*	res_{s,q}nan_1op() - set NAN result for monadic operation
*		
* INPUT *************************************************************** *
*	a0 = pointer to extended precision source operand
*	d0 = rnd precision/mode	
*		
* OUTPUT ************************************************************** *
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms into extended, single, and double precision. 
* 	Simply clear sign for extended precision norm. Ext prec denorm
* gets an EXOP created for it since it's an underflow.
*	Double and single precision can overflow and underflow. First,
* scale the operand such that the exponent is zero. Perform an "fabs"
* using the correct rnd mode/prec. Check to see if the original 
* exponent would take an exception. If so, use unf_res() or ovf_res()
* to calculate the default result. Also, create the EXOP for the
* exceptional case. If no exception should occur, insert the correct 
* result exponent and return.	
* 	Unnorms don't pass through here.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsabs
fsabs:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl precision
	bra.b	fabs

	xdef	fdabs
fdabs:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl precision

	xdef	fabs
fabs:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info
	move.b	EXC_LV+STAG(a6),d1
	bne.w	fabs_not_norm	* optimize on non-norm input
	
*
* ABSOLUTE VALUE: norms and denorms ONLY!
*
fabs_norm:
	andi.b	#$c0,d0	* is precision extended?
	bne.b	fabs_not_ext	* no; go handle sgl or dbl

*
* precision selected is extended. so...we can not get an underflow
* or overflow because of rounding to the correct precision. so...
* skip the scaling and unscaling...
*
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.w	SRC_EX(a0),d1
	bclr	#15,d1	* force absolute value
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* for an extended precision DENORM, the UNFL exception bit is set
* the accrued bit is NOT set in this instance(no inexactness!)
*
fabs_denorm:
	andi.b	#$c0,d0	* is precision extended?
	bne.b	fabs_not_ext	* no

	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.w	SRC_EX(a0),d0
	bclr	#15,d0	* clear sign
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert exponent

	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0

	btst	#unfl_bit,EXC_LV+FPCR_ENABLE(a6) * is UNFL enabled?
	bne.b	fabs_ext_unfl_ena
	rts

*
* the input is an extended DENORM and underflow is enabled in the FPCR.
* normalize the mantissa and add the bias of $6000 to the resulting negative
* exponent and insert back into the operand.
*
fabs_ext_unfl_ena:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	bsr.l	norm	* normalize result
	neg.w	d0	* new exponent = -(shft val)
	addi.w	#$6000,d0	* add new bias to exponent
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch old sign,exp
	andi.w	#$8000,d1	* keep old sign
	andi.w	#$7fff,d0	* clear sign position
	or.w	d1,d0	* concat old sign, new exponent
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

*
* operand is either single or double
*
fabs_not_ext:
	ICMP.b	d0,#s_mode*$10	* separate sgl/dbl prec
	bne.b	fabs_dbl

*
* operand is to be rounded to single precision
*
fabs_sgl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3f80	* will move in underflow?
	bge.w	fabs_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$407e	* will move in overflow?
	beq.w	fabs_sd_may_ovfl	* maybe; go check
	blt.w	fabs_sd_ovfl	* yes; go handle overflow

*
* operand will NOT overflow or underflow when moved in to the fp reg file
*
fabs_sd_normal:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fabs.x	EXC_LV+FP_SCR0(a6),fp0	* perform absolute

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fabs_sd_normal_exit:
	move.l	d2,-(sp)	* save d2
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load sgn,exp
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	andi.w	#$8000,d2	* keep old sign
	or.w	d1,d2	* concat old sign,new exp
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* operand is to be rounded to double precision
*
fabs_dbl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* calculate scale factor

	ICMP.l	d0,#$3fff-$3c00	* will move in underflow?
	bge.b	fabs_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$43fe	* will move in overflow?
	beq.w	fabs_sd_may_ovfl	* maybe; go check
	blt.w	fabs_sd_ovfl	* yes; go handle overflow
	bra.w	fabs_sd_normal	* no; ho handle normalized op

*
* operand WILL underflow when moved in to the fp register file
*
fabs_sd_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	bclr	#$7,EXC_LV+FP_SCR0_EX(a6)	* force absolute value

* if underflow or inexact is enabled, go calculate EXOP first.
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fabs_sd_unfl_ena	* yes

fabs_sd_unfl_dis:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set possible 'Z' ccode
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts	

*
* operand will underflow AND underflow is enabled. 
* therefore, we must return the result rounded to extended precision.
*
fabs_sd_unfl_ena:
	move.l	EXC_LV+FP_SCR0_HI(a6),EXC_LV+FP_SCR1_HI(a6)
	move.l	EXC_LV+FP_SCR0_LO(a6),EXC_LV+FP_SCR1_LO(a6)
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load current exponent

	move.l	d2,-(sp)	* save d2
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* subtract scale factor
	addi.l	#$6000,d1	* add new bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat new sign,new exp
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)	* insert new exp
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fabs_sd_unfl_dis

*
* operand WILL overflow.
*
fabs_sd_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fabs.x	EXC_LV+FP_SCR0(a6),fp0	* perform absolute

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save FPSR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fabs_sd_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fabs_sd_ovfl_ena	* yes

*
* OVFL is not enabled; therefore, we must create the default result by
* calling ovf_res().
*
fabs_sd_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: prec,mode
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

*
* OVFL is enabled.
* the INEX2 bit has already been updated by the round to the correct precision.
* now, round to extended(and don't alter the FPSR).
*
fabs_sd_ovfl_ena:
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat sign,exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fabs_sd_ovfl_dis

*
* the move in MAY underflow. so...
*
fabs_sd_may_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fabs.x	EXC_LV+FP_SCR0(a6),fp0	* perform absolute

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#2,fp1	* is |result| >= 2.b?
	fbge.w	fabs_sd_ovfl_tst	* yes; overflow has occurred

* no, it didn't overflow; we have correct result
	bra.w	fabs_sd_normal_exit

**-------------------------------------------------------------------------------------------------*

*
* input is not normalized; what is it?
*
fabs_not_norm:
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.w	fabs_denorm
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	ICMP.b	d1,#QNAN	* weed out QNAN
	beq.l	res_qnan_1op

	fabs.x	SRC(a0),fp0	* force absolute value

	ICMP.b	d1,#INF	* weed out INF
	beq.b	fabs_inf
fabs_zero:
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts
fabs_inf:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'I' ccode bit
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fcmp(): fp compare op routine	
*		
* xdef **
* 	res_qnan() - return QNAN result	
*	res_snan() - return SNAN result	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	a1 = pointer to extended precision destination operand
*	d0 = round prec/mode	
*		
* OUTPUT ************************************************************** *
*	None	
*		
* ALGORITHM ***********************************************************
* 	Handle NANs and denorms as special cases. For everything else,
* just use the actual fcmp instruction to produce the correct condition
* codes.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fcmp
fcmp:
	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1
	bne.b	fcmp_not_norm	* optimize on non-norm input
	
*
* COMPARE FP OPs : NORMs, ZEROs, INFs, and "corrected" DENORMs
*
fcmp_norm:
	fmovem.x	DST(a1),fp0	* load dst op

	fcmp.x 	SRC(a0),fp0	* do compare

	fmove.l	fpsr,d0	* save FPSR
	rol.l	#$8,d0	* extract ccode bits
	move.b	d0,EXC_LV+FPSR_CC(a6)	* set ccode bits(no exc bits are set)

	rts

*
* fcmp: inputs are not both normalized; what are they?
*
fcmp_not_norm:
	move.w	((tbl_fcmp_op).b,pc,d1.w*2),d1
	jmp	((tbl_fcmp_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fcmp_op:
	dc.w	fcmp_norm	- tbl_fcmp_op * NORM - NORM
	dc.w	fcmp_norm	- tbl_fcmp_op * NORM - ZERO
	dc.w	fcmp_norm	- tbl_fcmp_op * NORM - INF
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * NORM - QNAN
	dc.w	fcmp_nrm_dnrm 	- tbl_fcmp_op * NORM - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * NORM - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

	dc.w	fcmp_norm	- tbl_fcmp_op * ZERO - NORM
	dc.w	fcmp_norm	- tbl_fcmp_op * ZERO - ZERO
	dc.w	fcmp_norm	- tbl_fcmp_op * ZERO - INF
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * ZERO - QNAN
	dc.w	fcmp_dnrm_s	- tbl_fcmp_op * ZERO - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * ZERO - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

	dc.w	fcmp_norm	- tbl_fcmp_op * INF - NORM
	dc.w	fcmp_norm	- tbl_fcmp_op * INF - ZERO
	dc.w	fcmp_norm	- tbl_fcmp_op * INF - INF
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * INF - QNAN
	dc.w	fcmp_dnrm_s	- tbl_fcmp_op * INF - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * INF - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

	dc.w	fcmp_res_qnan	- tbl_fcmp_op * QNAN - NORM
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * QNAN - ZERO
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * QNAN - INF
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * QNAN - QNAN
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * QNAN - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * QNAN - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

	dc.w	fcmp_dnrm_nrm	- tbl_fcmp_op * DENORM - NORM
	dc.w	fcmp_dnrm_d	- tbl_fcmp_op * DENORM - ZERO
	dc.w	fcmp_dnrm_d	- tbl_fcmp_op * DENORM - INF
	dc.w	fcmp_res_qnan	- tbl_fcmp_op * DENORM - QNAN
	dc.w	fcmp_dnrm_sd	- tbl_fcmp_op * DENORM - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * DENORM - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - NORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - ZERO
	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - INF
	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - QNAN
	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - DENORM
	dc.w	fcmp_res_snan	- tbl_fcmp_op * SNAN - SNAN
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *
	dc.w	tbl_fcmp_op	- tbl_fcmp_op *

* unlike all other functions for QNAN and SNAN, fcmp does NOT set the
* 'N' bit for a negative QNAN or SNAN input so we must squelch it here.
fcmp_res_qnan:
	bsr.l	res_qnan
	andi.b	#$f7,EXC_LV+FPSR_CC(a6)
	rts
fcmp_res_snan:
	bsr.l	res_snan
	andi.b	#$f7,EXC_LV+FPSR_CC(a6)
	rts

*
* DENORMs are a little more difficult. 
* If you have a 2 DENORMs, then you can just force the j-bit to a one 
* and use the fcmp_norm routine.
* If you have a DENORM and an INF or ZERO, just force the DENORM's j-bit to a one
* and use the fcmp_norm routine.
* If you have a DENORM and a NORM with opposite signs, then use fcmp_norm, also.
* But with a DENORM and a NORM of the same sign, the neg bit is set if the
* (1) signs are (+) and the DENORM is the dst or
* (2) signs are (-) and the DENORM is the src
*

fcmp_dnrm_s:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),d0
	bset	#31,d0	* DENORM src; make into small norm
	move.l	d0,EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	lea	EXC_LV+FP_SCR0(a6),a0
	bra.w	fcmp_norm

fcmp_dnrm_d:
	move.l	DST_EX(a1),EXC_LV+FP_SCR0_EX(a6)
	move.l	DST_HI(a1),d0
	bset	#31,d0	* DENORM src; make into small norm
	move.l	d0,EXC_LV+FP_SCR0_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR0_LO(a6)
	lea	EXC_LV+FP_SCR0(a6),a1
	bra.w	fcmp_norm

fcmp_dnrm_sd:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	DST_HI(a1),d0
	bset	#31,d0	* DENORM dst; make into small norm
	move.l	d0,EXC_LV+FP_SCR1_HI(a6)
	move.l	SRC_HI(a0),d0
	bset	#31,d0	* DENORM dst; make into small norm
	move.l	d0,EXC_LV+FP_SCR0_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	lea	EXC_LV+FP_SCR1(a6),a1
	lea	EXC_LV+FP_SCR0(a6),a0
	bra.w	fcmp_norm	

fcmp_nrm_dnrm:
	move.b	SRC_EX(a0),d0	* determine if like signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bmi.w	fcmp_dnrm_s

* signs are the same, so must determine the answer ourselves.
	tst.b	d0	* is src op negative?
	bmi.b	fcmp_nrm_dnrm_m	* yes
	rts
fcmp_nrm_dnrm_m:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts

fcmp_dnrm_nrm:
	move.b	SRC_EX(a0),d0	* determine if like signs
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bmi.w	fcmp_dnrm_d

* signs are the same, so must determine the answer ourselves.
	tst.b	d0	* is src op negative?
	bpl.b	fcmp_dnrm_nrm_m	* no
	rts
fcmp_dnrm_nrm_m:
	move.b	#neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fsglmul(): emulates the fsglmul instruction
*		
* xdef **
*	scale_to_zero_src() - scale src exponent to zero
*	scale_to_zero_dst() - scale dst exponent to zero
*	unf_res4() - return default underflow result for sglop
*	ovf_res() - return default overflow result
* 	res_qnan() - return QNAN result	
* 	res_snan() - return SNAN result	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	a1 = pointer to extended precision destination operand
*	d0  rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms/denorms into ext/sgl/dbl precision.
*	For norms/denorms, scale the exponents such that a multiply
* instruction won't cause an exception. Use the regular fsglmul to
* compute a result. Check if the regular operands would have taken
* an exception. If so, return the default overflow/underflow result
* and return the EXOP if exceptions are enabled. Else, scale the 
* result operand to the proper exponent.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsglmul
fsglmul:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1

	bne.w	fsglmul_not_norm	* optimize on non-norm input

fsglmul_norm:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_to_zero_src	* scale exponent
	move.l	d0,-(sp)	* save scale factor 1

	bsr.l	scale_to_zero_dst	* scale dst exponent

	add.l	(sp)+,d0	* SCALE_FACTOR = scale1 + scale2

	ICMP.l	d0,#$3fff-$7ffe 	* would result ovfl?
	beq.w	fsglmul_may_ovfl	* result may rnd to overflow
	blt.w	fsglmul_ovfl	* result will overflow

	ICMP.l	d0,#$3fff+$0001 	* would result unfl?
	beq.w	fsglmul_may_unfl	* result may rnd to no unfl
	bgt.w	fsglmul_unfl	* result will underflow

fsglmul_normal:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl multiply

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fsglmul_normal_exit:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

fsglmul_ovfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl multiply

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fsglmul_ovfl_tst:

* save setting this until now because this is where fsglmul_may_ovfl may jump in
	or.l	#ovfl_inx_mask, EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fsglmul_ovfl_ena	* yes

fsglmul_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass prec:rnd
	andi.b	#$30,d0	* force prec = ext
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

fsglmul_ovfl_ena:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* move result to stack

	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1
	andi.w	#$8000,d2	* keep old sign
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fsglmul_ovfl_dis

fsglmul_may_ovfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl multiply
	
	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#2,fp1	* is |result| >= 2.b?
	fbge.w	fsglmul_ovfl_tst	* yes; overflow has occurred
	
* no, it didn't overflow; we have correct result
	bra.w	fsglmul_normal_exit

fsglmul_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl multiply

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fsglmul_unfl_ena	* yes

fsglmul_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res4	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* 'Z' bit may have been set
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts

*
* UNFL is enabled. 
*
fsglmul_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp1	* execute sgl multiply	

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* save result to stack
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	addi.l	#$6000,d1	* add bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.w	fsglmul_unfl_dis

fsglmul_may_unfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl multiply	

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#2,fp1	* is |result| > 2.b?
	fbgt.w	fsglmul_normal_exit	* no; no underflow occurred
	fblt.w	fsglmul_unfl	* yes; underflow occurred

*
* we still don't know if underflow occurred. result is ~ equal to 2. but,
* we don't know if the result was an underflow that rounded up to a 2 or
* a normalized number that rounded down to a 2. so, redo the entire operation
* using RZ as the rounding mode to see what the pre-rounded result is.
* this case should be relatively rare.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op into fp1

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* keep rnd prec
	ori.b	#rz_mode*$10,d1	* insert RZ
	
	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsglmul.x	EXC_LV+FP_SCR0(a6),fp1	* execute sgl multiply	

	fmove.l	#$0,fpcr	* clear FPCR
	fabs.x	fp1	* make absolute value
	fcmp.b	#2,fp1	* is |result| < 2.b?
	fbge.w	fsglmul_normal_exit	* no; no underflow occurred
	bra.w	fsglmul_unfl	* yes, underflow occurred

**-------------------------------------------------------------------------------------------------*****

*
* Single Precision Multiply: inputs are not both normalized; what are they?
*
fsglmul_not_norm:
	move.w	((tbl_fsglmul_op).b,pc,d1.w*2),d1
	jmp	((tbl_fsglmul_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fsglmul_op:
	dc.w	fsglmul_norm	- tbl_fsglmul_op * NORM x NORM
	dc.w	fsglmul_zero	- tbl_fsglmul_op * NORM x ZERO
	dc.w	fsglmul_inf_src	- tbl_fsglmul_op * NORM x INF
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * NORM x QNAN
	dc.w	fsglmul_norm	- tbl_fsglmul_op * NORM x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * NORM x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

	dc.w	fsglmul_zero	- tbl_fsglmul_op * ZERO x NORM
	dc.w	fsglmul_zero	- tbl_fsglmul_op * ZERO x ZERO
	dc.w	fsglmul_res_operr	- tbl_fsglmul_op * ZERO x INF
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * ZERO x QNAN
	dc.w	fsglmul_zero	- tbl_fsglmul_op * ZERO x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * ZERO x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

	dc.w	fsglmul_inf_dst	- tbl_fsglmul_op * INF x NORM
	dc.w	fsglmul_res_operr	- tbl_fsglmul_op * INF x ZERO
	dc.w	fsglmul_inf_dst	- tbl_fsglmul_op * INF x INF
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * INF x QNAN
	dc.w	fsglmul_inf_dst	- tbl_fsglmul_op * INF x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * INF x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * QNAN x NORM
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * QNAN x ZERO
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * QNAN x INF
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * QNAN x QNAN
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * QNAN x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * QNAN x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

	dc.w	fsglmul_norm	- tbl_fsglmul_op * NORM x NORM
	dc.w	fsglmul_zero	- tbl_fsglmul_op * NORM x ZERO
	dc.w	fsglmul_inf_src	- tbl_fsglmul_op * NORM x INF
	dc.w	fsglmul_res_qnan	- tbl_fsglmul_op * NORM x QNAN
	dc.w	fsglmul_norm	- tbl_fsglmul_op * NORM x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * NORM x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x NORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x ZERO
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x INF
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x QNAN
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x DENORM
	dc.w	fsglmul_res_snan	- tbl_fsglmul_op * SNAN x SNAN
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *
	dc.w	tbl_fsglmul_op	- tbl_fsglmul_op *

fsglmul_res_operr:
	bra.l	res_operr
fsglmul_res_snan:
	bra.l	res_snan
fsglmul_res_qnan:
	bra.l	res_qnan
fsglmul_zero:
	bra.l	fmul_zero
fsglmul_inf_src:
	bra.l	fmul_inf_src
fsglmul_inf_dst:
	bra.l	fmul_inf_dst

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fsgldiv(): emulates the fsgldiv instruction
*		
* xdef **
*	scale_to_zero_src() - scale src exponent to zero
*	scale_to_zero_dst() - scale dst exponent to zero
*	unf_res4() - return default underflow result for sglop
*	ovf_res() - return default overflow result
* 	res_qnan() - return QNAN result	
* 	res_snan() - return SNAN result	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	a1 = pointer to extended precision destination operand
*	d0  rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms/denorms into ext/sgl/dbl precision.
*	For norms/denorms, scale the exponents such that a divide
* instruction won't cause an exception. Use the regular fsgldiv to
* compute a result. Check if the regular operands would have taken
* an exception. If so, return the default overflow/underflow result
* and return the EXOP if exceptions are enabled. Else, scale the 
* result operand to the proper exponent.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsgldiv
fsgldiv:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1	* combine src tags

	bne.w	fsgldiv_not_norm	* optimize on non-norm input
	
*
* DIVIDE: NORMs and DENORMs ONLY!
*
fsgldiv_norm:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_to_zero_src	* calculate scale factor 1
	move.l	d0,-(sp)	* save scale factor 1

	bsr.l	scale_to_zero_dst	* calculate scale factor 2

	neg.l	(sp)	* S.F. = scale1 - scale2
	add.l	d0,(sp)

	move.w	2+EXC_LV+L_SCR3(a6),d1	* fetch precision,mode
	lsr.b	#$6,d1
	move.l	(sp)+,d0
	ICMP.l	d0,#$3fff-$7ffe
	ble.w	fsgldiv_may_ovfl

	ICMP.l	d0,#$3fff-0 	* will result underflow?
	beq.w	fsgldiv_may_unfl	* maybe
	bgt.w	fsgldiv_unfl	* yes; go handle underflow

fsgldiv_normal:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* save FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp0	* perform sgl divide

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fsgldiv_normal_exit:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store result on stack
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

fsgldiv_may_ovfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* set FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute divide

	fmove.l	fpsr,d1
	fmove.l	#$0,fpcr

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX,N

	fmovem.x	fp7,-(sp)	* save result to stack
	move.w	(sp),d1	* fetch new exponent
	add.l	#$c,sp	* clear result
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	ICMP.l	d1,#$7fff	* did divide overflow?
	blt.b	fsgldiv_normal_exit

fsgldiv_ovfl_tst:
	or.w	#ovfl_inx_mask,2+EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fsgldiv_ovfl_ena	* yes

fsgldiv_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6) 	* is result negative
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass prec:rnd
	andi.b	#$30,d0	* kill precision
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

fsgldiv_ovfl_ena:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* move result to stack

	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract new bias
	andi.w	#$7fff,d1	* clear ms bit
	or.w	d2,d1	* concat old sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fsgldiv_ovfl_dis

fsgldiv_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl divide

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fsgldiv_unfl_ena	* yes

fsgldiv_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res4	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* 'Z' bit may have been set
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts

*
* UNFL is enabled. 
*
fsgldiv_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp1	* execute sgl divide

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* save result to stack
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	addi.l	#$6000,d1	* add bias
	andi.w	#$7fff,d1	* clear top bit
	or.w	d2,d1	* concat old sign, new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.b	fsgldiv_unfl_dis

*
* the divide operation MAY underflow:
*
fsgldiv_may_unfl:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp0	* execute sgl divide

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fabs.x	fp0,fp1	* make a copy of result
	fcmp.b	#1,fp1	* is |result| > 1.b?
	fbgt.w	fsgldiv_normal_exit	* no; no underflow occurred
	fblt.w	fsgldiv_unfl	* yes; underflow occurred

*
* we still don't know if underflow occurred. result is ~ equal to 1. but,
* we don't know if the result was an underflow that rounded up to a 1
* or a normalized number that rounded down to a 1. so, redo the entire 
* operation using RZ as the rounding mode to see what the pre-rounded
* result is. this case should be relatively rare.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op into fp1

	clr.l	d1	* clear scratch register
	ori.b	#rz_mode*$10,d1	* force RZ rnd mode

	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsgldiv.x	EXC_LV+FP_SCR0(a6),fp1	* execute sgl divide

	fmove.l	#$0,fpcr	* clear FPCR
	fabs.x	fp1	* make absolute value
	fcmp.b	#1,fp1	* is |result| < 1.b?
	fbge.w	fsgldiv_normal_exit	* no; no underflow occurred
	bra.w	fsgldiv_unfl	* yes; underflow occurred

**-------------------------------------------------------------------------------------------------***

*
* Divide: inputs are not both normalized; what are they?
*
fsgldiv_not_norm:
	move.w	((tbl_fsgldiv_op).b,pc,d1.w*2),d1
	jmp	((tbl_fsgldiv_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fsgldiv_op:
	dc.w	fsgldiv_norm	- tbl_fsgldiv_op * NORM / NORM
	dc.w	fsgldiv_inf_load	- tbl_fsgldiv_op * NORM / ZERO
	dc.w	fsgldiv_zero_load	- tbl_fsgldiv_op * NORM / INF
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * NORM / QNAN
	dc.w	fsgldiv_norm	- tbl_fsgldiv_op * NORM / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * NORM / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

	dc.w	fsgldiv_zero_load	- tbl_fsgldiv_op * ZERO / NORM
	dc.w	fsgldiv_res_operr	- tbl_fsgldiv_op * ZERO / ZERO
	dc.w	fsgldiv_zero_load	- tbl_fsgldiv_op * ZERO / INF
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * ZERO / QNAN
	dc.w	fsgldiv_zero_load	- tbl_fsgldiv_op * ZERO / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * ZERO / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

	dc.w	fsgldiv_inf_dst	- tbl_fsgldiv_op * INF / NORM
	dc.w	fsgldiv_inf_dst	- tbl_fsgldiv_op * INF / ZERO
	dc.w	fsgldiv_res_operr	- tbl_fsgldiv_op * INF / INF
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * INF / QNAN
	dc.w	fsgldiv_inf_dst	- tbl_fsgldiv_op * INF / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * INF / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * QNAN / NORM
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * QNAN / ZERO
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * QNAN / INF
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * QNAN / QNAN
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * QNAN / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * QNAN / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

	dc.w	fsgldiv_norm	- tbl_fsgldiv_op * DENORM / NORM
	dc.w	fsgldiv_inf_load	- tbl_fsgldiv_op * DENORM / ZERO
	dc.w	fsgldiv_zero_load	- tbl_fsgldiv_op * DENORM / INF
	dc.w	fsgldiv_res_qnan	- tbl_fsgldiv_op * DENORM / QNAN
	dc.w	fsgldiv_norm	- tbl_fsgldiv_op * DENORM / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * DENORM / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / NORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / ZERO
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / INF
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / QNAN
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / DENORM
	dc.w	fsgldiv_res_snan	- tbl_fsgldiv_op * SNAN / SNAN
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *
	dc.w	tbl_fsgldiv_op	- tbl_fsgldiv_op *

fsgldiv_res_qnan:
	bra.l	res_qnan
fsgldiv_res_snan:
	bra.l	res_snan
fsgldiv_res_operr:
	bra.l	res_operr
fsgldiv_inf_load:
	bra.l	fdiv_inf_load
fsgldiv_zero_load:
	bra.l	fdiv_zero_load
fsgldiv_inf_dst:
	bra.l	fdiv_inf_dst

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fadd(): emulates the fadd instruction
*	fsadd(): emulates the fadd instruction
*	fdadd(): emulates the fdadd instruction
*		
* xdef **
* 	addsub_scaler2() - scale the operands so they won't take exc
*	ovf_res() - return default overflow result
*	unf_res() - return default underflow result
*	res_qnan() - set QNAN result	
* 	res_snan() - set SNAN result	
*	res_operr() - set OPERR result	
*	scale_to_zero_src() - set src operand exponent equal to zero
*	scale_to_zero_dst() - set dst operand exponent equal to zero
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
* 	a1 = pointer to extended precision destination operand
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
* 	Handle NANs, infinities, and zeroes as special cases. Divide
* norms into extended, single, and double precision.
*	Do addition after scaling exponents such that exception won't
* occur. Then, check result exponent to see if exception would have
* occurred. If so, return default result and maybe EXOP. Else, insert
* the correct result exponent and return. Set FPSR bits as appropriate.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fsadd
fsadd:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl prec
	bra.b	fadd

	xdef	fdadd
fdadd:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl prec

	xdef	fadd
fadd:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1	* combine src tags

	bne.w	fadd_not_norm	* optimize on non-norm input

*
* ADD: norms and denorms
*
fadd_norm:
	bsr.l	addsub_scaler2	* scale exponents

fadd_zero_entry:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fadd.x	EXC_LV+FP_SCR0(a6),fp0	* execute add

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* fetch INEX2,N,Z

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save exc and ccode bits

	fbeq.w	fadd_zero_exit	* if result is zero, end now

	move.l	d2,-(sp)	* save d2

	fmovem.x	fp7,-(sp)	* save result to stack

	move.w	2+EXC_LV+L_SCR3(a6),d1
	lsr.b	#$6,d1

	move.w	(sp),d2	* fetch new sign, exp
	andi.l	#$7fff,d2	* strip sign
	sub.l	d0,d2	* add scale factor

	ICMP.l	d2,((tbl_fadd_ovfl).b,pc,d1.w*4) * is it an overflow?
	bge.b	fadd_ovfl	* yes

	ICMP.l	d2,((tbl_fadd_unfl).b,pc,d1.w*4) * is it an underflow?
	blt.w	fadd_unfl	* yes
	beq.w	fadd_may_unfl	* maybe; go find out

fadd_normal:
	move.w	(sp),d1
	andi.w	#$8000,d1	* keep sign
	or.w	d2,d1	* concat sign,new exp
	move.w	d1,(sp)	* insert new exponent

	fmovem.x	(sp)+,fp0	* return result in fp0

	move.l	(sp)+,d2	* restore d2
	rts

fadd_zero_exit:
*	fmove.s	#$00000000,fp0	* return zero in fp0
	rts

tbl_fadd_ovfl:
	dc.l	$7fff	* ext ovfl
	dc.l	$407f	* sgl ovfl
	dc.l	$43ff	* dbl ovfl

tbl_fadd_unfl:
	dc.l	        0	* ext unfl
	dc.l	$3f81	* sgl unfl
	dc.l	$3c01	* dbl unfl

fadd_ovfl:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fadd_ovfl_ena	* yes

	add.l	#$c,sp
fadd_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass prec:rnd
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	move.l	(sp)+,d2	* restore d2
	rts

fadd_ovfl_ena:
	move.b	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fadd_ovfl_ena_sd	* no; prec = sgl or dbl

fadd_ovfl_ena_cont:
	move.w	(sp),d1
	andi.w	#$8000,d1	* keep sign
	subi.l	#$6000,d2	* add extra bias
	andi.w	#$7fff,d2
	or.w	d2,d1	* concat sign,new exp
	move.w	d1,(sp)	* insert new exponent

	fmovem.x	(sp)+,fp1	* return EXOP in fp1
	bra.b	fadd_ovfl_dis

fadd_ovfl_ena_sd:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* keep rnd mode
	fmove.l	d1,fpcr	* set FPCR

	fadd.x	EXC_LV+FP_SCR0(a6),fp0	* execute add

	fmove.l	#$0,fpcr	* clear FPCR

	add.l	#$c,sp
	fmovem.x	fp7,-(sp)
	bra.b	fadd_ovfl_ena_cont

fadd_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	add.l	#$c,sp

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fadd.x	EXC_LV+FP_SCR0(a6),fp0	* execute add

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save status

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX,N

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fadd_unfl_ena	* yes

fadd_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* 'Z' bit may have been set
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	move.l	(sp)+,d2	* restore d2
	rts

fadd_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fadd_unfl_ena_sd	* no; sgl or dbl

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

fadd_unfl_ena_cont:
	fmove.l	#$0,fpsr	* clear FPSR

	fadd.x	EXC_LV+FP_SCR0(a6),fp1	* execute multiply

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* save result to stack
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	addi.l	#$6000,d1	* add new bias
	andi.w	#$7fff,d1	* clear top bit
	or.w	d2,d1	* concat sign,new exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.w	fadd_unfl_dis

fadd_unfl_ena_sd:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* use only rnd mode
	fmove.l	d1,fpcr	* set FPCR

	bra.b	fadd_unfl_ena_cont

*
* result is equal to the smallest normalized number in the selected precision
* if the precision is extended, this result could not have come from an 
* underflow that rounded up.
*
fadd_may_unfl:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1
	beq.w	fadd_normal	* yes; no underflow occurred

	move.l	$4(sp),d1	* extract hi(man)
	ICMP.l	d1,#$80000000	* is hi(man) = $80000000?
	bne.w	fadd_normal	* no; no underflow occurred

	tst.l	$8(sp)	* is lo(man) = $0?
	bne.w	fadd_normal	* no; no underflow occurred

	btst	#inex2_bit,EXC_LV+FPSR_EXCEPT(a6) * is INEX2 set?
	beq.w	fadd_normal	* no; no underflow occurred

*
* ok, so now the result has a exponent equal to the smallest normalized
* exponent for the selected precision. also, the mantissa is equal to
* $8000000000000000 and this mantissa is the result of rounding non-zero
* g,r,s. 
* now, we must determine whether the pre-rounded result was an underflow
* rounded "up" or a normalized number rounded "down".
* so, we do this be re-executing the add using RZ as the rounding mode and
* seeing if the new result is smaller or equal to the current result.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op into fp1

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* keep rnd prec
	ori.b	#rz_mode*$10,d1	* insert rnd mode
	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fadd.x	EXC_LV+FP_SCR0(a6),fp1	* execute add

	fmove.l	#$0,fpcr	* clear FPCR

	fabs.x	fp0	* compare absolute values
	fabs.x	fp1
	fcmp.x	fp0,fp1	* is first result > second?

	fbgt.w	fadd_unfl	* yes; it's an underflow
	bra.w	fadd_normal	* no; it's not an underflow

**-------------------------------------------------------------------------------------------------*

*
* Add: inputs are not both normalized; what are they?
*
fadd_not_norm:
	move.w	((tbl_fadd_op).b,pc,d1.w*2),d1
	jmp	((tbl_fadd_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fadd_op:
	dc.w	fadd_norm	- tbl_fadd_op * NORM + NORM
	dc.w	fadd_zero_src	- tbl_fadd_op * NORM + ZERO
	dc.w	fadd_inf_src	- tbl_fadd_op * NORM + INF
	dc.w	fadd_res_qnan	- tbl_fadd_op * NORM + QNAN
	dc.w	fadd_norm	- tbl_fadd_op * NORM + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * NORM + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

	dc.w	fadd_zero_dst	- tbl_fadd_op * ZERO + NORM
	dc.w	fadd_zero_2	- tbl_fadd_op * ZERO + ZERO
	dc.w	fadd_inf_src	- tbl_fadd_op * ZERO + INF
	dc.w	fadd_res_qnan	- tbl_fadd_op * NORM + QNAN
	dc.w	fadd_zero_dst	- tbl_fadd_op * ZERO + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * NORM + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

	dc.w	fadd_inf_dst	- tbl_fadd_op * INF + NORM
	dc.w	fadd_inf_dst	- tbl_fadd_op * INF + ZERO
	dc.w	fadd_inf_2	- tbl_fadd_op * INF + INF
	dc.w	fadd_res_qnan	- tbl_fadd_op * NORM + QNAN
	dc.w	fadd_inf_dst	- tbl_fadd_op * INF + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * NORM + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

	dc.w	fadd_res_qnan	- tbl_fadd_op * QNAN + NORM
	dc.w	fadd_res_qnan	- tbl_fadd_op * QNAN + ZERO
	dc.w	fadd_res_qnan	- tbl_fadd_op * QNAN + INF
	dc.w	fadd_res_qnan	- tbl_fadd_op * QNAN + QNAN
	dc.w	fadd_res_qnan	- tbl_fadd_op * QNAN + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * QNAN + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

	dc.w	fadd_norm	- tbl_fadd_op * DENORM + NORM
	dc.w	fadd_zero_src	- tbl_fadd_op * DENORM + ZERO
	dc.w	fadd_inf_src	- tbl_fadd_op * DENORM + INF
	dc.w	fadd_res_qnan	- tbl_fadd_op * NORM + QNAN
	dc.w	fadd_norm	- tbl_fadd_op * DENORM + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * NORM + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + NORM
	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + ZERO
	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + INF
	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + QNAN
	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + DENORM
	dc.w	fadd_res_snan	- tbl_fadd_op * SNAN + SNAN
	dc.w	tbl_fadd_op	- tbl_fadd_op *
	dc.w	tbl_fadd_op	- tbl_fadd_op *

fadd_res_qnan:
	bra.l	res_qnan
fadd_res_snan:
	bra.l	res_snan

*
* both operands are ZEROes
*
fadd_zero_2:
	move.b	SRC_EX(a0),d0	* are the signs opposite
	move.b	DST_EX(a1),d1
	eor.b	d0,d1
	bmi.w	fadd_zero_2_chk_rm	* weed out (-ZERO)+(+ZERO)

* the signs are the same. so determine whether they are positive or negative
* and return the appropriately signed zero.
	tst.b	d0	* are ZEROes positive or negative?
	bmi.b	fadd_zero_rm	* negative
	fmove.s	#$00000000,fp0	* return +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts
	
*
* the ZEROes have opposite signs:
* - therefore, we return +ZERO if the rounding modes are RN,RZ, or RP.
* - -ZERO is returned in the case of RM.
*
fadd_zero_2_chk_rm:
	move.b	3+EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* extract rnd mode
	ICMP.b	d1,#rm_mode*$10	* is rnd mode == RM?
	beq.b	fadd_zero_rm	* yes
	fmove.s	#$00000000,fp0	* return +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts

fadd_zero_rm:
	fmove.s	#$80000000,fp0	* return -ZERO
	move.b	#neg_bmask+z_bmask,EXC_LV+FPSR_CC(a6) * set NEG/Z
	rts

*
* one operand is a ZERO and the other is a DENORM or NORM. scale
* the DENORM or NORM and jump to the regular fadd routine.
*
fadd_zero_dst:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* scale the operand
	clr.w	EXC_LV+FP_SCR1_EX(a6)
	clr.l	EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)
	bra.w	fadd_zero_entry	* go execute fadd

fadd_zero_src:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)
	bsr.l	scale_to_zero_dst	* scale the operand
	clr.w	EXC_LV+FP_SCR0_EX(a6)
	clr.l	EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)
	bra.w	fadd_zero_entry	* go execute fadd

*
* both operands are INFs. an OPERR will result if the INFs have
* different signs. else, an INF of the same sign is returned
*
fadd_inf_2:
	move.b	SRC_EX(a0),d0	* exclusive or the signs
	move.b	DST_EX(a1),d1
	eor.b	d1,d0
	bmi.l	res_operr	* weed out (-INF)+(+INF)

* ok, so it's not an OPERR. but, we do have to remember to return the 
* src INF since that's where the 881/882 gets the j-bit from...

*
* operands are INF and one of {ZERO, INF, DENORM, NORM}
*
fadd_inf_src:
	fmovem.x	SRC(a0),fp0	* return src INF
	tst.b	SRC_EX(a0)	* is INF positive?
	bpl.b	fadd_inf_done	* yes; we're done
	move.b	#neg_bmask+inf_bmask,EXC_LV+FPSR_CC(a6) * set INF/NEG
	rts

*
* operands are INF and one of {ZERO, INF, DENORM, NORM}
*
fadd_inf_dst:
	fmovem.x	DST(a1),fp0	* return dst INF
	tst.b	DST_EX(a1)	* is INF positive?
	bpl.b	fadd_inf_done	* yes; we're done
	move.b	#neg_bmask+inf_bmask,EXC_LV+FPSR_CC(a6) * set INF/NEG
	rts

fadd_inf_done:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6) * set INF
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fsub(): emulates the fsub instruction
*	fssub(): emulates the fssub instruction
*	fdsub(): emulates the fdsub instruction
*		
* xdef **
* 	addsub_scaler2() - scale the operands so they won't take exc
*	ovf_res() - return default overflow result
*	unf_res() - return default underflow result
*	res_qnan() - set QNAN result	
* 	res_snan() - set SNAN result	
*	res_operr() - set OPERR result	
*	scale_to_zero_src() - set src operand exponent equal to zero
*	scale_to_zero_dst() - set dst operand exponent equal to zero
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
* 	a1 = pointer to extended precision destination operand
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
* 	Handle NANs, infinities, and zeroes as special cases. Divide
* norms into extended, single, and double precision.
*	Do subtraction after scaling exponents such that exception won't*
* occur. Then, check result exponent to see if exception would have
* occurred. If so, return default result and maybe EXOP. Else, insert
* the correct result exponent and return. Set FPSR bits as appropriate.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fssub
fssub:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl prec
	bra.b	fsub

	xdef	fdsub
fdsub:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl prec

	xdef	fsub
fsub:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info

	clr.w	d1
	move.b	EXC_LV+DTAG(a6),d1
	lsl.b	#$3,d1
	or.b	EXC_LV+STAG(a6),d1	* combine src tags

	bne.w	fsub_not_norm	* optimize on non-norm input

*
* SUB: norms and denorms
*
fsub_norm:
	bsr.l	addsub_scaler2	* scale exponents

fsub_zero_entry:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fsub.x	EXC_LV+FP_SCR0(a6),fp0	* execute subtract

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* fetch INEX2, N, Z

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save exc and ccode bits

	fbeq.w	fsub_zero_exit	* if result zero, end now

	move.l	d2,-(sp)	* save d2

	fmovem.x	fp7,-(sp)	* save result to stack

	move.w	2+EXC_LV+L_SCR3(a6),d1
	lsr.b	#$6,d1

	move.w	(sp),d2	* fetch new exponent
	andi.l	#$7fff,d2	* strip sign
	sub.l	d0,d2	* add scale factor

	ICMP.l	d2,((tbl_fsub_ovfl).b,pc,d1.w*4) * is it an overflow?
	bge.b	fsub_ovfl	* yes

	ICMP.l	d2,((tbl_fsub_unfl).b,pc,d1.w*4) * is it an underflow?
	blt.w	fsub_unfl	* yes
	beq.w	fsub_may_unfl	* maybe; go find out

fsub_normal:
	move.w	(sp),d1
	andi.w	#$8000,d1	* keep sign
	or.w	d2,d1	* insert new exponent
	move.w	d1,(sp)	* insert new exponent

	fmovem.x	(sp)+,fp0	* return result in fp0

	move.l	(sp)+,d2	* restore d2
	rts

fsub_zero_exit:
*	fmove.s	#$00000000,fp0	* return zero in fp0
	rts

tbl_fsub_ovfl:
	dc.l	$7fff	* ext ovfl
	dc.l	$407f	* sgl ovfl
	dc.l	$43ff	* dbl ovfl

tbl_fsub_unfl:
	dc.l	        0	* ext unfl
	dc.l	$3f81	* sgl unfl
	dc.l	$3c01	* dbl unfl

fsub_ovfl:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fsub_ovfl_ena	* yes

	add.l	#$c,sp
fsub_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass prec:rnd
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	move.l	(sp)+,d2	* restore d2
	rts

fsub_ovfl_ena:
	move.b	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fsub_ovfl_ena_sd	* no

fsub_ovfl_ena_cont:
	move.w	(sp),d1	* fetch {sgn,exp}
	andi.w	#$8000,d1	* keep sign
	subi.l	#$6000,d2	* subtract new bias
	andi.w	#$7fff,d2	* clear top bit
	or.w	d2,d1	* concat sign,exp
	move.w	d1,(sp)	* insert new exponent

	fmovem.x	(sp)+,fp1	* return EXOP in fp1
	bra.b	fsub_ovfl_dis

fsub_ovfl_ena_sd:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* clear rnd prec
	fmove.l	d1,fpcr	* set FPCR

	fsub.x	EXC_LV+FP_SCR0(a6),fp0	* execute subtract

	fmove.l	#$0,fpcr	* clear FPCR

	add.l	#$c,sp
	fmovem.x	fp7,-(sp)
	bra.b	fsub_ovfl_ena_cont

fsub_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	add.l	#$c,sp

	fmovem.x	EXC_LV+FP_SCR1(a6),fp0	* load dst op
	
	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsub.x	EXC_LV+FP_SCR0(a6),fp0	* execute subtract

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save status

	or.l	d1,EXC_LV+USER_FPSR(a6)

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fsub_unfl_ena	* yes

fsub_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* 'Z' may have been set
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	move.l	(sp)+,d2	* restore d2
	rts

fsub_unfl_ena:
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* is precision extended?
	bne.b	fsub_unfl_ena_sd	* no

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

fsub_unfl_ena_cont:
	fmove.l	#$0,fpsr	* clear FPSR

	fsub.x	EXC_LV+FP_SCR0(a6),fp1	* execute subtract

	fmove.l	#$0,fpcr	* clear FPCR

	fmovem.x	fp1,EXC_LV+FP_SCR0(a6)	* store result to stack
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	addi.l	#$6000,d1	* subtract new bias
	andi.w	#$7fff,d1	* clear top bit
	or.w	d2,d1	* concat sgn,exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	bra.w	fsub_unfl_dis

fsub_unfl_ena_sd:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* clear rnd prec
	fmove.l	d1,fpcr	* set FPCR

	bra.b	fsub_unfl_ena_cont

*
* result is equal to the smallest normalized number in the selected precision
* if the precision is extended, this result could not have come from an
* underflow that rounded up.
*
fsub_may_unfl:
	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* fetch rnd prec
	beq.w	fsub_normal	* yes; no underflow occurred

	move.l	$4(sp),d1
	ICMP.l	d1,#$80000000	* is hi(man) = $80000000?
	bne.w	fsub_normal	* no; no underflow occurred

	tst.l	$8(sp)	* is lo(man) = $0?
	bne.w	fsub_normal	* no; no underflow occurred

	btst	#inex2_bit,EXC_LV+FPSR_EXCEPT(a6) * is INEX2 set?
	beq.w	fsub_normal	* no; no underflow occurred

*
* ok, so now the result has a exponent equal to the smallest normalized
* exponent for the selected precision. also, the mantissa is equal to
* $8000000000000000 and this mantissa is the result of rounding non-zero
* g,r,s. 
* now, we must determine whether the pre-rounded result was an underflow
* rounded "up" or a normalized number rounded "down".
* so, we do this be re-executing the add using RZ as the rounding mode and
* seeing if the new result is smaller or equal to the current result.
*
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* load dst op into fp1

	move.l	EXC_LV+L_SCR3(a6),d1
	andi.b	#$c0,d1	* keep rnd prec
	ori.b	#rz_mode*$10,d1	* insert rnd mode
	fmove.l	d1,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsub.x	EXC_LV+FP_SCR0(a6),fp1	* execute subtract

	fmove.l	#$0,fpcr	* clear FPCR

	fabs.x	fp0	* compare absolute values
	fabs.x	fp1
	fcmp.x	fp0,fp1	* is first result > second?

	fbgt.w	fsub_unfl	* yes; it's an underflow
	bra.w	fsub_normal	* no; it's not an underflow

**-------------------------------------------------------------------------------------------------*

*
* Sub: inputs are not both normalized; what are they?
*
fsub_not_norm:
	move.w	((tbl_fsub_op).b,pc,d1.w*2),d1
	jmp	((tbl_fsub_op).b,pc,d1.w*1)

	illegal
	dc.w	$48
tbl_fsub_op:
	dc.w	fsub_norm	- tbl_fsub_op * NORM - NORM
	dc.w	fsub_zero_src	- tbl_fsub_op * NORM - ZERO
	dc.w	fsub_inf_src	- tbl_fsub_op * NORM - INF
	dc.w	fsub_res_qnan	- tbl_fsub_op * NORM - QNAN
	dc.w	fsub_norm	- tbl_fsub_op * NORM - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * NORM - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

	dc.w	fsub_zero_dst	- tbl_fsub_op * ZERO - NORM
	dc.w	fsub_zero_2	- tbl_fsub_op * ZERO - ZERO
	dc.w	fsub_inf_src	- tbl_fsub_op * ZERO - INF
	dc.w	fsub_res_qnan	- tbl_fsub_op * NORM - QNAN
	dc.w	fsub_zero_dst	- tbl_fsub_op * ZERO - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * NORM - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

	dc.w	fsub_inf_dst	- tbl_fsub_op * INF - NORM
	dc.w	fsub_inf_dst	- tbl_fsub_op * INF - ZERO
	dc.w	fsub_inf_2	- tbl_fsub_op * INF - INF
	dc.w	fsub_res_qnan	- tbl_fsub_op * NORM - QNAN
	dc.w	fsub_inf_dst	- tbl_fsub_op * INF - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * NORM - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

	dc.w	fsub_res_qnan	- tbl_fsub_op * QNAN - NORM
	dc.w	fsub_res_qnan	- tbl_fsub_op * QNAN - ZERO
	dc.w	fsub_res_qnan	- tbl_fsub_op * QNAN - INF
	dc.w	fsub_res_qnan	- tbl_fsub_op * QNAN - QNAN
	dc.w	fsub_res_qnan	- tbl_fsub_op * QNAN - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * QNAN - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

	dc.w	fsub_norm	- tbl_fsub_op * DENORM - NORM
	dc.w	fsub_zero_src	- tbl_fsub_op * DENORM - ZERO
	dc.w	fsub_inf_src	- tbl_fsub_op * DENORM - INF
	dc.w	fsub_res_qnan	- tbl_fsub_op * NORM - QNAN
	dc.w	fsub_norm	- tbl_fsub_op * DENORM - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * NORM - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - NORM
	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - ZERO
	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - INF
	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - QNAN
	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - DENORM
	dc.w	fsub_res_snan	- tbl_fsub_op * SNAN - SNAN
	dc.w	tbl_fsub_op	- tbl_fsub_op *
	dc.w	tbl_fsub_op	- tbl_fsub_op *

fsub_res_qnan:
	bra.l	res_qnan
fsub_res_snan:
	bra.l	res_snan

*
* both operands are ZEROes
*
fsub_zero_2:
	move.b	SRC_EX(a0),d0
	move.b	DST_EX(a1),d1
	eor.b	d1,d0
	bpl.b	fsub_zero_2_chk_rm

* the signs are opposite, so, return a ZERO w/ the sign of the dst ZERO
	tst.b	d0	* is dst negative?
	bmi.b	fsub_zero_2_rm	* yes
	fmove.s	#$00000000,fp0	* no; return +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts

*
* the ZEROes have the same signs:
* - therefore, we return +ZERO if the rounding mode is RN,RZ, or RP
* - -ZERO is returned in the case of RM.
*
fsub_zero_2_chk_rm:
	move.b	3+EXC_LV+L_SCR3(a6),d1
	andi.b	#$30,d1	* extract rnd mode
	ICMP.b	d1,#rm_mode*$10	* is rnd mode = RM?
	beq.b	fsub_zero_2_rm	* yes
	fmove.s	#$00000000,fp0	* no; return +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set Z
	rts

fsub_zero_2_rm:
	fmove.s	#$80000000,fp0	* return -ZERO
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6)	* set Z/NEG
	rts

*
* one operand is a ZERO and the other is a DENORM or a NORM.
* scale the DENORM or NORM and jump to the regular fsub routine.
*
fsub_zero_dst:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	bsr.l	scale_to_zero_src	* scale the operand
	clr.w	EXC_LV+FP_SCR1_EX(a6)
	clr.l	EXC_LV+FP_SCR1_HI(a6)
	clr.l	EXC_LV+FP_SCR1_LO(a6)
	bra.w	fsub_zero_entry	* go execute fsub

fsub_zero_src:
	move.w	DST_EX(a1),EXC_LV+FP_SCR1_EX(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)
	bsr.l	scale_to_zero_dst	* scale the operand
	clr.w	EXC_LV+FP_SCR0_EX(a6)
	clr.l	EXC_LV+FP_SCR0_HI(a6)
	clr.l	EXC_LV+FP_SCR0_LO(a6)
	bra.w	fsub_zero_entry	* go execute fsub

*
* both operands are INFs. an OPERR will result if the INFs have the
* same signs. else,
*
fsub_inf_2:
	move.b	SRC_EX(a0),d0	* exclusive or the signs
	move.b	DST_EX(a1),d1
	eor.b	d1,d0
	bpl.l	res_operr	* weed out (-INF)+(+INF)

* ok, so it's not an OPERR. but we do have to remember to return
* the src INF since that's where the 881/882 gets the j-bit.

fsub_inf_src:
	fmovem.x	SRC(a0),fp0	* return src INF
	fneg.x	fp0	* invert sign
	fbge.w	fsub_inf_done	* sign is now positive
	move.b	#neg_bmask+inf_bmask,EXC_LV+FPSR_CC(a6) * set INF/NEG
	rts

fsub_inf_dst:
	fmovem.x	DST(a1),fp0	* return dst INF
	tst.b	DST_EX(a1)	* is INF negative?
	bpl.b	fsub_inf_done	* no
	move.b	#neg_bmask+inf_bmask,EXC_LV+FPSR_CC(a6) * set INF/NEG
	rts

fsub_inf_done:
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set INF
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fsqrt(): emulates the fsqrt instruction
*	fssqrt(): emulates the fssqrt instruction
*	fdsqrt(): emulates the fdsqrt instruction
*		
* xdef **
*	scale_sqrt() - scale the source operand
*	unf_res() - return default underflow result
*	ovf_res() - return default overflow result
* 	res_qnan_1op() - return QNAN result
* 	res_snan_1op() - return SNAN result
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0  rnd prec,mode	
*		
* OUTPUT **************************************************************
*	fp0 = result	
*	fp1 = EXOP (if exception occurred)
*		
* ALGORITHM ***********************************************************
*	Handle NANs, infinities, and zeroes as special cases. Divide
* norms/denorms into ext/sgl/dbl precision.
*	For norms/denorms, scale the exponents such that a sqrt
* instruction won't cause an exception. Use the regular fsqrt to
* compute a result. Check if the regular operands would have taken
* an exception. If so, return the default overflow/underflow result
* and return the EXOP if exceptions are enabled. Else, scale the 
* result operand to the proper exponent.
*		
**-------------------------------------------------------------------------------------------------

	xdef	fssqrt
fssqrt:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl precision
	bra.b	fsqrt

	xdef	fdsqrt
fdsqrt:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl precision

	xdef	fsqrt
fsqrt:
	move.l	d0,EXC_LV+L_SCR3(a6)	* store rnd info
	clr.w	d1
	move.b	EXC_LV+STAG(a6),d1
	bne.w	fsqrt_not_norm	* optimize on non-norm input

*
* SQUARE ROOT: norms and denorms ONLY!
*
fsqrt_norm:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.l	res_operr	* yes

	andi.b	#$c0,d0	* is precision extended?
	bne.b	fsqrt_not_ext	* no; go handle sgl or dbl

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsqrt.x	(a0),fp0	* execute square root

	fmove.l	fpsr,d1
	or.l	d1,EXC_LV+USER_FPSR(a6)	* set N,INEX

	rts

fsqrt_denorm:
	tst.b	SRC_EX(a0)	* is operand negative?
	bmi.l	res_operr	* yes

	andi.b	#$c0,d0	* is precision extended?
	bne.b	fsqrt_not_ext	* no; go handle sgl or dbl

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_sqrt	* calculate scale factor

	bra.w	fsqrt_sd_normal

*
* operand is either single or double
*
fsqrt_not_ext:
	ICMP.b	d0,#s_mode*$10	* separate sgl/dbl prec
	bne.w	fsqrt_dbl

*
* operand is to be rounded to single precision
*
fsqrt_sgl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_sqrt	* calculate scale factor

	ICMP.l	d0,#$3fff-$3f81	* will move in underflow?
	beq.w	fsqrt_sd_may_unfl
	bgt.w	fsqrt_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$407f	* will move in overflow?
	beq.w	fsqrt_sd_may_ovfl	* maybe; go check
	blt.w	fsqrt_sd_ovfl	* yes; go handle overflow

*
* operand will NOT overflow or underflow when moved in to the fp reg file
*
fsqrt_sd_normal:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fsqrt.x	EXC_LV+FP_SCR0(a6),fp0	* perform absolute

	fmove.l	fpsr,d1	* save FPSR
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fsqrt_sd_normal_exit:
	move.l	d2,-(sp)	* save d2
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load sgn,exp
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	sub.l	d0,d1	* add scale factor
	andi.w	#$8000,d2	* keep old sign
	or.w	d1,d2	* concat old sign,new exp
	move.w	d2,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	move.l	(sp)+,d2	* restore d2
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return result in fp0
	rts

*
* operand is to be rounded to double precision
*
fsqrt_dbl:
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	bsr.l	scale_sqrt	* calculate scale factor

	ICMP.l	d0,#$3fff-$3c01	* will move in underflow?
	beq.w	fsqrt_sd_may_unfl
	bgt.b	fsqrt_sd_unfl	* yes; go handle underflow
	ICMP.l	d0,#$3fff-$43ff	* will move in overflow?
	beq.w	fsqrt_sd_may_ovfl	* maybe; go check
	blt.w	fsqrt_sd_ovfl	* yes; go handle overflow
	bra.w	fsqrt_sd_normal	* no; ho handle normalized op

* we're on the line here and the distinguising characteristic is whether
* the exponent is 3fff or 3ffe. if it's 3ffe, then it's a safe number
* elsewise fall through to underflow.
fsqrt_sd_may_unfl:
	btst	#$0,1+EXC_LV+FP_SCR0_EX(a6)	* is exponent $3fff?
	bne.w	fsqrt_sd_normal	* yes, so no underflow

*
* operand WILL underflow when moved in to the fp register file
*
fsqrt_sd_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set unfl exc bit

	fmove.l	#rz_mode*$10,fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fsqrt.x 	EXC_LV+FP_SCR0(a6),fp0	* execute square root

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

* if underflow or inexact is enabled, go calculate EXOP first.
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0b,d1	* is UNFL or INEX enabled?
	bne.b	fsqrt_sd_unfl_ena	* yes

fsqrt_sd_unfl_dis:
	fmovem.x	fp0,EXC_LV+FP_SCR0(a6)	* store out result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: result addr
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set possible 'Z' ccode
	fmovem.x	EXC_LV+FP_SCR0(a6),fp0	* return default result in fp0
	rts	

*
* operand will underflow AND underflow is enabled. 
* therefore, we must return the result rounded to extended precision.
*
fsqrt_sd_unfl_ena:
	move.l	EXC_LV+FP_SCR0_HI(a6),EXC_LV+FP_SCR1_HI(a6)
	move.l	EXC_LV+FP_SCR0_LO(a6),EXC_LV+FP_SCR1_LO(a6)
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* load current exponent

	move.l	d2,-(sp)	* save d2
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* subtract scale factor
	addi.l	#$6000,d1	* add new bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat new sign,new exp
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)	* insert new exp
	fmovem.x	EXC_LV+FP_SCR1(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fsqrt_sd_unfl_dis

*
* operand WILL overflow.
*
fsqrt_sd_ovfl:
	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fsqrt.x	EXC_LV+FP_SCR0(a6),fp0	* perform square root

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save FPSR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

fsqrt_sd_ovfl_tst:
	or.l	#ovfl_inx_mask,EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$13,d1	* is OVFL or INEX enabled?
	bne.b	fsqrt_sd_ovfl_ena	* yes

*
* OVFL is not enabled; therefore, we must create the default result by
* calling ovf_res().
*
fsqrt_sd_ovfl_dis:
	btst	#neg_bit,EXC_LV+FPSR_CC(a6)	* is result negative?
	sne	d1	* set sign param accordingly
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: prec,mode
	bsr.l	ovf_res	* calculate default result
	or.b	d0,EXC_LV+FPSR_CC(a6)	* set INF,N if applicable
	fmovem.x	(a0),fp0	* return default result in fp0
	rts

*
* OVFL is enabled.
* the INEX2 bit has already been updated by the round to the correct precision.
* now, round to extended(and don't alter the FPSR).
*
fsqrt_sd_ovfl_ena:
	move.l	d2,-(sp)	* save d2
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* fetch {sgn,exp}
	move.l	d1,d2	* make a copy
	andi.l	#$7fff,d1	* strip sign
	andi.w	#$8000,d2	* keep old sign
	sub.l	d0,d1	* add scale factor
	subi.l	#$6000,d1	* subtract bias
	andi.w	#$7fff,d1
	or.w	d2,d1	* concat sign,exp
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	move.l	(sp)+,d2	* restore d2
	bra.b	fsqrt_sd_ovfl_dis

*
* the move in MAY underflow. so...
*
fsqrt_sd_may_ovfl:
	btst	#$0,1+EXC_LV+FP_SCR0_EX(a6)	* is exponent $3fff?
	bne.w	fsqrt_sd_ovfl	* yes, so overflow

	fmove.l	#$0,fpsr	* clear FPSR
	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fsqrt.x	EXC_LV+FP_SCR0(a6),fp0	* perform absolute

	fmove.l	fpsr,d1	* save status
	fmove.l	#$0,fpcr	* clear FPCR

	or.l	d1,EXC_LV+USER_FPSR(a6)	* save INEX2,N

	fmove.x	fp0,fp1	* make a copy of result
	fcmp.b	#1,fp1	* is |result| >= 1.b?
	fbge.w	fsqrt_sd_ovfl_tst	* yes; overflow has occurred

* no, it didn't overflow; we have correct result
	bra.w	fsqrt_sd_normal_exit

**-------------------------------------------------------------------------------------------------*

*
* input is not normalized; what is it?
*
fsqrt_not_norm:
	ICMP.b	d1,#DENORM	* weed out DENORM
	beq.w	fsqrt_denorm
	ICMP.b	d1,#ZERO	* weed out ZERO
	beq.b	fsqrt_zero
	ICMP.b	d1,#INF	* weed out INF
	beq.b	fsqrt_inf
	ICMP.b	d1,#SNAN	* weed out SNAN
	beq.l	res_snan_1op
	bra.l	res_qnan_1op

*
* 	fsqrt(+0) = +0
* 	fsqrt(-0) = -0
*	fsqrt(+INF) = +INF
* 	fsqrt(-INF) = OPERR
*
fsqrt_zero:
	tst.b	SRC_EX(a0)	* is ZERO positive or negative?
	bmi.b	fsqrt_zero_m	* negative
fsqrt_zero_p:	
	fmove.s	#$00000000,fp0	* return +ZERO
	move.b	#z_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z' ccode bit
	rts
fsqrt_zero_m:
	fmove.s	#$80000000,fp0	* return -ZERO
	move.b	#z_bmask+neg_bmask,EXC_LV+FPSR_CC(a6)	* set 'Z','N' ccode bits
	rts

fsqrt_inf:
	tst.b	SRC_EX(a0)	* is INF positive or negative?
	bmi.l	res_operr	* negative
fsqrt_inf_p:
	fmovem.x	SRC(a0),fp0	* return +INF in fp0
	move.b	#inf_bmask,EXC_LV+FPSR_CC(a6)	* set 'I' ccode bit
	rts

**-------------------------------------------------------------------------------------------------*

**-------------------------------------------------------------------------------------------------
* XDEF **
*	addsub_scaler2(): scale inputs to fadd/fsub such that no
*	  OVFL/UNFL exceptions will result
*		
* xdef **
*	norm() - normalize mantissa after adjusting exponent
*		
* INPUT ***************************************************************
*	EXC_LV+FP_SRC(a6) = fp op1(src)	
*	EXC_LV+FP_DST(a6) = fp op2(dst)	
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_SRC(a6) = fp op1 scaled(src)	
*	EXC_LV+FP_DST(a6) = fp op2 scaled(dst)	
*	d0         = scale amount	
*		
* ALGORITHM ***********************************************************
* 	If the DST exponent is > the SRC exponent, set the DST exponent
* equal to $3fff and scale the SRC exponent by the value that the
* DST exponent was scaled by. If the SRC exponent is greater or equal,
* do the opposite. Return this scale factor in d0.
*	If the two exponents differ by > the number of mantissa bits
* plus two, then set the smallest exponent to a very small value as a
* quick shortcut.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	addsub_scaler2
addsub_scaler2:
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	DST_HI(a1),EXC_LV+FP_SCR1_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.l	DST_LO(a1),EXC_LV+FP_SCR1_LO(a6)
	move.w	SRC_EX(a0),d0
	move.w	DST_EX(a1),d1
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)
	move.w	d1,EXC_LV+FP_SCR1_EX(a6)

	andi.w	#$7fff,d0
	andi.w	#$7fff,d1
	move.w	d0,EXC_LV+L_SCR1(a6)	* store src exponent
	move.w	d1,2+EXC_LV+L_SCR1(a6)	* store dst exponent

	ICMP.w	d0, d1	* is src exp >= dst exp?
	bge.l	src_exp_ge2

* dst exp is >  src exp; scale dst to exp = $3fff
dst_exp_gt2:
	bsr.l	scale_to_zero_dst
	move.l	d0,-(sp)	* save scale factor

	ICMP.b	EXC_LV+STAG(a6),#DENORM	* is dst denormalized?
	bne.b	cmpexp12

	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm	* normalize the denorm; result is new exp
	neg.w	d0	* new exp = -(shft val)
	move.w	d0,EXC_LV+L_SCR1(a6)	* inset new exp

cmpexp12:
	move.w	2+EXC_LV+L_SCR1(a6),d0
	subi.w	#mantissalen+2,d0	* subtract mantissalen+2 from larger exp

	ICMP.w	d0,EXC_LV+L_SCR1(a6)	* is difference >= len(mantissa)+2?
	bge.b	quick_scale12

	move.w	EXC_LV+L_SCR1(a6),d0
	add.w	$2(sp),d0	* scale src exponent by scale factor
	move.w	EXC_LV+FP_SCR0_EX(a6),d1
	and.w	#$8000,d1
	or.w	d1,d0	* concat {sgn,new exp}
	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new dst exponent

	move.l	(sp)+,d0	* return SCALE factor
	rts

quick_scale12:
	andi.w	#$8000,EXC_LV+FP_SCR0_EX(a6)	* zero src exponent
	bset	#$0,1+EXC_LV+FP_SCR0_EX(a6)	* set exp = 1

	move.l	(sp)+,d0	* return SCALE factor
	rts

* src exp is >= dst exp; scale src to exp = $3fff
src_exp_ge2:
	bsr.l	scale_to_zero_src
	move.l	d0,-(sp)	* save scale factor

	ICMP.b	EXC_LV+DTAG(a6),#DENORM	* is dst denormalized?
	bne.b	cmpexp22
	lea	EXC_LV+FP_SCR1(a6),a0
	bsr.l	norm	* normalize the denorm; result is new exp
	neg.w	d0	* new exp = -(shft val)
	move.w	d0,2+EXC_LV+L_SCR1(a6)	* inset new exp

cmpexp22:
	move.w	EXC_LV+L_SCR1(a6),d0
	subi.w	#mantissalen+2,d0	* subtract mantissalen+2 from larger exp

	ICMP.w	d0,2+EXC_LV+L_SCR1(a6)	* is difference >= len(mantissa)+2?
	bge.b	quick_scale22

	move.w	2+EXC_LV+L_SCR1(a6),d0
	add.w	$2(sp),d0	* scale dst exponent by scale factor
	move.w	EXC_LV+FP_SCR1_EX(a6),d1
	andi.w	#$8000,d1
	or.w	d1,d0	* concat {sgn,new exp}
	move.w	d0,EXC_LV+FP_SCR1_EX(a6)	* insert new dst exponent

	move.l	(sp)+,d0	* return SCALE factor
	rts

quick_scale22:
	andi.w	#$8000,EXC_LV+FP_SCR1_EX(a6)	* zero dst exponent
	bset	#$0,1+EXC_LV+FP_SCR1_EX(a6)	* set exp = 1

	move.l	(sp)+,d0	* return SCALE factor	
	rts

**-------------------------------------------------------------------------------------------------*

**-------------------------------------------------------------------------------------------------
* XDEF **
*	scale_to_zero_src(): scale the exponent of extended precision
*	     value at EXC_LV+FP_SCR0(a6).
*		
* xdef **
*	norm() - normalize the mantissa if the operand was a DENORM
*		
* INPUT ***************************************************************
*	EXC_LV+FP_SCR0(a6) = extended precision operand to be scaled
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_SCR0(a6) = scaled extended precision operand
*	d0	    = scale value	
*		
* ALGORITHM ***********************************************************
* 	Set the exponent of the input operand to $3fff. Save the value
* of the difference between the original and new exponent. Then, 
* normalize the operand if it was a DENORM. Add this normalization
* value to the previous value. Return the result.
*		
**-------------------------------------------------------------------------------------------------

	xdef	scale_to_zero_src
scale_to_zero_src:
	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* extract operand's {sgn,exp}
	move.w	d1,d0	* make a copy

	andi.l	#$7fff,d1	* extract operand's exponent

	andi.w	#$8000,d0	* extract operand's sgn
	or.w	#$3fff,d0	* insert new operand's exponent(=0)

	move.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert biased exponent

	ICMP.b	EXC_LV+STAG(a6),#DENORM	* is operand normalized?
	beq.b	stzs_denorm	* normalize the DENORM

stzs_norm:
	move.l	#$3fff,d0
	sub.l	d1,d0	* scale = BIAS + (-exp)

	rts

stzs_denorm:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass ptr to src op
	bsr.l	norm	* normalize denorm
	neg.l	d0	* new exponent = -(shft val)
	move.l	d0,d1	* prepare for op_norm call
	bra.b	stzs_norm	* finish scaling

***

**-------------------------------------------------------------------------------------------------
* XDEF **
*	scale_sqrt(): scale the input operand exponent so a subsequent
*	      fsqrt operation won't take an exception.
*		
* xdef **
*	norm() - normalize the mantissa if the operand was a DENORM
*		
* INPUT ***************************************************************
*	EXC_LV+FP_SCR0(a6) = extended precision operand to be scaled
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_SCR0(a6) = scaled extended precision operand
*	d0	    = scale value	
*		
* ALGORITHM ***********************************************************
*	If the input operand is a DENORM, normalize it.
* 	If the exponent of the input operand is even, set the exponent
* to $3ffe and return a scale factor of "(exp-$3ffe)/2". If the 
* exponent of the input operand is off, set the exponent to ox3fff and
* return a scale factor of "(exp-$3fff)/2". 
*		
**-------------------------------------------------------------------------------------------------

	xdef	scale_sqrt
scale_sqrt:
	ICMP.b	EXC_LV+STAG(a6),#DENORM	* is operand normalized?
	beq.b	ss_denorm	* normalize the DENORM

	move.w	EXC_LV+FP_SCR0_EX(a6),d1	* extract operand's {sgn,exp}
	andi.l	#$7fff,d1	* extract operand's exponent

	andi.w	#$8000,EXC_LV+FP_SCR0_EX(a6)	* extract operand's sgn

	btst	#$0,d1	* is exp even or odd?
	beq.b	ss_norm_even

	ori.w	#$3fff,EXC_LV+FP_SCR0_EX(a6)	* insert new operand's exponent(=0)

	move.l	#$3fff,d0
	sub.l	d1,d0	* scale = BIAS + (-exp)
	asr.l	#$1,d0	* divide scale factor by 2
	rts

ss_norm_even:
	ori.w	#$3ffe,EXC_LV+FP_SCR0_EX(a6)	* insert new operand's exponent(=0)

	move.l	#$3ffe,d0
	sub.l	d1,d0	* scale = BIAS + (-exp)
	asr.l	#$1,d0	* divide scale factor by 2
	rts

ss_denorm:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass ptr to src op
	bsr.l	norm	* normalize denorm

	btst	#$0,d0	* is exp even or odd?
	beq.b	ss_denorm_even

	ori.w	#$3fff,EXC_LV+FP_SCR0_EX(a6)	* insert new operand's exponent(=0)

	add.l	#$3fff,d0
	asr.l	#$1,d0	* divide scale factor by 2
	rts

ss_denorm_even:
	ori.w	#$3ffe,EXC_LV+FP_SCR0_EX(a6)	* insert new operand's exponent(=0)

	add.l	#$3ffe,d0
	asr.l	#$1,d0	* divide scale factor by 2
	rts

***

**-------------------------------------------------------------------------------------------------
* XDEF **
*	scale_to_zero_dst(): scale the exponent of extended precision
*	     value at EXC_LV+FP_SCR1(a6).
*		
* xdef **
*	norm() - normalize the mantissa if the operand was a DENORM
*		
* INPUT ***************************************************************
*	EXC_LV+FP_SCR1(a6) = extended precision operand to be scaled
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_SCR1(a6) = scaled extended precision operand
*	d0	    = scale value	
*		
* ALGORITHM ***********************************************************
* 	Set the exponent of the input operand to $3fff. Save the value
* of the difference between the original and new exponent. Then, 
* normalize the operand if it was a DENORM. Add this normalization
* value to the previous value. Return the result.
*		
**-------------------------------------------------------------------------------------------------

	xdef	scale_to_zero_dst
scale_to_zero_dst:
	move.w	EXC_LV+FP_SCR1_EX(a6),d1	* extract operand's {sgn,exp}
	move.w	d1,d0	* make a copy

	andi.l	#$7fff,d1	* extract operand's exponent

	andi.w	#$8000,d0	* extract operand's sgn
	or.w	#$3fff,d0	* insert new operand's exponent(=0)

	move.w	d0,EXC_LV+FP_SCR1_EX(a6)	* insert biased exponent

	ICMP.b	EXC_LV+DTAG(a6),#DENORM	* is operand normalized?
	beq.b	stzd_denorm	* normalize the DENORM

stzd_norm:
	move.l	#$3fff,d0
	sub.l	d1,d0	* scale = BIAS + (-exp)
	rts

stzd_denorm:
	lea	EXC_LV+FP_SCR1(a6),a0	* pass ptr to dst op
	bsr.l	norm	* normalize denorm
	neg.l	d0	* new exponent = -(shft val)
	move.l	d0,d1	* prepare for op_norm call
	bra.b	stzd_norm	* finish scaling

**-------------------------------------------------------------------------------------------------*

**-------------------------------------------------------------------------------------------------
* XDEF **
*	res_qnan(): return default result w/ QNAN operand for dyadic
*	res_snan(): return default result w/ SNAN operand for dyadic
*	res_qnan_1op(): return dflt result w/ QNAN operand for monadic
*	res_snan_1op(): return dflt result w/ SNAN operand for monadic
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	EXC_LV+FP_SRC(a6) = pointer to extended precision src operand
*	EXC_LV+FP_DST(a6) = pointer to extended precision dst operand
* 		
* OUTPUT **************************************************************
*	fp0 = default result	
*		
* ALGORITHM ***********************************************************
* 	If either operand (but not both operands) of an operation is a
* nonsignalling NAN, then that NAN is returned as the result. If both
* operands are nonsignalling NANs, then the destination operand 
* nonsignalling NAN is returned as the result.
* 	If either operand to an operation is a signalling NAN (SNAN),
* then, the SNAN bit is set in the FPSR EXC byte. If the SNAN trap
* enable bit is set in the FPCR, then the trap is taken and the 
* destination is not modified. If the SNAN trap enable bit is not set,
* then the SNAN is converted to a nonsignalling NAN (by setting the 
* SNAN bit in the operand to one), and the operation continues as 
* described in the preceding paragraph, for nonsignalling NANs.
*	Make sure the appropriate FPSR bits are set before exiting.
*		
**-------------------------------------------------------------------------------------------------

	xdef	res_qnan
	xdef	res_snan
res_qnan:
res_snan:
	ICMP.b	EXC_LV+DTAG(a6), #SNAN	* is the dst an SNAN?
	beq.b	dst_snan2
	ICMP.b	EXC_LV+DTAG(a6), #QNAN	* is the dst a  QNAN?
	beq.b	dst_qnan2
src_nan:
	ICMP.b	EXC_LV+STAG(a6), #QNAN
	beq.b	src_qnan2
	xdef	res_snan_1op
res_snan_1op:
src_snan2:
	bset	#$6, EXC_LV+FP_SRC_HI(a6)	* set SNAN bit
	or.l	#nan_mask+aiop_mask+snan_mask, EXC_LV+USER_FPSR(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	bra.b	nan_comp
	xdef	res_qnan_1op
res_qnan_1op:
src_qnan2:
	or.l	#nan_mask, EXC_LV+USER_FPSR(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	bra.b	nan_comp
dst_snan2:
	or.l	#nan_mask+aiop_mask+snan_mask, EXC_LV+USER_FPSR(a6)
	bset	#$6, EXC_LV+FP_DST_HI(a6)	* set SNAN bit
	lea	EXC_LV+FP_DST(a6), a0
	bra.b	nan_comp
dst_qnan2:
	lea	EXC_LV+FP_DST(a6), a0
	ICMP.b	EXC_LV+STAG(a6), #SNAN
	bne	nan_done
	or.l	#aiop_mask+snan_mask, EXC_LV+USER_FPSR(a6)
nan_done:
	or.l	#nan_mask, EXC_LV+USER_FPSR(a6)
nan_comp:
	btst	#$7, FTEMP_EX(a0)	* is NAN neg?
	beq.b	nan_not_neg
	or.l	#neg_mask, EXC_LV+USER_FPSR(a6)
nan_not_neg:
	fmovem.x	(a0), fp0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	res_operr(): return default result during operand error
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	fp0 = default operand error result
*		
* ALGORITHM ***********************************************************
*	An nonsignalling NAN is returned as the default result when
* an operand error occurs for the following cases:
*		
* 	Multiply: (Infinity x Zero)	
* 	Divide  : (Zero / Zero) || (Infinity / Infinity)
*		
**-------------------------------------------------------------------------------------------------

	xdef	res_operr
res_operr:
	or.l	#nan_mask+operr_mask+aiop_mask, EXC_LV+USER_FPSR(a6)
	fmovem.x	nan_return(pc), fp0
	rts

nan_return:	
	dc.l	$7fff0000, $ffffffff, $ffffffff

**-------------------------------------------------------------------------------------------------
* fdbcc(): routine to emulate the fdbcc instruction
*		
* XDEF ** *
*	_fdbcc()	
*		
* xdef ** *
*	fetch_dreg() - fetch Dn value	
*	store_dreg_l() - store updated Dn value
*		
* INPUT ***************************************************************
*	d0 = displacement	
*		
* OUTPUT ************************************************************** *
*	none	
*		
* ALGORITHM ***********************************************************
*	This routine checks which conditional predicate is specified by
* the stacked fdbcc instruction opcode and then branches to a routine
* for that predicate. The corresponding fbcc instruction is then used
* to see whether the condition (specified by the stacked FPSR) is true
* or false.	
*	If a BSUN exception should be indicated, the BSUN and ABSUN
* bits are set in the stacked FPSR. If the BSUN exception is enabled,
* the fbsun_flg is set in the EXC_LV+SPCOND_FLG location on the stack. If an 
* enabled BSUN should not be flagged and the predicate is true, then
* Dn is fetched and decremented by one. If Dn is not equal to -1, add
* the displacement value to the stacked PC so that when an "rte" is
* finally executed, the branch occurs.	
*		
**-------------------------------------------------------------------------------------------------
	xdef	_fdbcc
_fdbcc:
	move.l	d0,EXC_LV+L_SCR1(a6)	* save displacement

	move.w	EXC_LV+EXC_CMDREG(a6),d0	* fetch predicate

	clr.l	d1	* clear scratch reg
	move.b	EXC_LV+FPSR_CC(a6),d1	* fetch fp ccodes
	ror.l	#$8,d1	* rotate to top byte
	fmove.l	d1,fpsr	* insert into FPSR

	move.w	((tbl_fdbcc).b,pc,d0.w*2),d1 * load table
	jmp	((tbl_fdbcc).b,pc,d1.w) * jump to fdbcc routine

tbl_fdbcc:
	dc.w	fdbcc_f	-	tbl_fdbcc	* 00
	dc.w	fdbcc_eq	-	tbl_fdbcc	* 01
	dc.w	fdbcc_ogt	-	tbl_fdbcc	* 02
	dc.w	fdbcc_oge	-	tbl_fdbcc	* 03
	dc.w	fdbcc_olt	-	tbl_fdbcc	* 04
	dc.w	fdbcc_ole	-	tbl_fdbcc	* 05
	dc.w	fdbcc_ogl	-	tbl_fdbcc	* 06
	dc.w	fdbcc_or	-	tbl_fdbcc	* 07
	dc.w	fdbcc_un	-	tbl_fdbcc	* 08
	dc.w	fdbcc_ueq	-	tbl_fdbcc	* 09
	dc.w	fdbcc_ugt	-	tbl_fdbcc	* 10
	dc.w	fdbcc_uge	-	tbl_fdbcc	* 11
	dc.w	fdbcc_ult	-	tbl_fdbcc	* 12
	dc.w	fdbcc_ule	-	tbl_fdbcc	* 13
	dc.w	fdbcc_neq	-	tbl_fdbcc	* 14
	dc.w	fdbcc_t	-	tbl_fdbcc	* 15
	dc.w	fdbcc_sf	-	tbl_fdbcc	* 16
	dc.w	fdbcc_seq	-	tbl_fdbcc	* 17
	dc.w	fdbcc_gt	-	tbl_fdbcc	* 18
	dc.w	fdbcc_ge	-	tbl_fdbcc	* 19
	dc.w	fdbcc_lt	-	tbl_fdbcc	* 20
	dc.w	fdbcc_le	-	tbl_fdbcc	* 21
	dc.w	fdbcc_gl	-	tbl_fdbcc	* 22
	dc.w	fdbcc_gle	-	tbl_fdbcc	* 23
	dc.w	fdbcc_ngle	-	tbl_fdbcc	* 24
	dc.w	fdbcc_ngl	-	tbl_fdbcc	* 25
	dc.w	fdbcc_nle	-	tbl_fdbcc	* 26
	dc.w	fdbcc_nlt	-	tbl_fdbcc	* 27
	dc.w	fdbcc_nge	-	tbl_fdbcc	* 28
	dc.w	fdbcc_ngt	-	tbl_fdbcc	* 29
	dc.w	fdbcc_sneq	-	tbl_fdbcc	* 30
	dc.w	fdbcc_st	-	tbl_fdbcc	* 31

**-------------------------------------------------------------------------------------------------
*		
* IEEE Nonaware tests	
*		
* For the IEEE nonaware tests, only the false branch changes the 
* counter. However, the true branch may set bsun so we check to see
* if the NAN bit is set, in which case BSUN and AIOP will be set.
*		
* The cases EQ and NE are shared by the Aware and Nonaware groups
* and are incapable of setting the BSUN exception bit.
*		
* Typically, only one of the two possible branch directions could
* have the NAN bit set.	
* (This is assuming the mutual exclusiveness of FPSR cc bit groupings
*  is preserved.)	
*		
**-------------------------------------------------------------------------------------------------

*
* equal:
*
*	Z
*
fdbcc_eq:
	fbeq.w	fdbcc_eq_yes	* equal?
fdbcc_eq_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_eq_yes:
	rts

*
* not equal:
*	_
*	Z
*
fdbcc_neq:
	fbne.w	fdbcc_neq_yes	* not equal?
fdbcc_neq_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_neq_yes:
	rts

*
* greater than:
*	_______
*	NANvZvN
*
fdbcc_gt:
	fbgt.w	fdbcc_gt_yes	* greater than?
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_false	* no;go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_gt_yes:
	rts		* do nothing

*
* not greater than:
*
*	NANvZvN	
*
fdbcc_ngt:
	fbngt.w	fdbcc_ngt_yes	* not greater than?
fdbcc_ngt_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ngt_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_ngt_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
fdbcc_ngt_done:
	rts		* no; do nothing

*
* greater than or equal:
*	   _____
*	Zv(NANvN)
*
fdbcc_ge:
	fbge.w	fdbcc_ge_yes	* greater than or equal?
fdbcc_ge_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_false	* no;go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ge_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_ge_yes_done	* no;go do nothing
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
fdbcc_ge_yes_done:
	rts		* do nothing

*
* not (greater than or equal):
*	       _
*	NANv(N^Z)
*
fdbcc_nge:
	fbnge.w	fdbcc_nge_yes	* not (greater than or equal)?
fdbcc_nge_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_nge_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_nge_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
fdbcc_nge_done:
	rts		* no; do nothing

*
* less than:
*	   _____
*	N^(NANvZ)
*
fdbcc_lt:
	fblt.w	fdbcc_lt_yes	* less than?
fdbcc_lt_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_false	* no; go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_lt_yes:
	rts		* do nothing

*
* not less than:
*	       _
*	NANv(ZvN)
*
fdbcc_nlt:
	fbnlt.w	fdbcc_nlt_yes	* not less than?
fdbcc_nlt_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_nlt_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_nlt_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
fdbcc_nlt_done:
	rts		* no; do nothing

*
* less than or equal:
*	     ___
*	Zv(N^NAN)
*
fdbcc_le:
	fble.w	fdbcc_le_yes	* less than or equal?
fdbcc_le_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_false	* no; go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_le_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_le_yes_done	* no; go do nothing
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception	
fdbcc_le_yes_done:
	rts		* do nothing

*
* not (less than or equal):
*	     ___
*	NANv(NvZ)
*
fdbcc_nle:
	fbnle.w	fdbcc_nle_yes	* not (less than or equal)?
fdbcc_nle_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_nle_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_nle_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
fdbcc_nle_done:
	rts		* no; do nothing

*
* greater or less than:
*	_____
*	NANvZ
*
fdbcc_gl:
	fbgl.w	fdbcc_gl_yes	* greater or less than?
fdbcc_gl_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fdbcc_false	* no; handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_gl_yes:
	rts		* do nothing

*
* not (greater or less than):
*
*	NANvZ
*
fdbcc_ngl:
	fbngl.w	fdbcc_ngl_yes	* not (greater or less than)?
fdbcc_ngl_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ngl_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	fdbcc_ngl_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
fdbcc_ngl_done:
	rts		* no; do nothing

*
* greater, less, or equal:
*	___
*	NAN
*
fdbcc_gle:
	fbgle.w	fdbcc_gle_yes	* greater, less, or equal?
fdbcc_gle_no:
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_gle_yes:
	rts		* do nothing

*
* not (greater, less, or equal):
*
*	NAN
*
fdbcc_ngle:
	fbngle.w	fdbcc_ngle_yes	* not (greater, less, or equal)?
fdbcc_ngle_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ngle_yes:
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	rts		* no; do nothing

**-------------------------------------------------------------------------------------------------
*		
* Miscellaneous tests	
*		
* For the IEEE miscellaneous tests, all but fdbf and fdbt can set bsun. *
*		
**-------------------------------------------------------------------------------------------------

*
* false:
*
*	False
*
fdbcc_f:		* no bsun possible
	bra.w	fdbcc_false	* go handle counter

*
* true:
*
*	True
*
fdbcc_t:		* no bsun possible
	rts		* do nothing

*
* signalling false:
*
*	False
*
fdbcc_sf:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* is NAN set?
	beq.w	fdbcc_false	* no;go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	bra.w	fdbcc_false	* go handle counter

*
* signalling true:
*
*	True
*
fdbcc_st:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* is NAN set?
	beq.b	fdbcc_st_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
fdbcc_st_done:
	rts

*
* signalling equal:
*
*	Z
*
fdbcc_seq:
	fbseq.w	fdbcc_seq_yes	* signalling equal?
fdbcc_seq_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* is NAN set?
	beq.w	fdbcc_false	* no;go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	bra.w	fdbcc_false	* go handle counter
fdbcc_seq_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* is NAN set?
	beq.b	fdbcc_seq_yes_done	* no;go do nothing
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
fdbcc_seq_yes_done:
	rts		* yes; do nothing

*
* signalling not equal:
*	_
*	Z
*
fdbcc_sneq:
	fbsne.w	fdbcc_sneq_yes	* signalling not equal?
fdbcc_sneq_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* is NAN set?
	beq.w	fdbcc_false	* no;go handle counter
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
	bra.w	fdbcc_false	* go handle counter
fdbcc_sneq_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fdbcc_sneq_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * is BSUN enabled?
	bne.w	fdbcc_bsun	* yes; we have an exception
fdbcc_sneq_done:
	rts

**-------------------------------------------------------------------------------------------------
*		
* IEEE Aware tests	
*		
* For the IEEE aware tests, action is only taken if the result is false.*
* Therefore, the opposite branch type is used to jump to the decrement
* routine. 	
* The BSUN exception will not be set for any of these tests.
*		
**-------------------------------------------------------------------------------------------------

*
* ordered greater than:
*	_______
*	NANvZvN
*
fdbcc_ogt:
	fbogt.w	fdbcc_ogt_yes	* ordered greater than?
fdbcc_ogt_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ogt_yes:
	rts		* yes; do nothing

*
* unordered or less or equal:
*	_______
*	NANvZvN
*
fdbcc_ule:
	fbule.w	fdbcc_ule_yes	* unordered or less or equal?
fdbcc_ule_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ule_yes:
	rts		* yes; do nothing

*
* ordered greater than or equal:
*	   _____
*	Zv(NANvN)
*
fdbcc_oge:
	fboge.w	fdbcc_oge_yes	* ordered greater than or equal?
fdbcc_oge_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_oge_yes:
	rts		* yes; do nothing

*
* unordered or less than:
*	       _
*	NANv(N^Z)
*
fdbcc_ult:
	fbult.w	fdbcc_ult_yes	* unordered or less than?
fdbcc_ult_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ult_yes:
	rts		* yes; do nothing

*
* ordered less than:
*	   _____
*	N^(NANvZ)
*
fdbcc_olt:
	fbolt.w	fdbcc_olt_yes	* ordered less than?
fdbcc_olt_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_olt_yes:
	rts		* yes; do nothing

*
* unordered or greater or equal:
*
*	NANvZvN
*
fdbcc_uge:
	fbuge.w	fdbcc_uge_yes	* unordered or greater than?
fdbcc_uge_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_uge_yes:
	rts		* yes; do nothing

*
* ordered less than or equal:
*	     ___
*	Zv(N^NAN)
*
fdbcc_ole:
	fbole.w	fdbcc_ole_yes	* ordered greater or less than?
fdbcc_ole_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ole_yes:
	rts		* yes; do nothing

*
* unordered or greater than:
*	     ___
*	NANv(NvZ)
*
fdbcc_ugt:
	fbugt.w	fdbcc_ugt_yes	* unordered or greater than?
fdbcc_ugt_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ugt_yes:
	rts		* yes; do nothing

*
* ordered greater or less than:
*	_____
*	NANvZ
*
fdbcc_ogl:
	fbogl.w	fdbcc_ogl_yes	* ordered greater or less than?
fdbcc_ogl_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ogl_yes:
	rts		* yes; do nothing

*
* unordered or equal:
*
*	NANvZ
*
fdbcc_ueq:
	fbueq.w	fdbcc_ueq_yes	* unordered or equal?
fdbcc_ueq_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_ueq_yes:
	rts		* yes; do nothing

*
* ordered:
*	___
*	NAN
*
fdbcc_or:
	fbor.w	fdbcc_or_yes	* ordered?
fdbcc_or_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_or_yes:
	rts		* yes; do nothing

*
* unordered:
*
*	NAN
*
fdbcc_un:
	fbun.w	fdbcc_un_yes	* unordered?
fdbcc_un_no:
	bra.w	fdbcc_false	* no; go handle counter
fdbcc_un_yes:
	rts		* yes; do nothing

*********

*
* the bsun exception bit was not set.
*
* (1) subtract 1 from the count register
* (2) if (cr == -1) then
*	pc = pc of next instruction
*     else
*	pc += sign_ext(16-bit displacement)
*
fdbcc_false:
	move.b	1+EXC_LV+EXC_OPWORD(a6), d1	* fetch lo opword 
	andi.w	#$7, d1	* extract count register

	bsr.l	fetch_dreg	* fetch count value
* make sure that d0 isn't corrupted between calls...

	subq.w	#$1, d0	* Dn - 1 -> Dn

	bsr.l	store_dreg_l	* store new count value

	ICMP.w	d0, #-$1	* is (Dn == -1)?
	bne.b	fdbcc_false_cont	* no; 
	rts

fdbcc_false_cont:
	move.l	EXC_LV+L_SCR1(a6),d0	* fetch displacement
	add.l	EXC_LV+USER_FPIAR(a6),d0	* add instruction PC
	addq.l	#$4,d0	* add instruction length
	move.l	d0,EXC_LV+EXC_PC(a6)	* set new PC
	rts

* the emulation routine set bsun and BSUN was enabled. have to
* fix stack and jump to the bsun handler.
* let the caller of this routine shift the stack frame up to
* eliminate the effective address field.
fdbcc_bsun:
	move.b	#fbsun_flg,EXC_LV+SPCOND_FLG(a6)
	rts
















**-------------------------------------------------------------------------------------------------
* ftrapcc(): routine to emulate the ftrapcc instruction
*		
* XDEF **
*	_ftrapcc()	
*		
* xdef **
*	none	
*		
* INPUT *************************************************************** *
*	none	
*		
* OUTPUT ************************************************************** *
*	none	
*		
* ALGORITHM *********************************************************** *
*	This routine checks which conditional predicate is specified by
* the stacked ftrapcc instruction opcode and then branches to a routine
* for that predicate. The corresponding fbcc instruction is then used
* to see whether the condition (specified by the stacked FPSR) is true
* or false.	
*	If a BSUN exception should be indicated, the BSUN and ABSUN
* bits are set in the stacked FPSR. If the BSUN exception is enabled,
* the fbsun_flg is set in the EXC_LV+SPCOND_FLG location on the stack. If an 
* enabled BSUN should not be flagged and the predicate is true, then
* the ftrapcc_flg is set in the EXC_LV+SPCOND_FLG location. These special
* flags indicate to the calling routine to emulate the exceptional
* condition.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_ftrapcc
_ftrapcc:
	move.w	EXC_LV+EXC_CMDREG(a6),d0	* fetch predicate

	clr.l	d1	* clear scratch reg
	move.b	EXC_LV+FPSR_CC(a6),d1	* fetch fp ccodes
	ror.l	#$8,d1	* rotate to top byte
	fmove.l	d1,fpsr	* insert into FPSR

	move.w	((tbl_ftrapcc).b,pc,d0.w*2), d1 * load table
	jmp	((tbl_ftrapcc).b,pc,d1.w) * jump to ftrapcc routine

tbl_ftrapcc:
	dc.w	ftrapcc_f	-	tbl_ftrapcc	* 00
	dc.w	ftrapcc_eq	-	tbl_ftrapcc	* 01
	dc.w	ftrapcc_ogt	-	tbl_ftrapcc	* 02
	dc.w	ftrapcc_oge	-	tbl_ftrapcc	* 03
	dc.w	ftrapcc_olt	-	tbl_ftrapcc	* 04
	dc.w	ftrapcc_ole	-	tbl_ftrapcc	* 05
	dc.w	ftrapcc_ogl	-	tbl_ftrapcc	* 06
	dc.w	ftrapcc_or	-	tbl_ftrapcc	* 07
	dc.w	ftrapcc_un	-	tbl_ftrapcc	* 08
	dc.w	ftrapcc_ueq	-	tbl_ftrapcc	* 09
	dc.w	ftrapcc_ugt	-	tbl_ftrapcc	* 10
	dc.w	ftrapcc_uge	-	tbl_ftrapcc	* 11
	dc.w	ftrapcc_ult	-	tbl_ftrapcc	* 12
	dc.w	ftrapcc_ule	-	tbl_ftrapcc	* 13
	dc.w	ftrapcc_neq	-	tbl_ftrapcc	* 14
	dc.w	ftrapcc_t	-	tbl_ftrapcc	* 15
	dc.w	ftrapcc_sf	-	tbl_ftrapcc	* 16
	dc.w	ftrapcc_seq	-	tbl_ftrapcc	* 17
	dc.w	ftrapcc_gt	-	tbl_ftrapcc	* 18
	dc.w	ftrapcc_ge	-	tbl_ftrapcc	* 19
	dc.w	ftrapcc_lt	-	tbl_ftrapcc	* 20
	dc.w	ftrapcc_le	-	tbl_ftrapcc	* 21
	dc.w	ftrapcc_gl	-	tbl_ftrapcc	* 22
	dc.w	ftrapcc_gle	-	tbl_ftrapcc	* 23
	dc.w	ftrapcc_ngle	-	tbl_ftrapcc	* 24
	dc.w	ftrapcc_ngl	-	tbl_ftrapcc	* 25
	dc.w	ftrapcc_nle	-	tbl_ftrapcc	* 26
	dc.w	ftrapcc_nlt	-	tbl_ftrapcc	* 27
	dc.w	ftrapcc_nge	-	tbl_ftrapcc	* 28
	dc.w	ftrapcc_ngt	-	tbl_ftrapcc	* 29
	dc.w	ftrapcc_sneq	-	tbl_ftrapcc	* 30
	dc.w	ftrapcc_st	-	tbl_ftrapcc	* 31

**-------------------------------------------------------------------------------------------------
*		
* IEEE Nonaware tests	
*		
* For the IEEE nonaware tests, we set the result based on the
* floating point condition codes. In addition, we check to see
* if the NAN bit is set, in which case BSUN and AIOP will be set.
*		
* The cases EQ and NE are shared by the Aware and Nonaware groups
* and are incapable of setting the BSUN exception bit.
*		
* Typically, only one of the two possible branch directions could
* have the NAN bit set.	
*		
**-------------------------------------------------------------------------------------------------

*
* equal:
*
*	Z
*
ftrapcc_eq:
	fbeq.w	ftrapcc_trap	* equal?
ftrapcc_eq_no:
	rts		* do nothing

*
* not equal:
*	_
*	Z
*
ftrapcc_neq:
	fbne.w	ftrapcc_trap	* not equal?
ftrapcc_neq_no:
	rts		* do nothing

*
* greater than:
*	_______
*	NANvZvN
*
ftrapcc_gt:
	fbgt.w	ftrapcc_trap	* greater than?
ftrapcc_gt_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	ftrapcc_gt_done	* no
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_gt_done:
	rts		* no; do nothing

*
* not greater than:
*
*	NANvZvN	
*
ftrapcc_ngt:
	fbngt.w	ftrapcc_ngt_yes	* not greater than?
ftrapcc_ngt_no:
	rts		* do nothing
ftrapcc_ngt_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* greater than or equal:
*	   _____
*	Zv(NANvN)
*
ftrapcc_ge:
	fbge.w	ftrapcc_ge_yes	* greater than or equal?
ftrapcc_ge_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	ftrapcc_ge_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_ge_done:
	rts		* no; do nothing
ftrapcc_ge_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* not (greater than or equal):
*	       _
*	NANv(N^Z)
*
ftrapcc_nge:
	fbnge.w	ftrapcc_nge_yes	* not (greater than or equal)?
ftrapcc_nge_no:
	rts		* do nothing
ftrapcc_nge_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* less than:
*	   _____
*	N^(NANvZ)
*
ftrapcc_lt:
	fblt.w	ftrapcc_trap	* less than?
ftrapcc_lt_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	ftrapcc_lt_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_lt_done:
	rts		* no; do nothing

*
* not less than:
*	       _
*	NANv(ZvN)
*
ftrapcc_nlt:
	fbnlt.w	ftrapcc_nlt_yes	* not less than?
ftrapcc_nlt_no:
	rts		* do nothing
ftrapcc_nlt_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* less than or equal:
*	     ___
*	Zv(N^NAN)
*
ftrapcc_le:
	fble.w	ftrapcc_le_yes	* less than or equal?
ftrapcc_le_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	ftrapcc_le_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_le_done:
	rts		* no; do nothing
ftrapcc_le_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* not (less than or equal):
*	     ___
*	NANv(NvZ)
*
ftrapcc_nle:
	fbnle.w	ftrapcc_nle_yes	* not (less than or equal)?
ftrapcc_nle_no:
	rts		* do nothing
ftrapcc_nle_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* greater or less than:
*	_____
*	NANvZ
*
ftrapcc_gl:
	fbgl.w	ftrapcc_trap	* greater or less than?
ftrapcc_gl_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.b	ftrapcc_gl_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_gl_done:
	rts		* no; do nothing

*
* not (greater or less than):
*
*	NANvZ
*
ftrapcc_ngl:
	fbngl.w	ftrapcc_ngl_yes	* not (greater or less than)?
ftrapcc_ngl_no:
	rts		* do nothing
ftrapcc_ngl_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* greater, less, or equal:
*	___
*	NAN
*
ftrapcc_gle:
	fbgle.w	ftrapcc_trap	* greater, less, or equal?
ftrapcc_gle_no:
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	rts		* no; do nothing

*
* not (greater, less, or equal):
*
*	NAN
*
ftrapcc_ngle:
	fbngle.w	ftrapcc_ngle_yes	* not (greater, less, or equal)?
ftrapcc_ngle_no:
	rts		* do nothing
ftrapcc_ngle_yes:
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

**-------------------------------------------------------------------------------------------------
*		
* Miscellaneous tests	
*		
* For the IEEE aware tests, we only have to set the result based on the
* floating point condition codes. The BSUN exception will not be
* set for any of these tests.	
*		
**-------------------------------------------------------------------------------------------------

*
* false:
*
*	False
*
ftrapcc_f:
	rts		* do nothing

*
* true:
*
*	True
*
ftrapcc_t:
	bra.w	ftrapcc_trap	* go take trap

*
* signalling false:
*
*	False
*
ftrapcc_sf:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.b	ftrapcc_sf_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_sf_done:
	rts		* no; do nothing

*
* signalling true:
*
*	True
*
ftrapcc_st:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* signalling equal:
*
*	Z
*
ftrapcc_seq:
	fbseq.w	ftrapcc_seq_yes	* signalling equal?
ftrapcc_seq_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	ftrapcc_seq_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_seq_done:
	rts		* no; do nothing
ftrapcc_seq_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

*
* signalling not equal:
*	_
*	Z
*
ftrapcc_sneq:
	fbsne.w	ftrapcc_sneq_yes	* signalling equal?
ftrapcc_sneq_no:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	ftrapcc_sneq_no_done	* no; go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
ftrapcc_sneq_no_done:
	rts		* do nothing
ftrapcc_sneq_yes:
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	ftrapcc_trap	* no; go take trap
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	btst	#bsun_bit, EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	ftrapcc_bsun	* yes
	bra.w	ftrapcc_trap	* no; go take trap

**-------------------------------------------------------------------------------------------------
*		
* IEEE Aware tests	
*		
* For the IEEE aware tests, we only have to set the result based on the
* floating point condition codes. The BSUN exception will not be
* set for any of these tests.	
*		
**-------------------------------------------------------------------------------------------------

*
* ordered greater than:
*	_______
*	NANvZvN
*
ftrapcc_ogt:
	fbogt.w	ftrapcc_trap	* ordered greater than?
ftrapcc_ogt_no:
	rts		* do nothing

*
* unordered or less or equal:
*	_______
*	NANvZvN
*
ftrapcc_ule:
	fbule.w	ftrapcc_trap	* unordered or less or equal?
ftrapcc_ule_no:
	rts		* do nothing

*
* ordered greater than or equal:
*	   _____
*	Zv(NANvN)
*
ftrapcc_oge:
	fboge.w	ftrapcc_trap	* ordered greater than or equal?
ftrapcc_oge_no:
	rts		* do nothing

*
* unordered or less than:
*	       _
*	NANv(N^Z)
*
ftrapcc_ult:
	fbult.w	ftrapcc_trap	* unordered or less than?
ftrapcc_ult_no:
	rts		* do nothing

*
* ordered less than:
*	   _____
*	N^(NANvZ)
*
ftrapcc_olt:
	fbolt.w	ftrapcc_trap	* ordered less than?
ftrapcc_olt_no:
	rts		* do nothing

*
* unordered or greater or equal:
*
*	NANvZvN
*
ftrapcc_uge:
	fbuge.w	ftrapcc_trap	* unordered or greater than?
ftrapcc_uge_no:
	rts		* do nothing

*
* ordered less than or equal:
*	     ___
*	Zv(N^NAN)
*
ftrapcc_ole:
	fbole.w	ftrapcc_trap	* ordered greater or less than?
ftrapcc_ole_no:
	rts		* do nothing

*
* unordered or greater than:
*	     ___
*	NANv(NvZ)
*
ftrapcc_ugt:
	fbugt.w	ftrapcc_trap	* unordered or greater than?
ftrapcc_ugt_no:
	rts		* do nothing

*
* ordered greater or less than:
*	_____
*	NANvZ
*
ftrapcc_ogl:
	fbogl.w	ftrapcc_trap	* ordered greater or less than?
ftrapcc_ogl_no:
	rts		* do nothing

*
* unordered or equal:
*
*	NANvZ
*
ftrapcc_ueq:
	fbueq.w	ftrapcc_trap	* unordered or equal?
ftrapcc_ueq_no:
	rts		* do nothing

*
* ordered:
*	___
*	NAN
*
ftrapcc_or:
	fbor.w	ftrapcc_trap	* ordered?
ftrapcc_or_no:
	rts		* do nothing

*
* unordered:
*
*	NAN
*
ftrapcc_un:
	fbun.w	ftrapcc_trap	* unordered?
ftrapcc_un_no:
	rts		* do nothing

*********

* the bsun exception bit was not set.
* we will need to jump to the ftrapcc vector. the stack frame
* is the same size as that of the fp unimp instruction. the
* only difference is that the <ea> field should hold the PC
* of the ftrapcc instruction and the vector offset field
* should denote the ftrapcc trap.
ftrapcc_trap:
	move.b	#ftrapcc_flg,EXC_LV+SPCOND_FLG(a6)
	rts

* the emulation routine set bsun and BSUN was enabled. have to
* fix stack and jump to the bsun handler.
* let the caller of this routine shift the stack frame up to
* eliminate the effective address field.
ftrapcc_bsun:
	move.b	#fbsun_flg,EXC_LV+SPCOND_FLG(a6)
	rts

**-------------------------------------------------------------------------------------------------
* fscc(): routine to emulate the fscc instruction
*		
* XDEF ** *
*	_fscc()	
*		
* xdef ** *
*	store_dreg_b() - store result to data register file
*	dec_areg() - decrement an areg for -(an) mode
*	inc_areg() - increment an areg for (an)+ mode
*	_dmem_write_byte() - store result to memory
*		
* INPUT ***************************************************************
*	none	
*		
* OUTPUT ************************************************************** *
*	none	
*		
* ALGORITHM ***********************************************************
*	This routine checks which conditional predicate is specified by
* the stacked fscc instruction opcode and then branches to a routine
* for that predicate. The corresponding fbcc instruction is then used
* to see whether the condition (specified by the stacked FPSR) is true
* or false.	
*	If a BSUN exception should be indicated, the BSUN and ABSUN
* bits are set in the stacked FPSR. If the BSUN exception is enabled,
* the fbsun_flg is set in the EXC_LV+SPCOND_FLG location on the stack. If an 
* enabled BSUN should not be flagged and the predicate is true, then
* the result is stored to the data register file or memory
*		
**-------------------------------------------------------------------------------------------------

	xdef	_fscc
_fscc:
	move.w	EXC_LV+EXC_CMDREG(a6),d0	* fetch predicate

	clr.l	d1	* clear scratch reg
	move.b	EXC_LV+FPSR_CC(a6),d1	* fetch fp ccodes
	ror.l	#$8,d1	* rotate to top byte
	fmove.l	d1,fpsr	* insert into FPSR

	move.w	((tbl_fscc).b,pc,d0.w*2),d1 * load table
	jmp	((tbl_fscc).b,pc,d1.w) 	* jump to fscc routine

tbl_fscc:
	dc.w	fscc_f	-	tbl_fscc	* 00
	dc.w	fscc_eq	-	tbl_fscc	* 01
	dc.w	fscc_ogt	-	tbl_fscc	* 02
	dc.w	fscc_oge	-	tbl_fscc	* 03
	dc.w	fscc_olt	-	tbl_fscc	* 04
	dc.w	fscc_ole	-	tbl_fscc	* 05
	dc.w	fscc_ogl	-	tbl_fscc	* 06
	dc.w	fscc_or	-	tbl_fscc	* 07
	dc.w	fscc_un	-	tbl_fscc	* 08
	dc.w	fscc_ueq	-	tbl_fscc	* 09
	dc.w	fscc_ugt	-	tbl_fscc	* 10
	dc.w	fscc_uge	-	tbl_fscc	* 11
	dc.w	fscc_ult	-	tbl_fscc	* 12
	dc.w	fscc_ule	-	tbl_fscc	* 13
	dc.w	fscc_neq	-	tbl_fscc	* 14
	dc.w	fscc_t	-	tbl_fscc	* 15
	dc.w	fscc_sf	-	tbl_fscc	* 16
	dc.w	fscc_seq	-	tbl_fscc	* 17
	dc.w	fscc_gt	-	tbl_fscc	* 18
	dc.w	fscc_ge	-	tbl_fscc	* 19
	dc.w	fscc_lt	-	tbl_fscc	* 20
	dc.w	fscc_le	-	tbl_fscc	* 21
	dc.w	fscc_gl	-	tbl_fscc	* 22
	dc.w	fscc_gle	-	tbl_fscc	* 23
	dc.w	fscc_ngle	-	tbl_fscc	* 24
	dc.w	fscc_ngl	-	tbl_fscc	* 25
	dc.w	fscc_nle	-	tbl_fscc	* 26
	dc.w	fscc_nlt	-	tbl_fscc	* 27
	dc.w	fscc_nge	-	tbl_fscc	* 28
	dc.w	fscc_ngt	-	tbl_fscc	* 29
	dc.w	fscc_sneq	-	tbl_fscc	* 30
	dc.w	fscc_st	-	tbl_fscc	* 31

**-------------------------------------------------------------------------------------------------
*		
* IEEE Nonaware tests	
*		
* For the IEEE nonaware tests, we set the result based on the
* floating point condition codes. In addition, we check to see
* if the NAN bit is set, in which case BSUN and AIOP will be set.
*		
* The cases EQ and NE are shared by the Aware and Nonaware groups
* and are incapable of setting the BSUN exception bit.
*		
* Typically, only one of the two possible branch directions could
* have the NAN bit set.	
*		
**-------------------------------------------------------------------------------------------------

*
* equal:
*
*	Z
*
fscc_eq:
	fbeq.w	fscc_eq_yes	* equal?
fscc_eq_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_eq_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* not equal:
*	_
*	Z
*
fscc_neq:
	fbne.w	fscc_neq_yes	* not equal?
fscc_neq_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_neq_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* greater than:
*	_______
*	NANvZvN
*
fscc_gt:
	fbgt.w	fscc_gt_yes	* greater than?
fscc_gt_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_gt_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* not greater than:
*
*	NANvZvN	
*
fscc_ngt:
	fbngt.w	fscc_ngt_yes	* not greater than?
fscc_ngt_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ngt_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* greater than or equal:
*	   _____
*	Zv(NANvN)
*
fscc_ge:
	fbge.w	fscc_ge_yes	* greater than or equal?
fscc_ge_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_ge_yes:
	st	d0	* set true	
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* not (greater than or equal):
*	       _
*	NANv(N^Z)
*
fscc_nge:
	fbnge.w	fscc_nge_yes	* not (greater than or equal)?
fscc_nge_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_nge_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* less than:
*	   _____
*	N^(NANvZ)
*
fscc_lt:
	fblt.w	fscc_lt_yes	* less than?
fscc_lt_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_lt_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* not less than:
*	       _
*	NANv(ZvN)
*
fscc_nlt:
	fbnlt.w	fscc_nlt_yes	* not less than?
fscc_nlt_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_nlt_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* less than or equal:
*	     ___
*	Zv(N^NAN)
*
fscc_le:
	fble.w	fscc_le_yes	* less than or equal?
fscc_le_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_le_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* not (less than or equal):
*	     ___
*	NANv(NvZ)
*
fscc_nle:
	fbnle.w	fscc_nle_yes	* not (less than or equal)?
fscc_nle_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_nle_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* greater or less than:
*	_____
*	NANvZ
*
fscc_gl:
	fbgl.w	fscc_gl_yes	* greater or less than?
fscc_gl_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_gl_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* not (greater or less than):
*
*	NANvZ
*
fscc_ngl:
	fbngl.w	fscc_ngl_yes	* not (greater or less than)?
fscc_ngl_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ngl_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6)	* is NAN set in cc?
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* greater, less, or equal:
*	___
*	NAN
*
fscc_gle:
	fbgle.w	fscc_gle_yes	* greater, less, or equal?
fscc_gle_no:
	clr.b	d0	* set false
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_gle_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* not (greater, less, or equal):
*
*	NAN
*
fscc_ngle:
	fbngle.w	fscc_ngle_yes	* not (greater, less, or equal)?
fscc_ngle_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ngle_yes:
	st	d0	* set true
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

**-------------------------------------------------------------------------------------------------
*		
* Miscellaneous tests	
*		
* For the IEEE aware tests, we only have to set the result based on the
* floating point condition codes. The BSUN exception will not be
* set for any of these tests.	
*		
**-------------------------------------------------------------------------------------------------

*
* false:
*
*	False
*
fscc_f:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish

*
* true:
*
*	True
*
fscc_t:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* signalling false:
*
*	False
*
fscc_sf:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* signalling true:
*
*	True
*
fscc_st:
	st	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* signalling equal:
*
*	Z
*
fscc_seq:
	fbseq.w	fscc_seq_yes	* signalling equal?
fscc_seq_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_seq_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

*
* signalling not equal:
*	_
*	Z
*
fscc_sneq:
	fbsne.w	fscc_sneq_yes	* signalling equal?
fscc_sneq_no:
	clr.b	d0	* set false
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish
fscc_sneq_yes:
	st	d0	* set true
	btst	#nan_bit, EXC_LV+FPSR_CC(a6) 	* set BSUN exc bit
	beq.w	fscc_done	* no;go finish
	ori.l	#bsun_mask+aiop_mask, EXC_LV+USER_FPSR(a6) * set BSUN exc bit
	bra.w	fscc_chk_bsun	* go finish

**-------------------------------------------------------------------------------------------------
*		
* IEEE Aware tests	
*		
* For the IEEE aware tests, we only have to set the result based on the
* floating point condition codes. The BSUN exception will not be
* set for any of these tests.	
*		
**-------------------------------------------------------------------------------------------------

*
* ordered greater than:
*	_______
*	NANvZvN
*
fscc_ogt:
	fbogt.w	fscc_ogt_yes	* ordered greater than?
fscc_ogt_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ogt_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered or less or equal:
*	_______
*	NANvZvN
*
fscc_ule:
	fbule.w	fscc_ule_yes	* unordered or less or equal?
fscc_ule_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ule_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* ordered greater than or equal:
*	   _____
*	Zv(NANvN)
*
fscc_oge:
	fboge.w	fscc_oge_yes	* ordered greater than or equal?
fscc_oge_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_oge_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered or less than:
*	       _
*	NANv(N^Z)
*
fscc_ult:
	fbult.w	fscc_ult_yes	* unordered or less than?
fscc_ult_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ult_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* ordered less than:
*	   _____
*	N^(NANvZ)
*
fscc_olt:
	fbolt.w	fscc_olt_yes	* ordered less than?
fscc_olt_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_olt_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered or greater or equal:
*
*	NANvZvN
*
fscc_uge:
	fbuge.w	fscc_uge_yes	* unordered or greater than?
fscc_uge_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_uge_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* ordered less than or equal:
*	     ___
*	Zv(N^NAN)
*
fscc_ole:
	fbole.w	fscc_ole_yes	* ordered greater or less than?
fscc_ole_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ole_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered or greater than:
*	     ___
*	NANv(NvZ)
*
fscc_ugt:
	fbugt.w	fscc_ugt_yes	* unordered or greater than?
fscc_ugt_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ugt_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* ordered greater or less than:
*	_____
*	NANvZ
*
fscc_ogl:
	fbogl.w	fscc_ogl_yes	* ordered greater or less than?
fscc_ogl_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ogl_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered or equal:
*
*	NANvZ
*
fscc_ueq:
	fbueq.w	fscc_ueq_yes	* unordered or equal?
fscc_ueq_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_ueq_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* ordered:
*	___
*	NAN
*
fscc_or:
	fbor.w	fscc_or_yes	* ordered?
fscc_or_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_or_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*
* unordered:
*
*	NAN
*
fscc_un:
	fbun.w	fscc_un_yes	* unordered?
fscc_un_no:
	clr.b	d0	* set false
	bra.w	fscc_done	* go finish
fscc_un_yes:
	st	d0	* set true
	bra.w	fscc_done	* go finish

*********

*
* the bsun exception bit was set. now, check to see is BSUN 
* is enabled. if so, don't store result and correct stack frame
* for a bsun exception.
*
fscc_chk_bsun:
	btst	#bsun_bit,EXC_LV+FPCR_ENABLE(a6) * was BSUN set?
	bne.w	fscc_bsun

*
* the bsun exception bit was not set.
* the result has been selected.
* now, check to see if the result is to be stored in the data register
* file or in memory.
*
fscc_done:
	move.l	d0,a0	* save result for a moment

	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* fetch lo opword 
	move.l	d1,d0	* make a copy
	andi.b	#$38,d1	* extract src mode

	bne.b	fscc_mem_op	* it's a memory operation

	move.l	d0,d1
	andi.w	#$7,d1	* pass index in d1
	move.l	a0,d0	* pass result in d0
	bsr.l	store_dreg_b	* save result in regfile
	rts

*
* the stacked <ea> is correct with the exception of:
* 	-> Dn : <ea> is garbage
*
* if the addressing mode is post-increment or pre-decrement,
* then the address registers have not been updated.
*
fscc_mem_op:
	ICMP.b	d1,#$18	* is <ea> (An)+ ?
	beq.b	fscc_mem_inc	* yes
	ICMP.b	d1,#$20	* is <ea> -(An) ?
	beq.b	fscc_mem_dec	* yes

	move.l	a0,d0	* pass result in d0
	move.l	EXC_LV+EXC_EA(a6),a0	* fetch <ea>
	bsr.l	_dmem_write_byte	* write result byte

	tst.l	d1	* did dstore fail?
	bne.w	fscc_err	* yes

	rts

* addresing mode is post-increment. write the result byte. if the write
* fails then don't update the address register. if write passes then
* call inc_areg() to update the address register.
fscc_mem_inc:
	move.l	a0,d0	* pass result in d0
	move.l	EXC_LV+EXC_EA(a6),a0	* fetch <ea>
	bsr.l	_dmem_write_byte	* write result byte

	tst.l	d1	* did dstore fail?
	bne.w	fscc_err	* yes

	move.b	$1+EXC_LV+EXC_OPWORD(a6),d1	* fetch opword
	andi.w	#$7,d1	* pass index in d1
	moveq.l	#$1,d0	* pass amt to inc by
	bsr.l	inc_areg	* increment address register

	rts

* addressing mode is pre-decrement. write the result byte. if the write
* fails then don't update the address register. if the write passes then
* call dec_areg() to update the address register.
fscc_mem_dec:
	move.l	a0,d0	* pass result in d0
	move.l	EXC_LV+EXC_EA(a6),a0	* fetch <ea>
	bsr.l	_dmem_write_byte	* write result byte

	tst.l	d1	* did dstore fail?
	bne.w	fscc_err	* yes

	move.b	$1+EXC_LV+EXC_OPWORD(a6),d1	* fetch opword
	andi.w	#$7,d1	* pass index in d1
	moveq.l	#$1,d0	* pass amt to dec by
	bsr.l	dec_areg	* decrement address register

	rts

* the emulation routine set bsun and BSUN was enabled. have to
* fix stack and jump to the bsun handler.
* let the caller of this routine shift the stack frame up to
* eliminate the effective address field.
fscc_bsun:
	move.b	#fbsun_flg,EXC_LV+SPCOND_FLG(a6)
	rts

* the byte write to memory has failed. pass the failing effective address
* and a FSLW to funimp_dacc().
fscc_err:
	move.w	#$00a1,EXC_LV+EXC_VOFF(a6)
	bra.l	facc_finish

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fmovm_dynamic(): emulate "fmovm" dynamic instruction
*		
* xdef **
*	fetch_dreg() - fetch data register
*	{i,d,}mem_read() - fetch data from memory
*	_mem_write() - write data to memory
*	iea_iacc() - instruction memory access error occurred
*	iea_dacc() - data memory access error occurred
*	restore() - restore An index regs if access error occurred
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	If instr is "fmovm Dn,-(A7)" from supervisor mode,
*	d0 = size of dump	
*	d1 = Dn	
*	Else if instruction access error,
*	d0 = FSLW	
*	Else if data access error,	
*	d0 = FSLW	
*	a0 = address of fault	
*	Else	
*	none.	
*		
* ALGORITHM ***********************************************************
*	The effective address must be calculated since this is entered
* from an "Unimplemented Effective Address" exception handler. So, we
* have our own fcalc_ea() routine here. If an access error is flagged
* by a _{i,d,}mem_read() call, we must exit through the special
* handler.	
*	The data register is determined and its value loaded to get the
* string of FP registers affected. This value is used as an index into
* a lookup table such that we can determine the number of bytes
* involved. 	
*	If the instruction is "fmovem.x <ea>,Dn", a _mem_read() is used
* to read in all FP values. Again, _mem_read() may fail and require a
* special exit. 	
*	If the instruction is "fmovem.x DN,<ea>", a _mem_write() is used
* to write all FP values. _mem_write() may also fail.
* 	If the instruction is "fmovem.x DN,-(a7)" from supervisor mode,
* then we return the size of the dump and the string to the caller
* so that the move can occur outside of this routine. This special
* case is required so that moves to the system stack are handled
* correctly.	
*		
* DYNAMIC:	
* 	fmovem.x	dn, <ea>	
* 	fmovem.x	<ea>, dn	
*		
*	      <WORD 1>	      <WORD2>
*	1111 0010 00 |<ea>|	11@@# 1000 0$$$ 0000
*		  
*	# = (0): predecrement addressing mode
*	    (1): postincrement or control addressing mode
*	@@ = (0): move listed regs from memory to the FPU
*	    (1): move listed regs from the FPU to memory
*	$$$    : index of data register holding reg select mask
*		
* NOTES:	
*	If the data register holds a zero, then the
*	instruction is a nop.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fmovm_dynamic
fmovm_dynamic:

* extract the data register in which the bit string resides...
	move.b	1+EXC_LV+EXC_EXTWORD(a6),d1	* fetch extword
	andi.w	#$70,d1	* extract reg bits
	lsr.b	#$4,d1	* shift into lo bits

* fetch the bit string into d0...
	bsr.l	fetch_dreg	* fetch reg string

	andi.l	#$000000ff,d0	* keep only lo byte

	move.l	d0,-(sp)	* save strg
	move.b	(tbl_fmovm_size.w,pc,d0),d0
	move.l	d0,-(sp)	* save size
	bsr.l	fmovm_calc_ea	* calculate <ea>
	move.l	(sp)+,d0	* restore size
	move.l	(sp)+,d1	* restore strg

* if the bit string is a zero, then the operation is a no-op
* but, make sure that we've calculated ea and advanced the opword pointer
	beq.w	fmovm_data_done

* separate move ins from move outs...
	btst	#$5,EXC_LV+EXC_EXTWORD(a6)	* is it a move in or out?
	beq.w	fmovm_data_in	* it's a move out

*************
* MOVE OUT: *
*************
fmovm_data_out:
	btst	#$4,EXC_LV+EXC_EXTWORD(a6)	* control or predecrement?
	bne.w	fmovm_out_ctrl	* control

****************************
fmovm_out_predec:
* for predecrement mode, the bit string is the opposite of both control
* operations and postincrement mode. (bit7 = FP7 ... bit0 = FP0)
* here, we convert it to be just like the others...
	move.b	(tbl_fmovm_convert.w,pc,d1.w*1),d1

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor mode?
	beq.b	fmovm_out_ctrl	* user

fmovm_out_predec_s:
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg * is <ea> mode -(a7)?
	bne.b	fmovm_out_ctrl

* the operation was unfortunately an: fmovem.x dn,-(sp)
* called from supervisor mode.
* we're also passing "size" and "strg" back to the calling routine
	rts

****************************
fmovm_out_ctrl:
	move.l	a0,a1	* move <ea> to a1

	sub.l	d0,sp	* subtract size of dump
	lea	(sp),a0

	tst.b	d1	* should FP0 be moved?
	bpl.b	fmovm_out_ctrl_fp1	* no

	move.l	$0+EXC_LV+EXC_FP0(a6),(a0)+	* yes
	move.l	$4+EXC_LV+EXC_FP0(a6),(a0)+
	move.l	$8+EXC_LV+EXC_FP0(a6),(a0)+

fmovm_out_ctrl_fp1:
	lsl.b	#$1,d1	* should FP1 be moved?
	bpl.b	fmovm_out_ctrl_fp2	* no

	move.l	$0+EXC_LV+EXC_FP1(a6),(a0)+	* yes
	move.l	$4+EXC_LV+EXC_FP1(a6),(a0)+
	move.l	$8+EXC_LV+EXC_FP1(a6),(a0)+

fmovm_out_ctrl_fp2:
	lsl.b	#$1,d1	* should FP2 be moved?
	bpl.b	fmovm_out_ctrl_fp3	* no

	fmovem.x	fp2,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_fp3:
	lsl.b	#$1,d1	* should FP3 be moved?
	bpl.b	fmovm_out_ctrl_fp4	* no

	fmovem.x	fp3,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_fp4:
	lsl.b	#$1,d1	* should FP4 be moved?
	bpl.b	fmovm_out_ctrl_fp5	* no

	fmovem.x	fp4,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_fp5:
	lsl.b	#$1,d1	* should FP5 be moved?
	bpl.b	fmovm_out_ctrl_fp6	* no

	fmovem.x	fp5,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_fp6:
	lsl.b	#$1,d1	* should FP6 be moved?
	bpl.b	fmovm_out_ctrl_fp7	* no

	fmovem.x	fp6,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_fp7:
	lsl.b	#$1,d1	* should FP7 be moved?
	bpl.b	fmovm_out_ctrl_done	* no

	fmovem.x	fp7,(a0)	* yes
	add.l	#$c,a0

fmovm_out_ctrl_done:
	move.l	a1,EXC_LV+L_SCR1(a6)

	lea	(sp),a0	* pass: supervisor src
	move.l	d0,-(sp)	* save size
	bsr.l	_dmem_write	* copy data to user mem

	move.l	(sp)+,d0
	add.l	d0,sp	* clear fpreg data from stack

	tst.l	d1	* did dstore err?
	bne.w	fmovm_out_err	* yes

	rts

************
* MOVE IN: *
************
fmovm_data_in:
	move.l	a0,EXC_LV+L_SCR1(a6)

	sub.l	d0,sp	* make room for fpregs
	lea	(sp),a1

	move.l	d1,-(sp)	* save bit string for later
	move.l	d0,-(sp)	* save * of bytes

	bsr.l	_dmem_read	* copy data from user mem

	move.l	(sp)+,d0	* retrieve * of bytes

	tst.l	d1	* did dfetch fail?
	bne.w	fmovm_in_err	* yes

	move.l	(sp)+,d1	* load bit string

	lea	(sp),a0	* addr of stack

	tst.b	d1	* should FP0 be moved?
	bpl.b	fmovm_data_in_fp1	* no

	move.l	(a0)+,$0+EXC_LV+EXC_FP0(a6)	* yes
	move.l	(a0)+,$4+EXC_LV+EXC_FP0(a6)
	move.l	(a0)+,$8+EXC_LV+EXC_FP0(a6)

fmovm_data_in_fp1:
	lsl.b	#$1,d1	* should FP1 be moved?
	bpl.b	fmovm_data_in_fp2	* no

	move.l	(a0)+,$0+EXC_LV+EXC_FP1(a6)	* yes
	move.l	(a0)+,$4+EXC_LV+EXC_FP1(a6)
	move.l	(a0)+,$8+EXC_LV+EXC_FP1(a6)

fmovm_data_in_fp2:
	lsl.b	#$1,d1	* should FP2 be moved?
	bpl.b	fmovm_data_in_fp3	* no

	fmovem.x	(a0)+,fp2	* yes

fmovm_data_in_fp3:
	lsl.b	#$1,d1	* should FP3 be moved?
	bpl.b	fmovm_data_in_fp4	* no

	fmovem.x	(a0)+,fp3	* yes

fmovm_data_in_fp4:
	lsl.b	#$1,d1	* should FP4 be moved?
	bpl.b	fmovm_data_in_fp5	* no

	fmovem.x	(a0)+,fp4	* yes

fmovm_data_in_fp5:
	lsl.b	#$1,d1	* should FP5 be moved?
	bpl.b	fmovm_data_in_fp6	* no

	fmovem.x	(a0)+,fp5	* yes

fmovm_data_in_fp6:
	lsl.b	#$1,d1	* should FP6 be moved?
	bpl.b	fmovm_data_in_fp7	* no

	fmovem.x	(a0)+,fp6	* yes

fmovm_data_in_fp7:
	lsl.b	#$1,d1	* should FP7 be moved?
	bpl.b	fmovm_data_in_done	* no

	fmovem.x	(a0)+,fp7	* yes

fmovm_data_in_done:
	add.l	d0,sp	* remove fpregs from stack
	rts

*************************************

fmovm_data_done:
	rts

**-------------------------------------------------------------------------------------------------*****

*
* table indexed by the operation's bit string that gives the number
* of bytes that will be moved.
*
* number of bytes = (* of 1's in bit string) * 12(bytes/fpreg)
*
tbl_fmovm_size:
	dc.b	$00,$0c,$0c,$18,$0c,$18,$18,$24
	dc.b	$0c,$18,$18,$24,$18,$24,$24,$30
	dc.b	$0c,$18,$18,$24,$18,$24,$24,$30
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$0c,$18,$18,$24,$18,$24,$24,$30
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$0c,$18,$18,$24,$18,$24,$24,$30
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$30,$3c,$3c,$48,$3c,$48,$48,$54
	dc.b	$0c,$18,$18,$24,$18,$24,$24,$30
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$30,$3c,$3c,$48,$3c,$48,$48,$54
	dc.b	$18,$24,$24,$30,$24,$30,$30,$3c
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$30,$3c,$3c,$48,$3c,$48,$48,$54
	dc.b	$24,$30,$30,$3c,$30,$3c,$3c,$48
	dc.b	$30,$3c,$3c,$48,$3c,$48,$48,$54
	dc.b	$30,$3c,$3c,$48,$3c,$48,$48,$54
	dc.b	$3c,$48,$48,$54,$48,$54,$54,$60

*
* table to convert a pre-decrement bit string into a post-increment
* or control bit string.
* ex: 	$00	==>	$00
*	$01	==>	$80
*	$02	==>	$40
*	.
*	.
*	$fd	==>	$bf
*	$fe	==>	$7f
*	$ff	==>	$ff
*
tbl_fmovm_convert:
	dc.b	$00,$80,$40,$c0,$20,$a0,$60,$e0
	dc.b	$10,$90,$50,$d0,$30,$b0,$70,$f0
	dc.b	$08,$88,$48,$c8,$28,$a8,$68,$e8
	dc.b	$18,$98,$58,$d8,$38,$b8,$78,$f8
	dc.b	$04,$84,$44,$c4,$24,$a4,$64,$e4
	dc.b	$14,$94,$54,$d4,$34,$b4,$74,$f4
	dc.b	$0c,$8c,$4c,$cc,$2c,$ac,$6c,$ec
	dc.b	$1c,$9c,$5c,$dc,$3c,$bc,$7c,$fc
	dc.b	$02,$82,$42,$c2,$22,$a2,$62,$e2
	dc.b	$12,$92,$52,$d2,$32,$b2,$72,$f2
	dc.b	$0a,$8a,$4a,$ca,$2a,$aa,$6a,$ea
	dc.b	$1a,$9a,$5a,$da,$3a,$ba,$7a,$fa
	dc.b	$06,$86,$46,$c6,$26,$a6,$66,$e6
	dc.b	$16,$96,$56,$d6,$36,$b6,$76,$f6
	dc.b	$0e,$8e,$4e,$ce,$2e,$ae,$6e,$ee
	dc.b	$1e,$9e,$5e,$de,$3e,$be,$7e,$fe
	dc.b	$01,$81,$41,$c1,$21,$a1,$61,$e1
	dc.b	$11,$91,$51,$d1,$31,$b1,$71,$f1
	dc.b	$09,$89,$49,$c9,$29,$a9,$69,$e9
	dc.b	$19,$99,$59,$d9,$39,$b9,$79,$f9
	dc.b	$05,$85,$45,$c5,$25,$a5,$65,$e5
	dc.b	$15,$95,$55,$d5,$35,$b5,$75,$f5
	dc.b	$0d,$8d,$4d,$cd,$2d,$ad,$6d,$ed
	dc.b	$1d,$9d,$5d,$dd,$3d,$bd,$7d,$fd
	dc.b	$03,$83,$43,$c3,$23,$a3,$63,$e3
	dc.b	$13,$93,$53,$d3,$33,$b3,$73,$f3
	dc.b	$0b,$8b,$4b,$cb,$2b,$ab,$6b,$eb
	dc.b	$1b,$9b,$5b,$db,$3b,$bb,$7b,$fb
	dc.b	$07,$87,$47,$c7,$27,$a7,$67,$e7
	dc.b	$17,$97,$57,$d7,$37,$b7,$77,$f7
	dc.b	$0f,$8f,$4f,$cf,$2f,$af,$6f,$ef
	dc.b	$1f,$9f,$5f,$df,$3f,$bf,$7f,$ff

	xdef	fmovm_calc_ea
***********************************************
* _fmovm_calc_ea: calculate effective address *
***********************************************
fmovm_calc_ea:
	move.l	d0,a0	* move * bytes to a0

* currently, MODE and REG are taken from the EXC_LV+EXC_OPWORD. this could be
* easily changed if they were inputs passed in registers.
	move.w	EXC_LV+EXC_OPWORD(a6),d0	* fetch opcode word
	move.w	d0,d1	* make a copy

	andi.w	#$3f,d0	* extract mode field
	andi.l	#$7,d1	* extract reg  field

* jump to the corresponding function for each {MODE,REG} pair.
	move.w	((tbl_fea_mode).b,pc,d0.w*2),d0 * fetch jmp distance
	jmp	((tbl_fea_mode).b,pc,d0.w*1) * jmp to correct ea mode

	illegal
	dc.w	$64
tbl_fea_mode:
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode

	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode
	dc.w	tbl_fea_mode	-	tbl_fea_mode

	dc.w	faddr_ind_a0	- 	tbl_fea_mode
	dc.w	faddr_ind_a1	- 	tbl_fea_mode
	dc.w	faddr_ind_a2	- 	tbl_fea_mode
	dc.w	faddr_ind_a3 	- 	tbl_fea_mode
	dc.w	faddr_ind_a4 	- 	tbl_fea_mode
	dc.w	faddr_ind_a5 	- 	tbl_fea_mode
	dc.w	faddr_ind_a6 	- 	tbl_fea_mode
	dc.w	faddr_ind_a7 	- 	tbl_fea_mode

	dc.w	faddr_ind_p_a0	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a1 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a2 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a3 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a4 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a5 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a6 	- 	tbl_fea_mode
	dc.w	faddr_ind_p_a7 	- 	tbl_fea_mode

	dc.w	faddr_ind_m_a0 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a1 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a2 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a3 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a4 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a5 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a6 	- 	tbl_fea_mode
	dc.w	faddr_ind_m_a7 	- 	tbl_fea_mode

	dc.w	faddr_ind_disp_a0	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a1 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a2 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a3 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a4 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a5 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a6 	- 	tbl_fea_mode
	dc.w	faddr_ind_disp_a7	-	tbl_fea_mode

	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode
	dc.w	faddr_ind_ext 	- 	tbl_fea_mode

	dc.w	fabs_short	- 	tbl_fea_mode
	dc.w	fabs_long	- 	tbl_fea_mode
	dc.w	fpc_ind	- 	tbl_fea_mode
	dc.w	fpc_ind_ext	- 	tbl_fea_mode
	dc.w	tbl_fea_mode	- 	tbl_fea_mode
	dc.w	tbl_fea_mode	- 	tbl_fea_mode
	dc.w	tbl_fea_mode	- 	tbl_fea_mode
	dc.w	tbl_fea_mode	- 	tbl_fea_mode

***********************************
* Address register indirect: (An) *
***********************************
faddr_ind_a0:
	move.l	EXC_LV+EXC_DREGS+$8(a6),a0	* Get current a0
	rts

faddr_ind_a1:
	move.l	EXC_LV+EXC_DREGS+$c(a6),a0	* Get current a1
	rts

faddr_ind_a2:
	move.l	a2,a0	* Get current a2
	rts

faddr_ind_a3:
	move.l	a3,a0	* Get current a3
	rts

faddr_ind_a4:
	move.l	a4,a0	* Get current a4
	rts

faddr_ind_a5:
	move.l	a5,a0	* Get current a5
	rts

faddr_ind_a6:
	move.l	(a6),a0	* Get current a6
	rts

faddr_ind_a7:
	move.l	EXC_LV+EXC_A7(a6),a0	* Get current a7
	rts

*****************************************************
* Address register indirect w/ postincrement: (An)+ *
*****************************************************
faddr_ind_p_a0:
	move.l	EXC_LV+EXC_DREGS+$8(a6),d0	* Get current a0
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,EXC_LV+EXC_DREGS+$8(a6)	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a1:
	move.l	EXC_LV+EXC_DREGS+$c(a6),d0	* Get current a1
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,EXC_LV+EXC_DREGS+$c(a6)	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a2:
	move.l	a2,d0	* Get current a2
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,a2	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a3:
	move.l	a3,d0	* Get current a3
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,a3	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a4:
	move.l	a4,d0	* Get current a4
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,a4	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a5:
	move.l	a5,d0	* Get current a5
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,a5	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a6:
	move.l	(a6),d0	* Get current a6
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,(a6)	* Save incr value
	move.l	d0,a0
	rts

faddr_ind_p_a7:
	move.b	#mia7_flg,EXC_LV+SPCOND_FLG(a6) * set "special case" flag

	move.l	EXC_LV+EXC_A7(a6),d0	* Get current a7
	move.l	d0,d1
	add.l	a0,d1	* Increment
	move.l	d1,EXC_LV+EXC_A7(a6)	* Save incr value
	move.l	d0,a0
	rts

****************************************************
* Address register indirect w/ predecrement: -(An) *
****************************************************
faddr_ind_m_a0:
	move.l	EXC_LV+EXC_DREGS+$8(a6),d0	* Get current a0
	sub.l	a0,d0	* Decrement
	move.l	d0,EXC_LV+EXC_DREGS+$8(a6)	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a1:
	move.l	EXC_LV+EXC_DREGS+$c(a6),d0	* Get current a1
	sub.l	a0,d0	* Decrement
	move.l	d0,EXC_LV+EXC_DREGS+$c(a6)	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a2:
	move.l	a2,d0	* Get current a2
	sub.l	a0,d0	* Decrement
	move.l	d0,a2	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a3:
	move.l	a3,d0	* Get current a3
	sub.l	a0,d0	* Decrement
	move.l	d0,a3	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a4:
	move.l	a4,d0	* Get current a4
	sub.l	a0,d0	* Decrement
	move.l	d0,a4	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a5:
	move.l	a5,d0	* Get current a5
	sub.l	a0,d0	* Decrement
	move.l	d0,a5	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a6:
	move.l	(a6),d0	* Get current a6
	sub.l	a0,d0	* Decrement
	move.l	d0,(a6)	* Save decr value
	move.l	d0,a0
	rts

faddr_ind_m_a7:
	move.b	#mda7_flg,EXC_LV+SPCOND_FLG(a6) * set "special case" flag

	move.l	EXC_LV+EXC_A7(a6),d0	* Get current a7
	sub.l	a0,d0	* Decrement
	move.l	d0,EXC_LV+EXC_A7(a6)	* Save decr value
	move.l	d0,a0
	rts

********************************************************
* Address register indirect w/ displacement: (d16, An) *
********************************************************
faddr_ind_disp_a0:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	EXC_LV+EXC_DREGS+$8(a6),a0	* a0 + d16
	rts

faddr_ind_disp_a1:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	EXC_LV+EXC_DREGS+$c(a6),a0	* a1 + d16
	rts

faddr_ind_disp_a2:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	a2,a0	* a2 + d16
	rts

faddr_ind_disp_a3:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	a3,a0	* a3 + d16
	rts

faddr_ind_disp_a4:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	a4,a0	* a4 + d16
	rts

faddr_ind_disp_a5:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	a5,a0	* a5 + d16
	rts

faddr_ind_disp_a6:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	(a6),a0	* a6 + d16
	rts

faddr_ind_disp_a7:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	EXC_LV+EXC_A7(a6),a0	* a7 + d16
	rts

**********
* Address register indirect w/ index(8-bit displacement): (d8, An, Xn) *
*    "       "         "    w/   "  (base displacement): (bd, An, Xn)  *
* Memory indirect postindexed: ([bd, An], Xn, od)	       *
* Memory indirect preindexed: ([bd, An, Xn], od)	       *
**********
faddr_ind_ext:
	addq.l	#$8,d1
	bsr.l	fetch_dreg	* fetch base areg
	move.l	d0,-(sp)

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word	* fetch extword in d0

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	(sp)+,a0

	btst	#$8,d0
	bne.w	fcalc_mem_ind
	
	move.l	d0,EXC_LV+L_SCR1(a6)	* hold opword

	move.l	d0,d1
	rol.w	#$4,d1
	andi.w	#$f,d1	* extract index regno

* count on fetch_dreg() not to alter a0...
	bsr.l	fetch_dreg	* fetch index

	move.l	d2,-(sp)	* save d2
	move.l	EXC_LV+L_SCR1(a6),d2	* fetch opword

	btst	#$b,d2	* is it word or dc.l?
	bne.b	faii8_long
	ext.l	d0	* sign extend word index
faii8_long:
	move.l	d2,d1
	rol.w	#$7,d1
	andi.l	#$3,d1	* extract scale value

	lsl.l	d1,d0	* shift index by scale

	extb.l	d2	* sign extend displacement
	add.l	d2,d0	* index + disp
	add.l	d0,a0	* An + (index + disp)

	move.l	(sp)+,d2	* restore old d2
	rts

***************************
* Absolute dc.w: (XXX).W *
***************************
fabs_short:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word	* fetch dc.w address

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* return <ea> in a0
	rts

**************************
* Absolute dc.l: (XXX).L *
**************************
fabs_long:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch dc.l address

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,a0	* return <ea> in a0
	rts

*******************************************************
* Program counter indirect w/ displacement: (d16, PC) *
*******************************************************
fpc_ind:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word	* fetch word displacement

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.w	d0,a0	* sign extend displacement

	add.l	EXC_LV+EXC_EXTWPTR(a6),a0	* pc + d16

* _imem_read_word() increased the extwptr by 2. need to adjust here.
	subq.l	#$2,a0	* adjust <ea>
	rts

**********************************************************
* PC indirect w/ index(8-bit displacement): (d8, PC, An) *
* "     "     w/   "  (base displacement): (bd, PC, An)  *
* PC memory indirect postindexed: ([bd, PC], Xn, od)     *
* PC memory indirect preindexed: ([bd, PC, Xn], od)      *
**********************************************************
fpc_ind_ext:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word	* fetch ext word

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* put base in a0
	subq.l	#$2,a0	* adjust base

	btst	#$8,d0	* is disp only 8 bits?
	bne.w	fcalc_mem_ind	* calc memory indirect
	
	move.l	d0,EXC_LV+L_SCR1(a6)	* store opword

	move.l	d0,d1	* make extword copy
	rol.w	#$4,d1	* rotate reg num into place
	andi.w	#$f,d1	* extract register number

* count on fetch_dreg() not to alter a0...
	bsr.l	fetch_dreg	* fetch index

	move.l	d2,-(sp)	* save d2
	move.l	EXC_LV+L_SCR1(a6),d2	* fetch opword

	btst	#$b,d2	* is index word or dc.l?
	bne.b	fpii8_long	* dc.l
	ext.l	d0	* sign extend word index
fpii8_long:
	move.l	d2,d1
	rol.w	#$7,d1	* rotate scale value into place
	andi.l	#$3,d1	* extract scale value

	lsl.l	d1,d0	* shift index by scale

	extb.l	d2	* sign extend displacement
	add.l	d2,d0	* disp + index
	add.l	d0,a0	* An + (index + disp)

	move.l	(sp)+,d2	* restore temp register
	rts

* d2 = index
* d3 = base
* d4 = od
* d5 = extword
fcalc_mem_ind:
	btst	#$6,d0	* is the index suppressed?
	beq.b	fcalc_index

	movem.l	d2-d5,-(sp)	* save d2-d5

	move.l	d0,d5	* put extword in d5
	move.l	a0,d3	* put base in d3

	clr.l	d2	* yes, so index = 0
	bra.b	fbase_supp_ck

* index:
fcalc_index:
	move.l	d0,EXC_LV+L_SCR1(a6)	* save d0 (opword)
	bfextu	d0{16:4},d1	* fetch dreg index
	bsr.l	fetch_dreg

	movem.l	d2-d5,-(sp)	* save d2-d5
	move.l	d0,d2	* put index in d2
	move.l	EXC_LV+L_SCR1(a6),d5
	move.l	a0,d3

	btst	#$b,d5	* is index word or dc.l?
	bne.b	fno_ext
	ext.l	d2

fno_ext:
	bfextu	d5{21:2},d0
	lsl.l	d0,d2

* base address (passed as parameter in d3):
* we clear the value here if it should actually be suppressed.
fbase_supp_ck:
	btst	#$7,d5	* is the bd suppressed?
	beq.b	fno_base_sup
	clr.l	d3

* base displacement:
fno_base_sup:
	bfextu	d5{26:2},d0	* get bd size
*	beq.l	fmovm_error	* if (size == 0) it's reserved

	ICMP.b	 	d0,#$2
	blt.b	fno_bd
	beq.b	fget_word_bd

	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long

	tst.l	d1	* did ifetch fail?
	bne.l	fcea_iacc	* yes

	bra.b	fchk_ind

fget_word_bd:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	fcea_iacc	* yes

	ext.l	d0	* sign extend bd
	
fchk_ind:
	add.l	d0,d3	* base += bd

* outer displacement:
fno_bd:
	bfextu	d5{30:2},d0	* is od suppressed?
	beq.w	faii_bd

	ICMP.b	 	d0,#$2
	blt.b	fnull_od
	beq.b	fword_od
	
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long

	tst.l	d1	* did ifetch fail?
	bne.l	fcea_iacc	* yes

	bra.b 	fadd_them

fword_od:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$2,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_word

	tst.l	d1	* did ifetch fail?
	bne.l	fcea_iacc	* yes

	ext.l	d0	* sign extend od
	bra.b	fadd_them

fnull_od:
	clr.l	d0

fadd_them:
	move.l	d0,d4

	btst	#$2,d5	* pre or post indexing?
	beq.b	fpre_indexed

	move.l	d3,a0
	bsr.l	_dmem_read_long

	tst.l	d1	* did dfetch fail?
	bne.w	fcea_err	* yes

	add.l	d2,d0	* <ea> += index
	add.l	d4,d0	* <ea> += od
	bra.b	fdone_ea

fpre_indexed:
	add.l	d2,d3	* preindexing
	move.l	d3,a0
	bsr.l	_dmem_read_long

	tst.l	d1	* did dfetch fail?
	bne.w	fcea_err	* yes

	add.l	d4,d0	* ea += od
	bra.b	fdone_ea

faii_bd:
	add.l	d2,d3	* ea = (base + bd) + index
	move.l	d3,d0
fdone_ea:
	move.l	d0,a0

	movem.l	(sp)+,d2-d5	* restore d2-d5
	rts

*********************************************************
fcea_err:	
	move.l	d3,a0

	movem.l	(sp)+,d2-d5	* restore d2-d5
	move.w	#$0101,d0
	bra.l	iea_dacc

fcea_iacc:
	movem.l	(sp)+,d2-d5	* restore d2-d5
	bra.l	iea_iacc
	
fmovm_out_err:
	bsr.l	restore
	move.w	#$00e1,d0
	bra.b	fmovm_err

fmovm_in_err:
	bsr.l	restore
	move.w	#$0161,d0

fmovm_err:
	move.l	EXC_LV+L_SCR1(a6),a0
	bra.l	iea_dacc

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fmovm_ctrl(): emulate fmovem.l of control registers instr
*		
* xdef **
*	_imem_read_long() - read longword from memory
*	iea_iacc() - _imem_read_long() failed; error recovery
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	If _imem_read_long() doesn't fail:
*	EXC_LV+USER_FPCR(a6)  = new FPCR value
*	EXC_LV+USER_FPSR(a6)  = new FPSR value
*	EXC_LV+USER_FPIAR(a6) = new FPIAR value
*		
* ALGORITHM ***********************************************************
* 	Decode the instruction type by looking at the extension word 
* in order to see how many control registers to fetch from memory.
* Fetch them using _imem_read_long(). If this fetch fails, exit through
* the special access error exit handler iea_iacc().
*		
* Instruction word decoding:	
*		
* 	fmovem.l *<data>, {FPIAR#|FPCR#|FPSR}
*		
*	WORD1	WORD2
*	1111 0010 00 111100	100$ $$00 0000 0000
*		
*	$$$ (100): FPCR	
*	    (010): FPSR	
*	    (001): FPIAR	
*	    (000): FPIAR	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fmovm_ctrl
fmovm_ctrl:
	move.b	EXC_LV+EXC_EXTWORD(a6),d0	* fetch reg select bits
	ICMP.b	d0,#$9c	* fpcr # fpsr # fpiar ?
	beq.w	fctrl_in_7	* yes
	ICMP.b	d0,#$98	* fpcr # fpsr ?
	beq.w	fctrl_in_6	* yes
	ICMP.b	d0,#$94	* fpcr # fpiar ?
	beq.b	fctrl_in_5	* yes
	
* fmovem.l *<data>, fpsr/fpiar
fctrl_in_3:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPSR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPSR(a6)	* store new FPSR to stack
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPIAR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPIAR(a6)	* store new FPIAR to stack
	rts

* fmovem.l *<data>, fpcr/fpiar
fctrl_in_5:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPCR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPCR(a6)	* store new FPCR to stack
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPIAR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPIAR(a6)	* store new FPIAR to stack
	rts

* fmovem.l *<data>, fpcr/fpsr
fctrl_in_6:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPCR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPCR(a6)	* store new FPCR to mem
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPSR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPSR(a6)	* store new FPSR to mem
	rts

* fmovem.l *<data>, fpcr/fpsr/fpiar
fctrl_in_7:
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPCR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPCR(a6)	* store new FPCR to mem
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPSR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPSR(a6)	* store new FPSR to mem
	move.l	EXC_LV+EXC_EXTWPTR(a6),a0	* fetch instruction addr
	addq.l	#$4,EXC_LV+EXC_EXTWPTR(a6)	* incr instruction ptr
	bsr.l	_imem_read_long	* fetch FPIAR from mem

	tst.l	d1	* did ifetch fail?
	bne.l	iea_iacc	* yes

	move.l	d0,EXC_LV+USER_FPIAR(a6)	* store new FPIAR to mem
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_dcalc_ea(): calc correct <ea> from <ea> stacked on exception
*		
* xdef **
*	inc_areg() - increment an address register
*	dec_areg() - decrement an address register
*		
* INPUT ***************************************************************
*	d0 = number of bytes to adjust <ea> by
* 		
* OUTPUT **************************************************************
*	None	
*		
* ALGORITHM ***********************************************************
* "Dummy" CALCulate Effective Address:	
* 	The stacked <ea> for FP unimplemented instructions and opclass
*	two packed instructions is correct with the exception of...
*		
*	1) -(An)   : The register is not updated regardless of size.
*	     Also, for extended precision and packed, the 
*	     stacked <ea> value is 8 bytes too big
*	2) (An)+   : The register is not updated.
*	3) *<data> : The upper longword of the immediate operand is 
*	     stacked b,w,l and s sizes are completely stacked. 
*	     d,x, and p are not.
*		
**-------------------------------------------------------------------------------------------------

	xdef	_dcalc_ea
_dcalc_ea:
	move.l	d0, a0	* move * bytes to a0

	move.b	1+EXC_LV+EXC_OPWORD(a6), d0	* fetch opcode word
	move.l	d0, d1	* make a copy

	andi.w	#$38, d0	* extract mode field
	andi.l	#$7, d1	* extract reg  field

	ICMP.b	d0,#$18	* is mode (An)+ ?
	beq.b	dcea_pi	* yes

	ICMP.b	d0,#$20	* is mode -(An) ?
	beq.b	dcea_pd	* yes

	or.w	d1,d0	* concat mode,reg
	ICMP.b	d0,#$3c	* is mode *<data>?

	beq.b	dcea_imm	* yes

	move.l	EXC_LV+EXC_EA(a6),a0	* return <ea>
	rts

* need to set immediate data flag here since we'll need to do
* an imem_read to fetch this later.
dcea_imm:
	move.b	#immed_flg,EXC_LV+SPCOND_FLG(a6)
	lea	([EXC_LV+USER_FPIAR,a6],$4),a0 * no; return <ea>
	rts

* here, the <ea> is stacked correctly. however, we must update the
* address register...
dcea_pi:
	move.l	a0,d0	* pass amt to inc by
	bsr.l	inc_areg	* inc addr register

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	rts

* the <ea> is stacked correctly for all but extended and packed which
* the <ea>s are 8 bytes too large.
* it would make no sense to have a pre-decrement to a7 in supervisor
* mode so we don't even worry about this tricky case here : )
dcea_pd:
	move.l	a0,d0	* pass amt to dec by
	bsr.l	dec_areg	* dec addr register

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct

	ICMP.b	d0,#$c	* is opsize ext or packed?
	beq.b	dcea_pd2	* yes
	rts
dcea_pd2:
	sub.l	#$8,a0	* correct <ea>
	move.l	a0,EXC_LV+EXC_EA(a6)	* put correct <ea> on stack
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	_calc_ea_fout(): calculate correct stacked <ea> for extended
*	 and packed data opclass 3 operations.
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	a0 = return correct effective address
*		
* ALGORITHM ***********************************************************
*	For opclass 3 extended and packed data operations, the <ea>
* stacked for the exception is incorrect for -(an) and (an)+ addressing
* modes. Also, while we're at it, the index register itself must get 
* updated.	
* 	So, for -(an), we must subtract 8 off of the stacked <ea> value
* and return that value as the correct <ea> and store that value in An.
* For (an)+, the stacked <ea> is correct but we must adjust An by +12.
*		
**-------------------------------------------------------------------------------------------------

* This calc_ea is currently used to retrieve the correct <ea>
* for fmove outs of type extended and packed.
	xdef	_calc_ea_fout
_calc_ea_fout:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d0	* fetch opcode word
	move.l	d0,d1	* make a copy

	andi.w	#$38,d0	* extract mode field
	andi.l	#$7,d1	* extract reg  field

	ICMP.b	d0,#$18	* is mode (An)+ ?
	beq.b	ceaf_pi	* yes

	ICMP.b	d0,#$20	* is mode -(An) ?
	beq.w	ceaf_pd	* yes

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	rts

* (An)+ : extended and packed fmove out
*	: stacked <ea> is correct
*	: "An" not updated 
ceaf_pi:
	move.w	((tbl_ceaf_pi).b,pc,d1.w*2),d1
	move.l	EXC_LV+EXC_EA(a6),a0
	jmp	((tbl_ceaf_pi).b,pc,d1.w*1)

	illegal
	dc.w	8
tbl_ceaf_pi:
	dc.w	ceaf_pi0 - tbl_ceaf_pi
	dc.w	ceaf_pi1 - tbl_ceaf_pi
	dc.w	ceaf_pi2 - tbl_ceaf_pi
	dc.w	ceaf_pi3 - tbl_ceaf_pi
	dc.w	ceaf_pi4 - tbl_ceaf_pi
	dc.w	ceaf_pi5 - tbl_ceaf_pi
	dc.w	ceaf_pi6 - tbl_ceaf_pi
	dc.w	ceaf_pi7 - tbl_ceaf_pi

ceaf_pi0:
	addi.l	#$c,EXC_LV+EXC_DREGS+$8(a6)
	rts
ceaf_pi1:
	addi.l	#$c,EXC_LV+EXC_DREGS+$c(a6)
	rts
ceaf_pi2:
	add.l	#$c,a2
	rts
ceaf_pi3:
	add.l	#$c,a3
	rts
ceaf_pi4:
	add.l	#$c,a4
	rts
ceaf_pi5:
	add.l	#$c,a5
	rts
ceaf_pi6:
	addi.l	#$c,EXC_LV+EXC_A6(a6)
	rts
ceaf_pi7:
	move.b	#mia7_flg,EXC_LV+SPCOND_FLG(a6)
	addi.l	#$c,EXC_LV+EXC_A7(a6)
	rts

* -(An) : extended and packed fmove out
*	: stacked <ea> = actual <ea> + 8
*	: "An" not updated
ceaf_pd:
	move.w	((tbl_ceaf_pd).b,pc,d1.w*2),d1
	move.l	EXC_LV+EXC_EA(a6),a0
	sub.l	#$8,a0
	sub.l	#$8,EXC_LV+EXC_EA(a6)
	jmp	((tbl_ceaf_pd).b,pc,d1.w*1)

	illegal
	dc.w	$8
tbl_ceaf_pd:
	dc.w	ceaf_pd0 - tbl_ceaf_pd
	dc.w	ceaf_pd1 - tbl_ceaf_pd
	dc.w	ceaf_pd2 - tbl_ceaf_pd
	dc.w	ceaf_pd3 - tbl_ceaf_pd
	dc.w	ceaf_pd4 - tbl_ceaf_pd
	dc.w	ceaf_pd5 - tbl_ceaf_pd
	dc.w	ceaf_pd6 - tbl_ceaf_pd
	dc.w	ceaf_pd7 - tbl_ceaf_pd

ceaf_pd0:
	move.l	a0,EXC_LV+EXC_DREGS+$8(a6)
	rts
ceaf_pd1:
	move.l	a0,EXC_LV+EXC_DREGS+$c(a6)
	rts
ceaf_pd2:
	move.l	a0,a2
	rts
ceaf_pd3:
	move.l	a0,a3
	rts
ceaf_pd4:
	move.l	a0,a4
	rts
ceaf_pd5:
	move.l	a0,a5
	rts
ceaf_pd6:
	move.l	a0,EXC_LV+EXC_A6(a6)
	rts
ceaf_pd7:
	move.l	a0,EXC_LV+EXC_A7(a6)
	move.b	#mda7_flg,EXC_LV+SPCOND_FLG(a6)
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_load_fop(): load operand for unimplemented FP exception
*		
* xdef **
*	set_tag_x() - determine ext prec optype tag
*	set_tag_s() - determine sgl prec optype tag
*	set_tag_d() - determine dbl prec optype tag
*	unnorm_fix() - convert normalized number to denorm or zero
*	norm() - normalize a denormalized number
*	get_packed() - fetch a packed operand from memory
*	_dcalc_ea() - calculate <ea>, fixing An in process
*		
*	_imem_read_{word,dc.l}() - read from instruction memory
*	_dmem_read() - read from data memory
*	_dmem_read_{byte,word,dc.l}() - read from data memory
*		
*	facc_in_{b,w,l,d,x}() - mem read failed; special exit point
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	If memory access doesn't fail:	
*	EXC_LV+FP_SRC(a6) = source operand in extended precision
* 	EXC_LV+FP_DST(a6) = destination operand in extended precision
*		
* ALGORITHM ***********************************************************
* 	This is called from the Unimplemented FP exception handler in
* order to load the source and maybe destination operand into
* EXC_LV+FP_SRC(a6) and EXC_LV+FP_DST(a6). If the instruction was opclass zero, load
* the source and destination from the FP register file. Set the optype
* tags for both if dyadic, one for monadic. If a number is an UNNORM,
* convert it to a DENORM or a ZERO.	
* 	If the instruction is opclass two (memory->reg), then fetch
* the destination from the register file and the source operand from 
* memory. Tag and fix both as above w/ opclass zero instructions.
* 	If the source operand is byte,word,dc.l, or single, it may be
* in the data register file. If it's actually out in memory, use one of
* the mem_read() routines to fetch it. If the mem_read() access returns
* a failing value, exit through the special facc_in() routine which
* will create an acess error exception frame from the current exception *
* frame.	
* 	Immediate data and regular data accesses are separated because 
* if an immediate data access fails, the resulting fault status
* longword stacked for the access error exception must have the 
* instruction bit set.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	_load_fop
_load_fop:

*  15     13 12 10  9 7  6       0
* /        \ /   \ /  \ /         \
* ---------------------------------
* | opclass | RX  | RY | EXTENSION |  (2nd word of general FP instruction)
* ---------------------------------
*

*	bfextu	EXC_LV+EXC_CMDREG(a6)0:3}, d0 * extract opclass
*	ICMP.b	d0, #$2	* which class is it? ('000,'010,'011)
*	beq.w	op010	* handle <ea> -> fpn
*	bgt.w	op011	* handle fpn -> <ea>

* we're not using op011 for now...
	btst	#$6,EXC_LV+EXC_CMDREG(a6)
	bne.b	op010

****************************
* OPCLASS '000: reg -> reg *
****************************
op000:
	move.b	1+EXC_LV+EXC_CMDREG(a6),d0	* fetch extension word lo
	btst	#$5,d0	* testing extension bits
	beq.b	op000_src	* (bit 5 == 0) => monadic
	btst	#$4,d0	* (bit 5 == 1)
	beq.b	op000_dst	* (bit 4 == 0) => dyadic
	and.w	#$007f,d0	* extract extension bits {6:0}
	ICMP.w	d0,#$0038	* is it an fcmp (dyadic) ?
	bne.b	op000_src	* it's an fcmp

op000_dst:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3}, d0 * extract dst field
	bsr.l	load_fpn2	* fetch dst fpreg into EXC_LV+FP_DST

	bsr.l	set_tag_x	* get dst optype tag

	ICMP.b	d0, #UNNORM	* is dst fpreg an UNNORM?
	beq.b	op000_dst_unnorm	* yes
op000_dst_cont:
	move.b 	d0, EXC_LV+DTAG(a6)	* store the dst optype tag

op000_src:
	bfextu	EXC_LV+EXC_CMDREG(a6){3:3}, d0 * extract src field
	bsr.l	load_fpn1	* fetch src fpreg into EXC_LV+FP_SRC

	bsr.l	set_tag_x	* get src optype tag

	ICMP.b	d0, #UNNORM	* is src fpreg an UNNORM?
	beq.b	op000_src_unnorm	* yes
op000_src_cont:
	move.b	d0, EXC_LV+STAG(a6)	* store the src optype tag
	rts

op000_dst_unnorm:
	bsr.l	unnorm_fix	* fix the dst UNNORM
	bra.b	op000_dst_cont
op000_src_unnorm:
	bsr.l	unnorm_fix	* fix the src UNNORM
	bra.b	op000_src_cont

*****************************
* OPCLASS '010: <ea> -> reg *
*****************************
op010:
	move.w	EXC_LV+EXC_CMDREG(a6),d0	* fetch extension word
	btst	#$5,d0	* testing extension bits
	beq.b	op010_src	* (bit 5 == 0) => monadic
	btst	#$4,d0	* (bit 5 == 1)
	beq.b	op010_dst	* (bit 4 == 0) => dyadic
	and.w	#$007f,d0	* extract extension bits {6:0}
	ICMP.w	d0,#$0038	* is it an fcmp (dyadic) ?
	bne.b	op010_src	* it's an fcmp

op010_dst:
	bfextu	EXC_LV+EXC_CMDREG(a6){6:3}, d0 * extract dst field
	bsr.l	load_fpn2	* fetch dst fpreg ptr

	bsr.l	set_tag_x	* get dst type tag

	ICMP.b	d0, #UNNORM	* is dst fpreg an UNNORM?
	beq.b	op010_dst_unnorm	* yes
op010_dst_cont:
	move.b	d0, EXC_LV+DTAG(a6)	* store the dst optype tag

op010_src:
	bfextu	EXC_LV+EXC_CMDREG(a6){3:3}, d0 * extract src type field

	bfextu	EXC_LV+EXC_OPWORD(a6){10:3}, d1 * extract <ea> mode field
	bne.w	fetch_from_mem	* src op is in memory

op010_dreg:
	clr.b	EXC_LV+STAG(a6)	* either NORM or ZERO
	bfextu	EXC_LV+EXC_OPWORD(a6){13:3}, d1 * extract src reg field

	move.w	((tbl_op010_dreg).b,pc,d0.w*2), d0 * jmp based on optype
	jmp	((tbl_op010_dreg).b,pc,d0.w*1) * fetch src from dreg

op010_dst_unnorm:
	bsr.l	unnorm_fix	* fix the dst UNNORM
	bra.b	op010_dst_cont

	illegal
	dc.w	$8
tbl_op010_dreg:
	dc.w	opd_long	- tbl_op010_dreg
	dc.w	opd_sgl 	- tbl_op010_dreg
	dc.w	tbl_op010_dreg	- tbl_op010_dreg
	dc.w	tbl_op010_dreg	- tbl_op010_dreg
	dc.w	opd_word	- tbl_op010_dreg
	dc.w	tbl_op010_dreg	- tbl_op010_dreg
	dc.w	opd_byte	- tbl_op010_dreg
	dc.w	tbl_op010_dreg	- tbl_op010_dreg

*
* LONG: can be either NORM or ZERO...
*
opd_long:
	bsr.l	fetch_dreg	* fetch dc.l in d0
	fmove.l	d0, fp0 	* load a dc.l
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	fbeq.w	opd_long_zero	* dc.l is a ZERO
	rts
opd_long_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set ZERO optype flag
	rts

*
* WORD: can be either NORM or ZERO...
*
opd_word:
	bsr.l	fetch_dreg	* fetch word in d0
	fmove.w	d0, fp0 	* load a word
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	fbeq.w	opd_word_zero	* WORD is a ZERO
	rts
opd_word_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set ZERO optype flag
	rts

*
* BYTE: can be either NORM or ZERO...
*
opd_byte:
	bsr.l	fetch_dreg	* fetch word in d0
	fmove.b	d0, fp0 	* load a byte
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	fbeq.w	opd_byte_zero	* byte is a ZERO
	rts
opd_byte_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set ZERO optype flag
	rts

*
* SGL: can be either NORM, DENORM, ZERO, INF, QNAN or SNAN but not UNNORM
*
* separate SNANs and DENORMs so they can be loaded w/ special care.
* all others can simply be moved "in" using fmove.
*
opd_sgl:
	bsr.l	fetch_dreg	* fetch sgl in d0
	move.l	d0,EXC_LV+L_SCR1(a6)

	lea	EXC_LV+L_SCR1(a6), a0 	* pass: ptr to the sgl
	bsr.l	set_tag_s	* determine sgl type
	move.b	d0, EXC_LV+STAG(a6)	* save the src tag

	ICMP.b	d0, #SNAN	* is it an SNAN?
	beq.w	get_sgl_snan	* yes

	ICMP.b	d0, #DENORM	* is it a DENORM?
	beq.w	get_sgl_denorm	* yes

	fmove.s	(a0), fp0	* no, so can load it regular
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	rts

**-------------------------------------------------------------------------------------------------*****

**-------------------------------------------------------------------------------------------------
* fetch_from_mem():	
* - src is out in memory. must:	
*	(1) calc ea - must read AFTER you know the src type since
*	      if the ea is -() or ()+, need to know * of bytes.
*	(2) read it in from either user or supervisor space
*	(3) if (b || w || l) then simply read in
*	    if (s || d || x) then check for SNAN,UNNORM,DENORM
*	    if (packed) then punt for now
* INPUT:	
*	d0 : src type field	
**-------------------------------------------------------------------------------------------------
fetch_from_mem:
	clr.b	EXC_LV+STAG(a6)	* either NORM or ZERO

	move.w	((tbl_EXC_LV+FP_type).b,pc,d0.w*2), d0 * index by src type field
	jmp	((tbl_EXC_LV+FP_type).b,pc,d0.w*1)

	illegal
	dc.w	$8
tbl_EXC_LV+FP_type:
	dc.w	load_long	- tbl_EXC_LV+FP_type
	dc.w	load_sgl	- tbl_EXC_LV+FP_type
	dc.w	load_ext	- tbl_EXC_LV+FP_type
	dc.w	load_packed	- tbl_EXC_LV+FP_type
	dc.w	load_word	- tbl_EXC_LV+FP_type
	dc.w	load_dbl	- tbl_EXC_LV+FP_type
	dc.w	load_byte	- tbl_EXC_LV+FP_type
	dc.w	tbl_EXC_LV+FP_type	- tbl_EXC_LV+FP_type

*****************************************
* load a LONG into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 4 bytes into EXC_LV+L_SCR1
*	(3) fmove.l into fp0
*****************************************
load_long:
	moveq.l	#$4, d0	* pass: 4 (bytes)
	bsr.l	_dcalc_ea	* calc <ea>; <ea> in a0

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#immed_flg
	beq.b	load_long_immed

	bsr.l	_dmem_read_long	* fetch src operand from memory

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_l	* yes

load_long_cont:
	fmove.l	d0, fp0	* read into fp0;convert to xprec
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC

	fbeq.w	load_long_zero	* src op is a ZERO
	rts
load_long_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set optype tag to ZERO
	rts

load_long_immed:
	bsr.l	_imem_read_long	* fetch src operand immed data

	tst.l	d1	* did ifetch fail?
	bne.l	funimp_iacc	* yes
	bra.b	load_long_cont

*****************************************
* load a WORD into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 2 bytes into EXC_LV+L_SCR1
*	(3) fmove.w into fp0
*****************************************
load_word:
	moveq.l	#$2, d0	* pass: 2 (bytes)
	bsr.l	_dcalc_ea	* calc <ea>; <ea> in a0

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#immed_flg
	beq.b	load_word_immed

	bsr.l	_dmem_read_word	* fetch src operand from memory

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_w	* yes

load_word_cont:
	fmove.w	d0, fp0	* read into fp0;convert to xprec
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC

	fbeq.w	load_word_zero	* src op is a ZERO
	rts
load_word_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set optype tag to ZERO
	rts

load_word_immed:
	bsr.l	_imem_read_word	* fetch src operand immed data

	tst.l	d1	* did ifetch fail?
	bne.l	funimp_iacc	* yes
	bra.b	load_word_cont

*****************************************
* load a BYTE into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 1 byte into EXC_LV+L_SCR1
*	(3) fmove.b into fp0
*****************************************
load_byte:
	moveq.l	#$1, d0	* pass: 1 (byte)
	bsr.l	_dcalc_ea	* calc <ea>; <ea> in a0

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#immed_flg
	beq.b	load_byte_immed

	bsr.l	_dmem_read_byte	* fetch src operand from memory

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_b	* yes

load_byte_cont:
	fmove.b	d0, fp0	* read into fp0;convert to xprec
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC

	fbeq.w	load_byte_zero	* src op is a ZERO
	rts
load_byte_zero:
	move.b	#ZERO, EXC_LV+STAG(a6)	* set optype tag to ZERO
	rts

load_byte_immed:
	bsr.l	_imem_read_word	* fetch src operand immed data

	tst.l	d1	* did ifetch fail?
	bne.l	funimp_iacc	* yes
	bra.b	load_byte_cont

*****************************************
* load a SGL into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 4 bytes into EXC_LV+L_SCR1
*	(3) fmove.s into fp0
*****************************************
load_sgl:
	moveq.l	#$4, d0	* pass: 4 (bytes)
	bsr.l	_dcalc_ea	* calc <ea>; <ea> in a0

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#immed_flg
	beq.b	load_sgl_immed

	bsr.l	_dmem_read_long	* fetch src operand from memory
	move.l	d0, EXC_LV+L_SCR1(a6)	* store src op on stack

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_l	* yes

load_sgl_cont:
	lea	EXC_LV+L_SCR1(a6), a0	* pass: ptr to sgl src op
	bsr.l	set_tag_s	* determine src type tag
	move.b	d0, EXC_LV+STAG(a6)	* save src optype tag on stack

	ICMP.b	d0, #DENORM	* is it a sgl DENORM?
	beq.w	get_sgl_denorm	* yes

	ICMP.b	d0, #SNAN	* is it a sgl SNAN?
	beq.w	get_sgl_snan	* yes

	fmove.s	EXC_LV+L_SCR1(a6), fp0	* read into fp0;convert to xprec
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	rts

load_sgl_immed:
	bsr.l	_imem_read_long	* fetch src operand immed data

	tst.l	d1	* did ifetch fail?
	bne.l	funimp_iacc	* yes
	bra.b	load_sgl_cont

* must convert sgl denorm format to an Xprec denorm fmt suitable for 
* normalization...
* a0 : points to sgl denorm
get_sgl_denorm:
	clr.w	EXC_LV+FP_SRC_EX(a6)
	bfextu	(a0){9:23}, d0	* fetch sgl hi(_mantissa)
	lsl.l	#$8, d0
	move.l	d0, EXC_LV+FP_SRC_HI(a6)	* set ext hi(_mantissa)
	clr.l	EXC_LV+FP_SRC_LO(a6)	* set ext lo(_mantissa)

	clr.w	EXC_LV+FP_SRC_EX(a6)
	btst	#$7, (a0)	* is sgn bit set?
	beq.b	sgl_dnrm_norm
	bset	#$7, EXC_LV+FP_SRC_EX(a6)	* set sgn of xprec value

sgl_dnrm_norm:
	lea	EXC_LV+FP_SRC(a6), a0
	bsr.l	norm	* normalize number
	move.w	#$3f81, d1	* xprec exp = $3f81
	sub.w	d0, d1	* exp = $3f81 - shft amt.
	or.w	d1, EXC_LV+FP_SRC_EX(a6)	* {sgn,exp}

	move.b	#NORM, EXC_LV+STAG(a6)	* fix src type tag
	rts

* convert sgl to ext SNAN
* a0 : points to sgl SNAN
get_sgl_snan:
	move.w	#$7fff, EXC_LV+FP_SRC_EX(a6) * set exp of SNAN
	bfextu	(a0){9:23}, d0
	lsl.l	#$8, d0	* extract and insert hi(man)
	move.l	d0, EXC_LV+FP_SRC_HI(a6)
	clr.l	EXC_LV+FP_SRC_LO(a6)

	btst	#$7, (a0)	* see if sign of SNAN is set
	beq.b	no_sgl_snan_sgn
	bset	#$7, EXC_LV+FP_SRC_EX(a6)
no_sgl_snan_sgn:
	rts

*****************************************
* load a DBL into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 8 bytes into EXC_LV+L_SCR(1,2)*
*	(3) fmove.d into fp0
*****************************************
load_dbl:
	moveq.l	#$8, d0	* pass: 8 (bytes)
	bsr.l	_dcalc_ea	* calc <ea>; <ea> in a0

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#immed_flg
	beq.b	load_dbl_immed

	lea	EXC_LV+L_SCR1(a6), a1	* pass: ptr to input dbl tmp space
	moveq.l	#$8, d0	* pass: * bytes to read
	bsr.l	_dmem_read	* fetch src operand from memory

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_d	* yes

load_dbl_cont:
	lea	EXC_LV+L_SCR1(a6), a0	* pass: ptr to input dbl
	bsr.l	set_tag_d	* determine src type tag
	move.b	d0, EXC_LV+STAG(a6)	* set src optype tag

	ICMP.b	d0, #DENORM	* is it a dbl DENORM?
	beq.w	get_dbl_denorm	* yes

	ICMP.b	d0, #SNAN	* is it a dbl SNAN?
	beq.w	get_dbl_snan	* yes

	fmove.d	EXC_LV+L_SCR1(a6), fp0	* read into fp0;convert to xprec
	fmovem.x	fp0, EXC_LV+FP_SRC(a6)	* return src op in EXC_LV+FP_SRC
	rts

load_dbl_immed:
	lea	EXC_LV+L_SCR1(a6), a1	* pass: ptr to input dbl tmp space
	moveq.l	#$8, d0	* pass: * bytes to read
	bsr.l	_imem_read	* fetch src operand from memory

	tst.l	d1	* did ifetch fail?
	bne.l	funimp_iacc	* yes
	bra.b	load_dbl_cont

* must convert dbl denorm format to an Xprec denorm fmt suitable for 
* normalization...
* a0 : loc. of dbl denorm
get_dbl_denorm:
	clr.w	EXC_LV+FP_SRC_EX(a6)
	bfextu	(a0){12:31}, d0	* fetch hi(_mantissa)
	move.l	d0, EXC_LV+FP_SRC_HI(a6)
	bfextu	4(a0){11:21}, d0	* fetch lo(_mantissa)
	move.l	#$b, d1
	lsl.l	d1, d0
	move.l	d0, EXC_LV+FP_SRC_LO(a6)

	btst	#$7, (a0)	* is sgn bit set?
	beq.b	dbl_dnrm_norm
	bset	#$7, EXC_LV+FP_SRC_EX(a6)	* set sgn of xprec value

dbl_dnrm_norm:
	lea	EXC_LV+FP_SRC(a6), a0
	bsr.l	norm	* normalize number
	move.w	#$3c01, d1	* xprec exp = $3c01
	sub.w	d0, d1	* exp = $3c01 - shft amt.
	or.w	d1, EXC_LV+FP_SRC_EX(a6)	* {sgn,exp}

	move.b	#NORM, EXC_LV+STAG(a6)	* fix src type tag
	rts

* convert dbl to ext SNAN
* a0 : points to dbl SNAN
get_dbl_snan:
	move.w	#$7fff, EXC_LV+FP_SRC_EX(a6) * set exp of SNAN

	bfextu	(a0){12:31}, d0	* fetch hi(_mantissa)
	move.l	d0, EXC_LV+FP_SRC_HI(a6)
	bfextu	4(a0){11:21}, d0	* fetch lo(_mantissa)
	move.l	#$b, d1
	lsl.l	d1, d0
	move.l	d0, EXC_LV+FP_SRC_LO(a6)

	btst	#$7, (a0)	* see if sign of SNAN is set
	beq.b	no_dbl_snan_sgn
	bset	#$7, EXC_LV+FP_SRC_EX(a6)
no_dbl_snan_sgn:
	rts

*************************************************
* load a Xprec into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 12 bytes into EXC_LV+L_SCR(1,2)
*	(3) fmove.x into fp0
*************************************************
load_ext:
	move.l	#$c, d0	* pass: 12 (bytes)
	bsr.l	_dcalc_ea	* calc <ea>

	lea	EXC_LV+FP_SRC(a6), a1	* pass: ptr to input ext tmp space
	move.l	#$c, d0	* pass: * of bytes to read
	bsr.l	_dmem_read	* fetch src operand from memory

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_x	* yes

	lea	EXC_LV+FP_SRC(a6), a0	* pass: ptr to src op
	bsr.l	set_tag_x	* determine src type tag

	ICMP.b	d0, #UNNORM	* is the src op an UNNORM?
	beq.b	load_ext_unnorm	* yes

	move.b	d0, EXC_LV+STAG(a6)	* store the src optype tag
	rts

load_ext_unnorm:
	bsr.l	unnorm_fix	* fix the src UNNORM
	move.b	d0, EXC_LV+STAG(a6)	* store the src optype tag
	rts

*************************************************
* load a packed into fp0:
* 	-number can't fault
*	(1) calc ea
*	(2) read 12 bytes into EXC_LV+L_SCR(1,2,3)
*	(3) fmove.x into fp0
*************************************************
load_packed:
	bsr.l	get_packed

	lea	EXC_LV+FP_SRC(a6),a0	* pass ptr to src op
	bsr.l	set_tag_x	* determine src type tag
	ICMP.b	d0,#UNNORM	* is the src op an UNNORM ZERO?
	beq.b	load_packed_unnorm	* yes

	move.b	d0,EXC_LV+STAG(a6)	* store the src optype tag
	rts

load_packed_unnorm:
	bsr.l	unnorm_fix	* fix the UNNORM ZERO
	move.b	d0,EXC_LV+STAG(a6)	* store the src optype tag
	rts	

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	fout(): move from fp register to memory or data register
*		
* xdef **
*	_round() - needed to create EXOP for sgl/dbl precision
*	norm() - needed to create EXOP for extended precision
*	ovf_res() - create default overflow result for sgl/dbl precision*
*	unf_res() - create default underflow result for sgl/dbl prec.
*	dst_dbl() - create rounded dbl precision result.
*	dst_sgl() - create rounded sgl precision result.
*	fetch_dreg() - fetch dynamic k-factor reg for packed.
*	bindec() - convert FP binary number to packed number.
*	_mem_write() - write data to memory.
*	_mem_write2() - write data to memory unless supv mode -(a7) exc.*
*	_dmem_write_{byte,word,dc.l}() - write data to memory.
*	store_dreg_{b,w,l}() - store data to data register file.
*	facc_out_{b,w,l,d,x}() - data access error occurred.
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision source operand
*	d0 = round prec,mode	
* 		
* OUTPUT **************************************************************
*	fp0 : intermediate underflow or overflow result if
*	      OVFL/UNFL occurred for a sgl or dbl operand
*		
* ALGORITHM ***********************************************************
*	This routine is accessed by many handlers that need to do an
* opclass three move of an operand out to memory.
*	Decode an fmove out (opclass 3) instruction to determine if
* it's b,w,l,s,d,x, or p in size. b,w,l can be stored to either a data
* register or memory. The algorithm uses a standard "fmove" to create
* the rounded result. Also, since exceptions are disabled, this also
* create the correct OPERR default result if appropriate.
*	For sgl or dbl precision, overflow or underflow can occur. If
* either occurs and is enabled, the EXOP.
*	For extended precision, the stacked <ea> must be fixed along
* w/ the address index register as appropriate w/ _calc_ea_fout(). If
* the source is a denorm and if underflow is enabled, an EXOP must be
* created.	
* 	For packed, the k-factor must be fetched from the instruction
* word or a data register. The <ea> must be fixed as w/ extended 
* precision. Then, bindec() is called to create the appropriate 
* packed result.	
*	If at any time an access error is flagged by one of the move-
* to-memory routines, then a special exit must be made so that the
* access error can be handled properly.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	fout
fout:
	bfextu	EXC_LV+EXC_CMDREG(a6){3:3},d1 * extract dst fmt
	move.w	((tbl_fout).b,pc,d1.w*2),a1 * use as index
	jmp	((tbl_fout).b,pc,a1)	* jump to routine

	illegal
	dc.w	8
tbl_fout:
	dc.w	fout_long	-	tbl_fout
	dc.w	fout_sgl	-	tbl_fout
	dc.w	fout_ext	-	tbl_fout
	dc.w	fout_pack	-	tbl_fout
	dc.w	fout_word	-	tbl_fout
	dc.w	fout_dbl	-	tbl_fout
	dc.w	fout_byte	-	tbl_fout
	dc.w	fout_pack	-	tbl_fout

***
* fmove.b out ***************************************************
***

* Only "Unimplemented Data Type" exceptions enter here. The operand
* is either a DENORM or a NORM.
fout_byte:
	tst.b	EXC_LV+STAG(a6)	* is operand normalized?
	bne.b	fout_byte_denorm	* no

	fmovem.x	SRC(a0),fp0	* load value

fout_byte_norm:
	fmove.l	d0,fpcr	* insert rnd prec,mode

	fmove.b	fp0,d0	* exec move out w/ correct rnd mode

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* fetch FPSR
	or.w	d1,2+EXC_LV+USER_FPSR(a6)	* save new exc,accrued bits

	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_byte_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_byte	* write byte

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_b	* yes

	rts

fout_byte_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_b
	rts

fout_byte_denorm:
	move.l	SRC_EX(a0),d1
	andi.l	#$80000000,d1	* keep DENORM sign
	ori.l	#$00800000,d1	* make smallest sgl
	fmove.s	d1,fp0
	bra.b	fout_byte_norm

***
* fmove.w out ***************************************************
***

* Only "Unimplemented Data Type" exceptions enter here. The operand
* is either a DENORM or a NORM.
fout_word:
	tst.b	EXC_LV+STAG(a6)	* is operand normalized?
	bne.b	fout_word_denorm	* no

	fmovem.x	SRC(a0),fp0	* load value

fout_word_norm:
	fmove.l	d0,fpcr	* insert rnd prec:mode

	fmove.w	fp0,d0	* exec move out w/ correct rnd mode

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* fetch FPSR
	or.w	d1,2+EXC_LV+USER_FPSR(a6)	* save new exc,accrued bits

	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_word_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_word	* write word

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_w	* yes

	rts

fout_word_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_w
	rts

fout_word_denorm:
	move.l	SRC_EX(a0),d1
	andi.l	#$80000000,d1	* keep DENORM sign
	ori.l	#$00800000,d1	* make smallest sgl
	fmove.s	d1,fp0
	bra.b	fout_word_norm
	
***
* fmove.l out ***************************************************
***

* Only "Unimplemented Data Type" exceptions enter here. The operand
* is either a DENORM or a NORM.
fout_long:
	tst.b	EXC_LV+STAG(a6)	* is operand normalized?
	bne.b	fout_long_denorm	* no

	fmovem.x	SRC(a0),fp0	* load value

fout_long_norm:
	fmove.l	d0,fpcr	* insert rnd prec:mode

	fmove.l	fp0,d0	* exec move out w/ correct rnd mode

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* fetch FPSR
	or.w	d1,2+EXC_LV+USER_FPSR(a6)	* save new exc,accrued bits

fout_long_write:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_long_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_long	* write dc.l

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	rts

fout_long_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_l
	rts

fout_long_denorm:
	move.l	SRC_EX(a0),d1
	andi.l	#$80000000,d1	* keep DENORM sign
	ori.l	#$00800000,d1	* make smallest sgl
	fmove.s	d1,fp0
	bra.b	fout_long_norm

***
* fmove.x out ***************************************************
***

* Only "Unimplemented Data Type" exceptions enter here. The operand
* is either a DENORM or a NORM.
* The DENORM causes an Underflow exception.
fout_ext:

* we copy the extended precision result to EXC_LV+FP_SCR0 so that the reserved
* 16-bit field gets zeroed. we do this since we promise not to disturb
* what's at SRC(a0).
	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	clr.w	2+EXC_LV+FP_SCR0_EX(a6)	* clear reserved field
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	fmovem.x	SRC(a0),fp0	* return result

	bsr.l	_calc_ea_fout	* fix stacked <ea>

	move.l	a0,a1	* pass: dst addr
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: src addr
	move.l	#$c,d0	* pass: opsize is 12 bytes

* we must not yet write the extended precision data to the stack
* in the pre-decrement case from supervisor mode or else we'll corrupt 
* the stack frame. so, leave it in EXC_LV+FP_SRC for now and deal with it later...
	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	beq.b	fout_ext_a7

	bsr.l	_dmem_write	* write ext prec number to memory

	tst.l	d1	* did dstore fail?
	bne.w	fout_ext_err	* yes

	tst.b	EXC_LV+STAG(a6)	* is operand normalized?
	bne.b	fout_ext_denorm	* no
	rts

* the number is a DENORM. must set the underflow exception bit
fout_ext_denorm:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set underflow exc bit

	move.b	EXC_LV+FPCR_ENABLE(a6),d0
	andi.b	#$0a,d0	* is UNFL or INEX enabled?
	bne.b	fout_ext_exc	* yes
	rts

* we don't want to do the write if the exception occurred in supervisor mode
* so _mem_write2() handles this for us.
fout_ext_a7:
	bsr.l	_mem_write2	* write ext prec number to memory

	tst.l	d1	* did dstore fail?
	bne.w	fout_ext_err	* yes

	tst.b	EXC_LV+STAG(a6)	* is operand normalized?
	bne.b	fout_ext_denorm	* no
	rts

fout_ext_exc:
	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm	* normalize the mantissa
	neg.w	d0	* new exp = -(shft amt)
	andi.w	#$7fff,d0
	andi.w	#$8000,EXC_LV+FP_SCR0_EX(a6)	* keep only old sign
	or.w	d0,EXC_LV+FP_SCR0_EX(a6)	* insert new exponent
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

fout_ext_err:
	move.l	EXC_LV+EXC_A6(a6),(a6)	* fix stacked a6
	bra.l	facc_out_x

**-------------------------------------------------------------------------------------------------
* fmove.s out ***********************************************************
**-------------------------------------------------------------------------------------------------
fout_sgl:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#s_mode*$10,d0	* insert sgl prec
	move.l	d0,EXC_LV+L_SCR3(a6)	* save rnd prec,mode on stack

*
* operand is a normalized number. first, we check to see if the move out
* would cause either an underflow or overflow. these cases are handled
* separately. otherwise, set the FPCR to the proper rounding mode and
* execute the move.
*
	move.w	SRC_EX(a0),d0	* extract exponent
	andi.w	#$7fff,d0	* strip sign

	ICMP.w	d0,#SGL_HI	* will operand overflow?
	bgt.w	fout_sgl_ovfl	* yes; go handle OVFL
	beq.w	fout_sgl_may_ovfl	* maybe; go handle possible OVFL
	ICMP.w	d0,#SGL_LO	* will operand underflow?
	blt.w	fout_sgl_unfl	* yes; go handle underflow

*
* NORMs(in range) can be stored out by a simple "fmove.s"
* Unnormalized inputs can come through this point.
*
fout_sgl_exg:
	fmovem.x	SRC(a0),fp0	* fetch fop from stack

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmove.s	fp0,d0	* store does convert and round

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d1	* save FPSR

	or.w	d1,2+EXC_LV+USER_FPSR(a6) 	* set possible inex2/ainex

fout_sgl_exg_write:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_sgl_exg_write_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_long	* write dc.l

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	rts

fout_sgl_exg_write_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_l
	rts

*
* here, we know that the operand would UNFL if moved out to single prec,
* so, denorm and round and then use generic store single routine to
* write the value to memory.
*
fout_sgl_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set UNFL

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.l	a0,-(sp)

	clr.l	d0	* pass: S.F. = 0

	ICMP.b	EXC_LV+STAG(a6),#DENORM	* fetch src optype tag
	bne.b	fout_sgl_unfl_cont	* let DENORMs fall through

	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm	* normalize the DENORM
	
fout_sgl_unfl_cont:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calc default underflow result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to fop
	bsr.l	dst_sgl	* convert to single prec

	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_sgl_unfl_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_long	* write dc.l

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	bra.b	fout_sgl_unfl_chkexc

fout_sgl_unfl_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_l

fout_sgl_unfl_chkexc:
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0a,d1	* is UNFL or INEX enabled?
	bne.w	fout_sd_EXC_LV+EXC_unfl	* yes
	addq.l	#$4,sp
	rts

*
* it's definitely an overflow so call ovf_res to get the correct answer
*
fout_sgl_ovfl:
	tst.b	3+SRC_HI(a0)	* is result inexact?
	bne.b	fout_sgl_ovfl_inex2
	tst.l	SRC_LO(a0)	* is result inexact?
	bne.b	fout_sgl_ovfl_inex2
	ori.w	#ovfl_inx_mask,2+EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex
	bra.b	fout_sgl_ovfl_cont
fout_sgl_ovfl_inex2:
	ori.w	#ovfinx_mask,2+EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex/inex2

fout_sgl_ovfl_cont:
	move.l	a0,-(sp)

* call ovf_res() w/ sgl prec and the correct rnd mode to create the default
* overflow result. DON'T save the returned ccodes from ovf_res() since
* fmove out doesn't alter them. 
	tst.b	SRC_EX(a0)	* is operand negative?
	smi	d1	* set if so
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: sgl prec,rnd mode
	bsr.l	ovf_res	* calc OVFL result
	fmovem.x	(a0),fp0	* load default overflow result
	fmove.s	fp0,d0	* store to single

	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract dst mode
	andi.b	#$38,d1	* is mode == 0? (Dreg dst)
	beq.b	fout_sgl_ovfl_dn	* must save to integer regfile

	move.l	EXC_LV+EXC_EA(a6),a0	* stacked <ea> is correct
	bsr.l	_dmem_write_long	* write dc.l

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_l	* yes

	bra.b	fout_sgl_ovfl_chkexc

fout_sgl_ovfl_dn:
	move.b	1+EXC_LV+EXC_OPWORD(a6),d1	* extract Dn
	andi.w	#$7,d1
	bsr.l	store_dreg_l

fout_sgl_ovfl_chkexc:
	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0a,d1	* is UNFL or INEX enabled?
	bne.w	fout_sd_EXC_LV+EXC_ovfl	* yes
	addq.l	#$4,sp
	rts

*
* move out MAY overflow:
* (1) force the exp to $3fff
* (2) do a move w/ appropriate rnd mode
* (3) if exp still equals zero, then insert original exponent
*	for the correct result.
*     if exp now equals one, then it overflowed so call ovf_res.
*
fout_sgl_may_ovfl:
	move.w	SRC_EX(a0),d1	* fetch current sign
	andi.w	#$8000,d1	* keep it,clear exp
	ori.w	#$3fff,d1	* insert exp = 0
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert scaled exp
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6) * copy hi(man)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6) * copy lo(man)

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* force fop to be rounded
	fmove.l	#$0,fpcr	* clear FPCR

	fabs.x	fp0	* need absolute value
	fcmp.b	#2,fp0	* did exponent increase?
	fblt.w	fout_sgl_exg	* no; go finish NORM	
	bra.w	fout_sgl_ovfl	* yes; go handle overflow

****************

fout_sd_EXC_LV+EXC_unfl:
	move.l	(sp)+,a0

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

	ICMP.b	EXC_LV+STAG(a6),#DENORM	* was src a DENORM?
	bne.b	fout_sd_EXC_LV+EXC_cont	* no

	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm
	neg.l	d0
	andi.w	#$7fff,d0
	bfins	d0,EXC_LV+FP_SCR0_EX(a6){1:15}
	bra.b	fout_sd_EXC_LV+EXC_cont

fout_sd_exc:
fout_sd_EXC_LV+EXC_ovfl:
	move.l	(sp)+,a0	* restore a0

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)

fout_sd_EXC_LV+EXC_cont:
	bclr	#$7,EXC_LV+FP_SCR0_EX(a6)	* clear sign bit
	sne.b	2+EXC_LV+FP_SCR0_EX(a6)	* set internal sign bit
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to DENORM

	move.b	3+EXC_LV+L_SCR3(a6),d1
	lsr.b	#$4,d1
	andi.w	#$0c,d1
	swap	d1
	move.b	3+EXC_LV+L_SCR3(a6),d1
	lsr.b	#$4,d1
	andi.w	#$03,d1
	clr.l	d0	* pass: zero g,r,s
	bsr.l	_round	* round the DENORM

	tst.b	2+EXC_LV+FP_SCR0_EX(a6)	* is EXOP negative?
	beq.b	fout_sd_EXC_LV+EXC_done	* no
	bset	#$7,EXC_LV+FP_SCR0_EX(a6)	* yes

fout_sd_EXC_LV+EXC_done:
	fmovem.x	EXC_LV+FP_SCR0(a6),fp1	* return EXOP in fp1
	rts

***
* fmove.d out ***************************************************
***
fout_dbl:
	andi.b	#$30,d0	* clear rnd prec
	ori.b	#d_mode*$10,d0	* insert dbl prec
	move.l	d0,EXC_LV+L_SCR3(a6)	* save rnd prec,mode on stack

*
* operand is a normalized number. first, we check to see if the move out
* would cause either an underflow or overflow. these cases are handled
* separately. otherwise, set the FPCR to the proper rounding mode and
* execute the move.
*
	move.w	SRC_EX(a0),d0	* extract exponent
	andi.w	#$7fff,d0	* strip sign

	ICMP.w	d0,#DBL_HI	* will operand overflow?
	bgt.w	fout_dbl_ovfl	* yes; go handle OVFL
	beq.w	fout_dbl_may_ovfl	* maybe; go handle possible OVFL
	ICMP.w	d0,#DBL_LO	* will operand underflow?
	blt.w	fout_dbl_unfl	* yes; go handle underflow

*
* NORMs(in range) can be stored out by a simple "fmove.d"
* Unnormalized inputs can come through this point.
*
fout_dbl_exg:
	fmovem.x	SRC(a0),fp0	* fetch fop from stack

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR
	fmove.l	#$0,fpsr	* clear FPSR

	fmove.d	fp0,EXC_LV+L_SCR1(a6)	* store does convert and round

	fmove.l	#$0,fpcr	* clear FPCR
	fmove.l	fpsr,d0	* save FPSR

	or.w	d0,2+EXC_LV+USER_FPSR(a6) 	* set possible inex2/ainex

	move.l	EXC_LV+EXC_EA(a6),a1	* pass: dst addr
	lea	EXC_LV+L_SCR1(a6),a0	* pass: src addr
	moveq.l	#$8,d0	* pass: opsize is 8 bytes
	bsr.l	_dmem_write	* store dbl fop to memory

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_d	* yes

	rts		* no; so we're finished	

*
* here, we know that the operand would UNFL if moved out to double prec,
* so, denorm and round and then use generic store double routine to
* write the value to memory.
*
fout_dbl_unfl:
	bset	#unfl_bit,EXC_LV+FPSR_EXCEPT(a6) * set UNFL

	move.w	SRC_EX(a0),EXC_LV+FP_SCR0_EX(a6)
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6)
	move.l	a0,-(sp)

	clr.l	d0	* pass: S.F. = 0

	ICMP.b	EXC_LV+STAG(a6),#DENORM	* fetch src optype tag
	bne.b	fout_dbl_unfl_cont	* let DENORMs fall through

	lea	EXC_LV+FP_SCR0(a6),a0
	bsr.l	norm	* normalize the DENORM
	
fout_dbl_unfl_cont:
	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to operand
	move.l	EXC_LV+L_SCR3(a6),d1	* pass: rnd prec,mode
	bsr.l	unf_res	* calc default underflow result

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: ptr to fop
	bsr.l	dst_dbl	* convert to single prec
	move.l	d0,EXC_LV+L_SCR1(a6)
	move.l	d1,EXC_LV+L_SCR2(a6)

	move.l	EXC_LV+EXC_EA(a6),a1	* pass: dst addr
	lea	EXC_LV+L_SCR1(a6),a0	* pass: src addr
	moveq.l	#$8,d0	* pass: opsize is 8 bytes
	bsr.l	_dmem_write	* store dbl fop to memory

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_d	* yes

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0a,d1	* is UNFL or INEX enabled?
	bne.w	fout_sd_EXC_LV+EXC_unfl	* yes
	addq.l	#$4,sp
	rts

*
* it's definitely an overflow so call ovf_res to get the correct answer
*
fout_dbl_ovfl:
	move.w	2+SRC_LO(a0),d0
	andi.w	#$7ff,d0
	bne.b	fout_dbl_ovfl_inex2

	ori.w	#ovfl_inx_mask,2+EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex
	bra.b	fout_dbl_ovfl_cont
fout_dbl_ovfl_inex2:
	ori.w	#ovfinx_mask,2+EXC_LV+USER_FPSR(a6) * set ovfl/aovfl/ainex/inex2

fout_dbl_ovfl_cont:
	move.l	a0,-(sp)

* call ovf_res() w/ dbl prec and the correct rnd mode to create the default
* overflow result. DON'T save the returned ccodes from ovf_res() since
* fmove out doesn't alter them. 
	tst.b	SRC_EX(a0)	* is operand negative?
	smi	d1	* set if so
	move.l	EXC_LV+L_SCR3(a6),d0	* pass: dbl prec,rnd mode
	bsr.l	ovf_res	* calc OVFL result
	fmovem.x	(a0),fp0	* load default overflow result
	fmove.d	fp0,EXC_LV+L_SCR1(a6)	* store to double

	move.l	EXC_LV+EXC_EA(a6),a1	* pass: dst addr
	lea	EXC_LV+L_SCR1(a6),a0	* pass: src addr
	moveq.l	#$8,d0	* pass: opsize is 8 bytes
	bsr.l	_dmem_write	* store dbl fop to memory

	tst.l	d1	* did dstore fail?
	bne.l	facc_out_d	* yes

	move.b	EXC_LV+FPCR_ENABLE(a6),d1
	andi.b	#$0a,d1	* is UNFL or INEX enabled?
	bne.w	fout_sd_EXC_LV+EXC_ovfl	* yes
	addq.l	#$4,sp
	rts

*
* move out MAY overflow:
* (1) force the exp to $3fff
* (2) do a move w/ appropriate rnd mode
* (3) if exp still equals zero, then insert original exponent
*	for the correct result.
*     if exp now equals one, then it overflowed so call ovf_res.
*
fout_dbl_may_ovfl:
	move.w	SRC_EX(a0),d1	* fetch current sign
	andi.w	#$8000,d1	* keep it,clear exp
	ori.w	#$3fff,d1	* insert exp = 0
	move.w	d1,EXC_LV+FP_SCR0_EX(a6)	* insert scaled exp
	move.l	SRC_HI(a0),EXC_LV+FP_SCR0_HI(a6) * copy hi(man)
	move.l	SRC_LO(a0),EXC_LV+FP_SCR0_LO(a6) * copy lo(man)

	fmove.l	EXC_LV+L_SCR3(a6),fpcr	* set FPCR

	fmove.x	EXC_LV+FP_SCR0(a6),fp0	* force fop to be rounded
	fmove.l	#$0,fpcr	* clear FPCR

	fabs.x	fp0	* need absolute value
	fcmp.b	#2,fp0	* did exponent increase?
	fblt.w	fout_dbl_exg	* no; go finish NORM	
	bra.w	fout_dbl_ovfl	* yes; go handle overflow

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	dst_dbl(): create double precision value from extended prec.
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0 = pointer to source operand in extended precision
* 		
* OUTPUT **************************************************************
*	d0 = hi(double precision result)
*	d1 = lo(double precision result)
*		
* ALGORITHM ***********************************************************
*		
*  Changes extended precision to double precision.
*  Note: no attempt is made to round the extended value to double.
*	dbl_sign = ext_sign	
*	dbl_exp = ext_exp - $3fff(ext bias) + $7ff(dbl bias)
*	get rid of ext integer bit	
*	dbl_mant = ext_mant{62:12}	
*		
*	    	---------------   ---------------    ---------------
*  extended ->  |s|    exp    |   |1| ms mant   |    | ls mant     |
*	    	---------------   ---------------    ---------------
*	   	 95	    64    63 62	      32      31     11	  0
*	     |	     |
*	     |	     |
*	     |	     |
*	 	             v   	     v
*	    	      ---------------   ---------------
*  double   ->  	      |s|exp| mant  |   |  mant       |
*	    	      ---------------   ---------------
*	   	 	      63     51   32   31	       0
*		
**-------------------------------------------------------------------------------------------------

dst_dbl:
	clr.l	d0	* clear d0
	move.w	FTEMP_EX(a0),d0	* get exponent
	subi.w	#EXT_BIAS,d0	* subtract extended precision bias
	addi.w	#DBL_BIAS,d0	* add double precision bias
	tst.b	FTEMP_HI(a0)	* is number a denorm?
	bmi.b	dst_get_dupper	* no
	subq.w	#$1,d0	* yes; denorm bias = DBL_BIAS - 1
dst_get_dupper:
	swap	d0	* d0 now in upper word
	lsl.l	#$4,d0	* d0 in proper place for dbl prec exp
	tst.b	FTEMP_EX(a0)	* test sign
	bpl.b	dst_get_dman	* if postive, go process mantissa
	bset	#$1f,d0	* if negative, set sign
dst_get_dman:
	move.l	FTEMP_HI(a0),d1	* get ms mantissa
	bfextu	d1{31:20},d1	* get upper 20 bits of ms
	or.l	d1,d0	* put these bits in ms word of double
	move.l	d0,EXC_LV+L_SCR1(a6)	* put the new exp back on the stack
	move.l	FTEMP_HI(a0),d1	* get ms mantissa
	move.l	#21,d0	* load shift count
	lsl.l	d0,d1	* put lower 11 bits in upper bits
	move.l	d1,EXC_LV+L_SCR2(a6)	* build lower lword in memory
	move.l	FTEMP_LO(a0),d1	* get ls mantissa
	bfextu	d1{0:21},d0	* get ls 21 bits of double
	move.l	EXC_LV+L_SCR2(a6),d1
	or.l	d0,d1	* put them in double result
	move.l	EXC_LV+L_SCR1(a6),d0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	dst_sgl(): create single precision value from extended prec
*		
* xdef **
*		
* INPUT ***************************************************************
*	a0 = pointer to source operand in extended precision
* 		
* OUTPUT **************************************************************
*	d0 = single precision result	
*		
* ALGORITHM ***********************************************************
*		
* Changes extended precision to single precision.
*	sgl_sign = ext_sign	
*	sgl_exp = ext_exp - $3fff(ext bias) + $7f(sgl bias)
*	get rid of ext integer bit	
*	sgl_mant = ext_mant{62:12}	
*		
*	    	---------------   ---------------    ---------------
*  extended ->  |s|    exp    |   |1| ms mant   |    | ls mant     |
*	    	---------------   ---------------    ---------------
*	   	 95	    64    63 62	   40 32      31     12	  0
*	     |	   |
*	     |	   |
*	     |	   |
*	 	             v     v
*	    	      ---------------
*  single   ->  	      |s|exp| mant  |
*	    	      ---------------
*	   	 	      31     22     0
*		
**-------------------------------------------------------------------------------------------------

dst_sgl:
	clr.l	d0
	move.w	FTEMP_EX(a0),d0	* get exponent
	subi.w	#EXT_BIAS,d0	* subtract extended precision bias
	addi.w	#SGL_BIAS,d0	* add single precision bias
	tst.b	FTEMP_HI(a0)	* is number a denorm?
	bmi.b	dst_get_supper	* no
	subq.w	#$1,d0	* yes; denorm bias = SGL_BIAS - 1
dst_get_supper:
	swap	d0	* put exp in upper word of d0
	lsl.l	#$7,d0	* shift it into single exp bits
	tst.b	FTEMP_EX(a0)	* test sign
	bpl.b	dst_get_sman	* if positive, continue
	bset	#$1f,d0	* if negative, put in sign first
dst_get_sman:
	move.l	FTEMP_HI(a0),d1	* get ms mantissa
	andi.l	#$7fffff00,d1	* get upper 23 bits of ms
	lsr.l	#$8,d1	* and put them flush right
	or.l	d1,d0	* put these bits in ms word of single
	rts

**-------------------------------------------------------------------------------------------------*****
fout_pack:
	bsr.l	_calc_ea_fout	* fetch the <ea>
	move.l	a0,-(sp)

	move.b	EXC_LV+STAG(a6),d0	* fetch input type
	bne.w	fout_pack_not_norm	* input is not NORM

fout_pack_norm:
	btst	#$4,EXC_LV+EXC_CMDREG(a6)	* static or dynamic?
	beq.b	fout_pack_s	* static

fout_pack_d:
	move.b	1+EXC_LV+EXC_CMDREG(a6),d1	* fetch dynamic reg
	lsr.b	#$4,d1
	andi.w	#$7,d1

	bsr.l	fetch_dreg	* fetch Dn w/ k-factor

	bra.b	fout_pack_type
fout_pack_s:
	move.b	1+EXC_LV+EXC_CMDREG(a6),d0	* fetch static field

fout_pack_type:
	bfexts	d0{25:7},d0	* extract k-factor
	move.l	d0,-(sp)

	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to input

* bindec is currently scrambling EXC_LV+FP_SRC for denorm inputs.
* we'll have to change this, but for now, tough luck!!!
	bsr.l	bindec	* convert xprec to packed

*	andi.l	#$cfff000f,EXC_LV+FP_SCR0(a6) * clear unused fields
	andi.l	#$cffff00f,EXC_LV+FP_SCR0(a6) * clear unused fields

	move.l	(sp)+,d0

	tst.b	3+EXC_LV+FP_SCR0_EX(a6)
	bne.b	fout_pack_set
	tst.l	EXC_LV+FP_SCR0_HI(a6)
	bne.b	fout_pack_set
	tst.l	EXC_LV+FP_SCR0_LO(a6)
	bne.b	fout_pack_set

* add the extra condition that only if the k-factor was zero, too, should
* we zero the exponent
	tst.l	d0
	bne.b	fout_pack_set	
* "mantissa" is all zero which means that the answer is zero. but, the '040
* algorithm allows the exponent to be non-zero. the 881/2 do not. therefore,
* if the mantissa is zero, I will zero the exponent, too.
* the question now is whether the exponents sign bit is allowed to be non-zero
* for a zero, also...
	andi.w	#$f000,EXC_LV+FP_SCR0(a6)

fout_pack_set:

	lea	EXC_LV+FP_SCR0(a6),a0	* pass: src addr

fout_pack_write:
	move.l	(sp)+,a1	* pass: dst addr
	move.l	#$c,d0	* pass: opsize is 12 bytes

	ICMP.b	EXC_LV+SPCOND_FLG(a6),#mda7_flg
	beq.b	fout_pack_a7

	bsr.l	_dmem_write	* write ext prec number to memory

	tst.l	d1	* did dstore fail?
	bne.w	fout_ext_err	* yes

	rts

* we don't want to do the write if the exception occurred in supervisor mode
* so _mem_write2() handles this for us.
fout_pack_a7:
	bsr.l	_mem_write2	* write ext prec number to memory

	tst.l	d1	* did dstore fail?
	bne.w	fout_ext_err	* yes

	rts

fout_pack_not_norm:
	ICMP.b	d0,#DENORM	* is it a DENORM?
	beq.w	fout_pack_norm	* yes
	lea	EXC_LV+FP_SRC(a6),a0
	clr.w	2+EXC_LV+FP_SRC_EX(a6)
	ICMP.b	d0,#SNAN	* is it an SNAN?
	beq.b	fout_pack_snan	* yes
	bra.b	fout_pack_write	* no

fout_pack_snan:
	ori.w	#snaniop2_mask,EXC_LV+FPSR_EXCEPT(a6) * set SNAN/AIOP
	bset	#$6,EXC_LV+FP_SRC_HI(a6)	* set snan bit
	bra.b	fout_pack_write

**-------------------------------------------------------------------------------------------------
* XDEF **
*	fetch_dreg(): fetch register according to index in d1
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d1 = index of register to fetch from
* 		
* OUTPUT **************************************************************
*	d0 = value of register fetched	
*		
* ALGORITHM ***********************************************************
*	According to the index value in d1 which can range from zero 
* to fifteen, load the corresponding register file value (where 
* address register indexes start at 8). D0/D1/A0/A1/A6/A7 are on the
* stack. The rest should still be in their original places.
*		
**-------------------------------------------------------------------------------------------------

* this routine leaves d1 intact for subsequent store_dreg calls.
	xdef	fetch_dreg
fetch_dreg:
	move.w	((tbl_fdreg).b,pc,d1.w*2),d0
	jmp	((tbl_fdreg).b,pc,d0.w*1)

tbl_fdreg:
	dc.w	fdreg0 - tbl_fdreg
	dc.w	fdreg1 - tbl_fdreg
	dc.w	fdreg2 - tbl_fdreg
	dc.w	fdreg3 - tbl_fdreg
	dc.w	fdreg4 - tbl_fdreg
	dc.w	fdreg5 - tbl_fdreg
	dc.w	fdreg6 - tbl_fdreg
	dc.w	fdreg7 - tbl_fdreg
	dc.w	fdreg8 - tbl_fdreg
	dc.w	fdreg9 - tbl_fdreg
	dc.w	fdrega - tbl_fdreg
	dc.w	fdregb - tbl_fdreg
	dc.w	fdregc - tbl_fdreg
	dc.w	fdregd - tbl_fdreg
	dc.w	fdrege - tbl_fdreg
	dc.w	fdregf - tbl_fdreg

fdreg0:
	move.l	EXC_LV+EXC_DREGS+$0(a6),d0
	rts
fdreg1:
	move.l	EXC_LV+EXC_DREGS+$4(a6),d0
	rts
fdreg2:
	move.l	d2,d0
	rts
fdreg3:
	move.l	d3,d0
	rts
fdreg4:
	move.l	d4,d0
	rts
fdreg5:
	move.l	d5,d0
	rts
fdreg6:
	move.l	d6,d0
	rts
fdreg7:
	move.l	d7,d0
	rts
fdreg8:
	move.l	EXC_LV+EXC_DREGS+$8(a6),d0
	rts
fdreg9:
	move.l	EXC_LV+EXC_DREGS+$c(a6),d0
	rts
fdrega:
	move.l	a2,d0
	rts
fdregb:
	move.l	a3,d0
	rts
fdregc:
	move.l	a4,d0
	rts
fdregd:
	move.l	a5,d0
	rts
fdrege:
	move.l	(a6),d0
	rts
fdregf:
	move.l	EXC_LV+EXC_A7(a6),d0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	store_dreg_l(): store longword to data register specified by d1
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = longowrd value to store	
*	d1 = index of register to fetch from
* 		
* OUTPUT **************************************************************
*	(data register is updated)	
*		
* ALGORITHM ***********************************************************
*	According to the index value in d1, store the longword value
* in d0 to the corresponding data register. D0/D1 are on the stack
* while the rest are in their initial places.
*		
**-------------------------------------------------------------------------------------------------

	xdef	store_dreg_l
store_dreg_l:
	move.w	((tbl_sdregl).b,pc,d1.w*2),d1
	jmp	((tbl_sdregl).b,pc,d1.w*1)

tbl_sdregl:
	dc.w	sdregl0 - tbl_sdregl
	dc.w	sdregl1 - tbl_sdregl
	dc.w	sdregl2 - tbl_sdregl
	dc.w	sdregl3 - tbl_sdregl
	dc.w	sdregl4 - tbl_sdregl
	dc.w	sdregl5 - tbl_sdregl
	dc.w	sdregl6 - tbl_sdregl
	dc.w	sdregl7 - tbl_sdregl

sdregl0:
	move.l	d0,EXC_LV+EXC_DREGS+$0(a6)
	rts
sdregl1:
	move.l	d0,EXC_LV+EXC_DREGS+$4(a6)
	rts
sdregl2:
	move.l	d0,d2
	rts
sdregl3:
	move.l	d0,d3
	rts
sdregl4:
	move.l	d0,d4
	rts
sdregl5:
	move.l	d0,d5
	rts
sdregl6:
	move.l	d0,d6
	rts
sdregl7:
	move.l	d0,d7
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	store_dreg_w(): store word to data register specified by d1
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = word value to store	
*	d1 = index of register to fetch from
* 		
* OUTPUT **************************************************************
*	(data register is updated)	
*		
* ALGORITHM ***********************************************************
*	According to the index value in d1, store the word value
* in d0 to the corresponding data register. D0/D1 are on the stack
* while the rest are in their initial places.
*		
**-------------------------------------------------------------------------------------------------

	xdef	store_dreg_w
store_dreg_w:
	move.w	((tbl_sdregw).b,pc,d1.w*2),d1
	jmp	((tbl_sdregw).b,pc,d1.w*1)

tbl_sdregw:
	dc.w	sdregw0 - tbl_sdregw
	dc.w	sdregw1 - tbl_sdregw
	dc.w	sdregw2 - tbl_sdregw
	dc.w	sdregw3 - tbl_sdregw
	dc.w	sdregw4 - tbl_sdregw
	dc.w	sdregw5 - tbl_sdregw
	dc.w	sdregw6 - tbl_sdregw
	dc.w	sdregw7 - tbl_sdregw

sdregw0:
	move.w	d0,2+EXC_LV+EXC_DREGS+$0(a6)
	rts
sdregw1:
	move.w	d0,2+EXC_LV+EXC_DREGS+$4(a6)
	rts
sdregw2:
	move.w	d0,d2
	rts
sdregw3:
	move.w	d0,d3
	rts
sdregw4:
	move.w	d0,d4
	rts
sdregw5:
	move.w	d0,d5
	rts
sdregw6:
	move.w	d0,d6
	rts
sdregw7:
	move.w	d0,d7
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	store_dreg_b(): store byte to data register specified by d1
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = byte value to store	
*	d1 = index of register to fetch from
* 		
* OUTPUT **************************************************************
*	(data register is updated)	
*		
* ALGORITHM ***********************************************************
*	According to the index value in d1, store the byte value
* in d0 to the corresponding data register. D0/D1 are on the stack
* while the rest are in their initial places.
*		
**-------------------------------------------------------------------------------------------------

	xdef	store_dreg_b
store_dreg_b:
	move.w	((tbl_sdregb).b,pc,d1.w*2),d1
	jmp	((tbl_sdregb).b,pc,d1.w*1)

tbl_sdregb:
	dc.w	sdregb0 - tbl_sdregb
	dc.w	sdregb1 - tbl_sdregb
	dc.w	sdregb2 - tbl_sdregb
	dc.w	sdregb3 - tbl_sdregb
	dc.w	sdregb4 - tbl_sdregb
	dc.w	sdregb5 - tbl_sdregb
	dc.w	sdregb6 - tbl_sdregb
	dc.w	sdregb7 - tbl_sdregb

sdregb0:
	move.b	d0,3+EXC_LV+EXC_DREGS+$0(a6)
	rts
sdregb1:
	move.b	d0,3+EXC_LV+EXC_DREGS+$4(a6)
	rts
sdregb2:
	move.b	d0,d2
	rts
sdregb3:
	move.b	d0,d3
	rts
sdregb4:
	move.b	d0,d4
	rts
sdregb5:
	move.b	d0,d5
	rts
sdregb6:
	move.b	d0,d6
	rts
sdregb7:
	move.b	d0,d7
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	inc_areg(): increment an address register by the value in d0
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = amount to increment by	
*	d1 = index of address register to increment
* 		
* OUTPUT **************************************************************
*	(address register is updated)	
*		
* ALGORITHM ***********************************************************
* 	Typically used for an instruction w/ a post-increment <ea>, 
* this routine adds the increment value in d0 to the address register
* specified by d1. A0/A1/A6/A7 reside on the stack. The rest reside
* in their original places.	
* 	For a7, if the increment amount is one, then we have to 
* increment by two. For any a7 update, set the mia7_flag so that if
* an access error exception occurs later in emulation, this address
* register update can be undone.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	inc_areg
inc_areg:
	move.w	((tbl_iareg).b,pc,d1.w*2),d1
	jmp	((tbl_iareg).b,pc,d1.w*1)

tbl_iareg:
	dc.w	iareg0 - tbl_iareg
	dc.w	iareg1 - tbl_iareg
	dc.w	iareg2 - tbl_iareg
	dc.w	iareg3 - tbl_iareg
	dc.w	iareg4 - tbl_iareg
	dc.w	iareg5 - tbl_iareg
	dc.w	iareg6 - tbl_iareg
	dc.w	iareg7 - tbl_iareg

iareg0:	add.l	d0,EXC_LV+EXC_DREGS+$8(a6)
	rts
iareg1:	add.l	d0,EXC_LV+EXC_DREGS+$c(a6)
	rts
iareg2:	add.l	d0,a2
	rts
iareg3:	add.l	d0,a3
	rts
iareg4:	add.l	d0,a4
	rts
iareg5:	add.l	d0,a5
	rts
iareg6:	add.l	d0,(a6)
	rts
iareg7:	move.b	#mia7_flg,EXC_LV+SPCOND_FLG(a6)
	ICMP.b	d0,#$1
	beq.b	iareg7b
	add.l	d0,EXC_LV+EXC_A7(a6)
	rts
iareg7b:
	addq.l	#$2,EXC_LV+EXC_A7(a6)
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	dec_areg(): decrement an address register by the value in d0
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = amount to decrement by	
*	d1 = index of address register to decrement
* 		
* OUTPUT **************************************************************
*	(address register is updated)	
*		
* ALGORITHM ***********************************************************
* 	Typically used for an instruction w/ a pre-decrement <ea>, 
* this routine adds the decrement value in d0 to the address register
* specified by d1. A0/A1/A6/A7 reside on the stack. The rest reside
* in their original places.	
* 	For a7, if the decrement amount is one, then we have to 
* decrement by two. For any a7 update, set the mda7_flag so that if
* an access error exception occurs later in emulation, this address
* register update can be undone.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	dec_areg
dec_areg:
	move.w	((tbl_dareg).b,pc,d1.w*2),d1
	jmp	((tbl_dareg).b,pc,d1.w*1)

tbl_dareg:
	dc.w	dareg0 - tbl_dareg
	dc.w	dareg1 - tbl_dareg
	dc.w	dareg2 - tbl_dareg
	dc.w	dareg3 - tbl_dareg
	dc.w	dareg4 - tbl_dareg
	dc.w	dareg5 - tbl_dareg
	dc.w	dareg6 - tbl_dareg
	dc.w	dareg7 - tbl_dareg

dareg0:	sub.l	d0,EXC_LV+EXC_DREGS+$8(a6)
	rts
dareg1:	sub.l	d0,EXC_LV+EXC_DREGS+$c(a6)
	rts
dareg2:	sub.l	d0,a2
	rts
dareg3:	sub.l	d0,a3
	rts
dareg4:	sub.l	d0,a4
	rts
dareg5:	sub.l	d0,a5
	rts
dareg6:	sub.l	d0,(a6)
	rts
dareg7:	move.b	#mda7_flg,EXC_LV+SPCOND_FLG(a6)
	ICMP.b	d0,#$1
	beq.b	dareg7b
	sub.l	d0,EXC_LV+EXC_A7(a6)
	rts
dareg7b:
	subq.l	#$2,EXC_LV+EXC_A7(a6)
	rts

**-------------------------------------------------------------------------------------------------*****

**-------------------------------------------------------------------------------------------------
* XDEF **
*	load_fpn1(): load FP register value into EXC_LV+FP_SRC(a6).
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = index of FP register to load
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_SRC(a6) = value loaded from FP register file
*		
* ALGORITHM ***********************************************************
*	Using the index in d0, load EXC_LV+FP_SRC(a6) with a number from the 
* FP register file.	
*		
**-------------------------------------------------------------------------------------------------

	xdef 	load_fpn1
load_fpn1:
	move.w	((tbl_load_fpn1).b,pc,d0.w*2), d0
	jmp	((tbl_load_fpn1).b,pc,d0.w*1)

tbl_load_fpn1:
	dc.w	load_fpn1_0 - tbl_load_fpn1
	dc.w	load_fpn1_1 - tbl_load_fpn1
	dc.w	load_fpn1_2 - tbl_load_fpn1
	dc.w	load_fpn1_3 - tbl_load_fpn1
	dc.w	load_fpn1_4 - tbl_load_fpn1
	dc.w	load_fpn1_5 - tbl_load_fpn1
	dc.w	load_fpn1_6 - tbl_load_fpn1
	dc.w	load_fpn1_7 - tbl_load_fpn1

load_fpn1_0:
	move.l	0+EXC_LV+EXC_FP0(a6), 0+EXC_LV+FP_SRC(a6)
	move.l	4+EXC_LV+EXC_FP0(a6), 4+EXC_LV+FP_SRC(a6)
	move.l	8+EXC_LV+EXC_FP0(a6), 8+EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_1:
	move.l	0+EXC_LV+EXC_FP1(a6), 0+EXC_LV+FP_SRC(a6)
	move.l	4+EXC_LV+EXC_FP1(a6), 4+EXC_LV+FP_SRC(a6)
	move.l	8+EXC_LV+EXC_FP1(a6), 8+EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_2:
	fmovem.x	fp2, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_3:
	fmovem.x	fp3, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_4:
	fmovem.x	fp4, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_5:
	fmovem.x	fp5, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_6:
	fmovem.x	fp6, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts
load_fpn1_7:
	fmovem.x	fp7, EXC_LV+FP_SRC(a6)
	lea	EXC_LV+FP_SRC(a6), a0
	rts

**-------------------------------------------------------------------------------------------------****

**-------------------------------------------------------------------------------------------------
* XDEF **
*	load_fpn2(): load FP register value into EXC_LV+FP_DST(a6).
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	d0 = index of FP register to load
* 		
* OUTPUT **************************************************************
*	EXC_LV+FP_DST(a6) = value loaded from FP register file
*		
* ALGORITHM ***********************************************************
*	Using the index in d0, load EXC_LV+FP_DST(a6) with a number from the 
* FP register file.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	load_fpn2
load_fpn2:
	move.w	((tbl_load_fpn2).b,pc,d0.w*2), d0
	jmp	((tbl_load_fpn2).b,pc,d0.w*1)

tbl_load_fpn2:
	dc.w	load_fpn2_0 - tbl_load_fpn2
	dc.w	load_fpn2_1 - tbl_load_fpn2
	dc.w	load_fpn2_2 - tbl_load_fpn2
	dc.w	load_fpn2_3 - tbl_load_fpn2
	dc.w	load_fpn2_4 - tbl_load_fpn2
	dc.w	load_fpn2_5 - tbl_load_fpn2
	dc.w	load_fpn2_6 - tbl_load_fpn2
	dc.w	load_fpn2_7 - tbl_load_fpn2

load_fpn2_0:
	move.l	0+EXC_LV+EXC_FP0(a6), 0+EXC_LV+FP_DST(a6)
	move.l	4+EXC_LV+EXC_FP0(a6), 4+EXC_LV+FP_DST(a6)
	move.l	8+EXC_LV+EXC_FP0(a6), 8+EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_1:
	move.l	0+EXC_LV+EXC_FP1(a6), 0+EXC_LV+FP_DST(a6)
	move.l	4+EXC_LV+EXC_FP1(a6), 4+EXC_LV+FP_DST(a6)
	move.l	8+EXC_LV+EXC_FP1(a6), 8+EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_2:
	fmovem.x	fp2, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_3:
	fmovem.x	fp3, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_4:
	fmovem.x	fp4, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_5:
	fmovem.x	fp5, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_6:
	fmovem.x	fp6, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts
load_fpn2_7:
	fmovem.x	fp7, EXC_LV+FP_DST(a6)
	lea	EXC_LV+FP_DST(a6), a0
	rts

**-------------------------------------------------------------------------------------------------****

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	store_fpreg(): store an fp value to the fpreg designated d0.
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	fp0 = extended precision value to store
*	d0  = index of floating-point register
* 		
* OUTPUT **************************************************************
*	None	
*		
* ALGORITHM ***********************************************************
*	Store the value in fp0 to the FP register designated by the
* value in d0. The FP number can be DENORM or SNAN so we have to be
* careful that we don't take an exception here.
*		
**-------------------------------------------------------------------------------------------------

	xdef	store_fpreg
store_fpreg:
	move.w	((tbl_store_fpreg).b,pc,d0.w*2), d0
	jmp	((tbl_store_fpreg).b,pc,d0.w*1)

tbl_store_fpreg:
	dc.w	store_fpreg_0 - tbl_store_fpreg
	dc.w	store_fpreg_1 - tbl_store_fpreg
	dc.w	store_fpreg_2 - tbl_store_fpreg
	dc.w	store_fpreg_3 - tbl_store_fpreg
	dc.w	store_fpreg_4 - tbl_store_fpreg
	dc.w	store_fpreg_5 - tbl_store_fpreg
	dc.w	store_fpreg_6 - tbl_store_fpreg
	dc.w	store_fpreg_7 - tbl_store_fpreg

store_fpreg_0:
	fmovem.x	fp0, EXC_LV+EXC_FP0(a6)
	rts
store_fpreg_1:
	fmovem.x	fp0, EXC_LV+EXC_FP1(a6)
	rts
store_fpreg_2:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp2
	rts
store_fpreg_3:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp3
	rts
store_fpreg_4:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp4
	rts
store_fpreg_5:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp5
	rts
store_fpreg_6:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp6
	rts
store_fpreg_7:
	fmovem.x 	fp7, -(sp)
	fmovem.x	(sp)+, fp7
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	_denorm(): denormalize an intermediate result
*		
* xdef **
*	None	
*		
* INPUT *************************************************************** *
*	a0 = points to the operand to be denormalized
*	(in the internal extended format)
*	 	
*	d0 = rounding precision	
*		
* OUTPUT **************************************************************
*	a0 = pointer to the denormalized result
*	(in the internal extended format)
*		
*	d0 = guard,round,sticky	
*		
* ALGORITHM ***********************************************************
* 	According to the exponent underflow threshold for the given
* precision, shift the mantissa bits to the right in order raise the
* exponent of the operand to the threshold value. While shifting the 
* mantissa bits right, maintain the value of the guard, round, and 
* sticky bits.	
* other notes:	
*	(1) _denorm() is called by the underflow routines
*	(2) _denorm() does NOT affect the status register
*		
**-------------------------------------------------------------------------------------------------

*
* table of exponent threshold values for each precision
*
tbl_thresh:
	dc.w	$0
	dc.w	sgl_thresh
	dc.w	dbl_thresh

	xdef	_denorm
_denorm:
*
* Load the exponent threshold for the precision selected and check
* to see if (threshold - exponent) is > 65 in which case we can 
* simply calculate the sticky bit and zero the mantissa. otherwise
* we have to call the denormalization routine.
*
	lsr.b	#$2, d0	* shift prec to lo bits
	move.w	((tbl_thresh).b,pc,d0.w*2), d1 * load prec threshold
	move.w	d1, d0	* copy d1 into d0
	sub.w	FTEMP_EX(a0), d0	* diff = threshold - exp
	ICMP.w	d0, #66	* is diff > 65? (mant + g,r bits)
	bpl.b	denorm_set_stky	* yes; just calc sticky

	clr.l	d0	* clear g,r,s
	btst	#inex2_bit, EXC_LV+FPSR_EXCEPT(a6) * yes; was INEX2 set?
	beq.b	denorm_call	* no; don't change anything
	bset	#29, d0	* yes; set sticky bit

denorm_call:
	bsr.l	dnrm_lp	* denormalize the number
	rts

*
* all bit would have been shifted off during the denorm so simply
* calculate if the sticky should be set and clear the entire mantissa.
*
denorm_set_stky:
	move.l	#$20000000, d0	* set sticky bit in return value
	move.w	d1, FTEMP_EX(a0)	* load exp with threshold
	clr.l	FTEMP_HI(a0)	* set d1 = 0 (ms mantissa)
	clr.l	FTEMP_LO(a0)	* set d2 = 0 (ms mantissa)
	rts

*		
* dnrm_lp(): normalize exponent/mantissa to specified threshhold
*		
* INPUT:	
*	a0	   : points to the operand to be denormalized
*	d0{31:29} : initial guard,round,sticky
*	d1{15:0}  : denormalization threshold
* OUTPUT:	
*	a0	   : points to the denormalized operand	 
*	d0{31:29} : final guard,round,sticky
*		

* *** Local Equates *** *
GRS	equ	EXC_LV+L_SCR2	* g,r,s temp storage
FTEMP_LO2	equ	EXC_LV+L_SCR1	* FTEMP_LO copy

	xdef	dnrm_lp
dnrm_lp:

*
* make a copy of FTEMP_LO and place the g,r,s bits directly after it
* in memory so as to make the bitfield extraction for denormalization easier.
*
	move.l	FTEMP_LO(a0), FTEMP_LO2(a6) * make FTEMP_LO copy
	move.l	d0, GRS(a6)	* place g,r,s after it

*
* check to see how much less than the underflow threshold the operand
* exponent is. 
*
	move.l	d1, d0	* copy the denorm threshold
	sub.w	FTEMP_EX(a0), d1	* d1 = threshold - uns exponent
	ble.b	dnrm_no_lp	* d1 <= 0
	ICMP.w	d1,#$20	* is ( 0 <= d1 < 32) ?
	blt.b	case_1	* yes
	ICMP.w	d1,#$40	* is (32 <= d1 < 64) ?
	blt.b	case_2	* yes
	bra.w	case_3	* (d1 >= 64)

*
* No normalization necessary
*
dnrm_no_lp:
	move.l	GRS(a6), d0 	* restore original g,r,s
	rts

*
* case (0<d1<32)
*
* d0 = denorm threshold
* d1 = "n" = amt to shift
*
*	---------------------------------------------------------
*	|     FTEMP_HI	  |    	FTEMP_LO     |grs000.........000|
*	---------------------------------------------------------
*	<-(32 - n)-><-(n)-><-(32 - n)-><-(n)-><-(32 - n)-><-(n)->
*	\	   \	      \	 \
*	 \	    \	       \	  \
*	  \	     \	\	   \
*	   \	      \	 \	    \
*	    \	       \	  \	     \
*	     \	\	   \	      \
*	      \	 \	    \	       \
*	       \	  \	     \	\
*	<-(n)-><-(32 - n)-><------(32)-------><------(32)------->	
*	---------------------------------------------------------
*	|0.....0| NEW_HI  |  NEW_FTEMP_LO     |grs	|
*	---------------------------------------------------------
*
case_1:
	move.l	d2, -(sp)	* create temp storage

	move.w	d0, FTEMP_EX(a0)	* exponent = denorm threshold
	move.l	#32, d0
	sub.w	d1, d0	* d0 = 32 - d1

	ICMP.w	d1, #29	* is shft amt >= 29
	blt.b	case1_extract	* no; no fix needed
	move.b	GRS(a6), d2
	or.b	d2, 3+FTEMP_LO2(a6)

case1_extract:
	bfextu	FTEMP_HI(a0){0:20}, d2 * d2 = new FTEMP_HI
	bfextu	FTEMP_HI(a0){0:32}, d1 * d1 = new FTEMP_LO
	bfextu	FTEMP_LO2(a6){0:32}, d0 * d0 = new G,R,S

	move.l	d2, FTEMP_HI(a0)	* store new FTEMP_HI
	move.l	d1, FTEMP_LO(a0)	* store new FTEMP_LO

	bftst	d0{2:30}	* were bits shifted off?
	beq.b	case1_sticky_clear	* no; go finish
	bset	#rnd_stky_bit, d0	* yes; set sticky bit

case1_sticky_clear:
	and.l	#$e0000000, d0	* clear all but G,R,S
	move.l	(sp)+, d2	* restore temp register
	rts

*
* case (32<=d1<64)
*
* d0 = denorm threshold
* d1 = "n" = amt to shift
*
*	---------------------------------------------------------
*	|     FTEMP_HI	  |    	FTEMP_LO     |grs000.........000|
*	---------------------------------------------------------
*	<-(32 - n)-><-(n)-><-(32 - n)-><-(n)-><-(32 - n)-><-(n)->
*	\	   \	      \
*	 \	    \	       \
*	  \	     \	-------------------
*	   \	      --------------------	   \
*	    -------------------	  	  \	    \
*	     	       \	   \	     \
*	      	 	\     	    \	      \
*	       	  	 \	     \	       \
*	<-------(32)------><-(n)-><-(32 - n)-><------(32)------->
*	---------------------------------------------------------
*	|0...............0|0....0| NEW_LO     |grs	|
*	---------------------------------------------------------
*
case_2:
	move.l	d2, -(sp)	* create temp storage

	move.w	d0, FTEMP_EX(a0)	* exponent = denorm threshold
	subi.w	#$20, d1	* d1 now between 0 and 32
	move.l	#$20, d0
	sub.w	d1, d0	* d0 = 32 - d1

* subtle step here; or in the g,r,s at the bottom of FTEMP_LO to minimize
* the number of bits to check for the sticky detect.
* it only plays a role in shift amounts of 61-63.
	move.b	GRS(a6), d2
	or.b	d2, 3+FTEMP_LO2(a6)

	bfextu	FTEMP_HI(a0){0:20}, d2 * d2 = new FTEMP_LO
	bfextu	FTEMP_HI(a0){20:32}, d1 * d1 = new G,R,S

	bftst	d1{2:30}	* were any bits shifted off?
	bne.b	case2_set_sticky	* yes; set sticky bit
	bftst	FTEMP_LO2(a6){d0:31}	* were any bits shifted off?
	bne.b	case2_set_sticky	* yes; set sticky bit

	move.l	d1, d0	* move new G,R,S to d0
	bra.b	case2_end

case2_set_sticky:
	move.l	d1, d0	* move new G,R,S to d0
	bset	#rnd_stky_bit, d0	* set sticky bit

case2_end:
	clr.l	FTEMP_HI(a0)	* store FTEMP_HI = 0
	move.l	d2, FTEMP_LO(a0)	* store FTEMP_LO
	and.l	#$e0000000, d0	* clear all but G,R,S

	move.l	(sp)+,d2	* restore temp register
	rts

*
* case (d1>=64)
*
* d0 = denorm threshold
* d1 = amt to shift
*
case_3:
	move.w	d0, FTEMP_EX(a0)	* insert denorm threshold

	ICMP.w	d1, #65	* is shift amt > 65?
	blt.b	case3_64	* no; it's == 64
	beq.b	case3_65	* no; it's == 65

*
* case (d1>65)
*
* Shift value is > 65 and out of range. All bits are shifted off.
* Return a zero mantissa with the sticky bit set
*
	clr.l	FTEMP_HI(a0)	* clear hi(mantissa)
	clr.l	FTEMP_LO(a0)	* clear lo(mantissa)
	move.l	#$20000000, d0	* set sticky bit
	rts

*
* case (d1 == 64)
*
*	---------------------------------------------------------
*	|     FTEMP_HI	  |    	FTEMP_LO     |grs000.........000|
*	---------------------------------------------------------
*	<-------(32)------>
*	\	   	   \
*	 \	    	    \
*	  \	     	     \
*	   \	      	      ------------------------------
*	    -------------------------------	    \
*	     	       	   \	     \
*	      	 	     	    \	      \
*	       	  	 	     \	       \
*		      <-------(32)------>
*	---------------------------------------------------------
*	|0...............0|0................0|grs	|
*	---------------------------------------------------------
*
case3_64:
	move.l	FTEMP_HI(a0), d0	* fetch hi(mantissa)
	move.l	d0, d1	* make a copy
	and.l	#$c0000000, d0	* extract G,R
	and.l	#$3fffffff, d1	* extract other bits

	bra.b	case3_complete

*
* case (d1 == 65)
*
*	---------------------------------------------------------
*	|     FTEMP_HI	  |    	FTEMP_LO     |grs000.........000|
*	---------------------------------------------------------
*	<-------(32)------>
*	\	   	   \
*	 \	    	    \
*	  \	     	     \
*	   \	      	      ------------------------------
*	    --------------------------------	    \
*	     	       	    \	     \
*	      	 	     	     \	      \
*	       	  	 	      \	       \
*		       <-------(31)----->
*	---------------------------------------------------------
*	|0...............0|0................0|0rs	|
*	---------------------------------------------------------
*
case3_65:
	move.l	FTEMP_HI(a0), d0	* fetch hi(mantissa)
	and.l	#$80000000, d0	* extract R bit
	lsr.l	#$1, d0	* shift high bit into R bit
	and.l	#$7fffffff, d1	* extract other bits

case3_complete:
* last operation done was an "and" of the bits shifted off so the condition
* codes are already set so branch accordingly.
	bne.b	case3_set_sticky	* yes; go set new sticky
	tst.l	FTEMP_LO(a0)	* were any bits shifted off?
	bne.b	case3_set_sticky	* yes; go set new sticky
	tst.b	GRS(a6)	* were any bits shifted off?
	bne.b	case3_set_sticky	* yes; go set new sticky

*
* no bits were shifted off so don't set the sticky bit.
* the guard and
* the entire mantissa is zero.
*
	clr.l	FTEMP_HI(a0)	* clear hi(mantissa)
	clr.l	FTEMP_LO(a0)	* clear lo(mantissa)
	rts

*
* some bits were shifted off so set the sticky bit.
* the entire mantissa is zero.
*
case3_set_sticky:
	bset	#rnd_stky_bit,d0	* set new sticky bit
	clr.l	FTEMP_HI(a0)	* clear hi(mantissa)
	clr.l	FTEMP_LO(a0)	* clear lo(mantissa)
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	_round(): round result according to precision/mode
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0	  = ptr to input operand in internal extended format 
*	d1(hi)    = contains rounding precision:
*	ext = $000$xxx	
*	sgl = $0004xxxx	
*	dbl = $0008xxxx	
*	d1(lo)	  = contains rounding mode:
*	RN  = $xxxx0000	
*	RZ  = $xxxx0001	
*	RM  = $xxxx0002	
*	RP  = $xxxx0003	
*	d0{31:29} = contains the g,r,s bits (extended)
*		
* OUTPUT **************************************************************
*	a0 = pointer to rounded result	
*		
* ALGORITHM ***********************************************************
*	On return the value pointed to by a0 is correctly rounded,
*	a0 is preserved and the g-r-s bits in d0 are cleared.
*	The result is not typed - the tag field is invalid.  The
*	result is still in the internal extended format.
*		
*	The INEX bit of USER_FPSR will be set if the rounded result was
*	inexact (i.e. if any of the g-r-s bits were set).
*		
**-------------------------------------------------------------------------------------------------

	xdef	_round
_round:
*
* ext_grs() looks at the rounding precision and sets the appropriate
* G,R,S bits.
* If (G,R,S == 0) then result is exact and round is done, else set 
* the inex flag in status reg and continue.
*
	bsr.l	ext_grs	* extract G,R,S

	tst.l	d0	* are G,R,S zero?
	beq.w	truncate	* yes; round is complete

	or.w	#inx2a_mask, 2+EXC_LV+USER_FPSR(a6) * set inex2/ainex

*
* Use rounding mode as an index into a jump table for these modes.
* All of the following assumes grs != 0.
*
	move.w	((tbl_mode).b,pc,d1.w*2), a1 * load jump offset
	jmp	((tbl_mode).b,pc,a1)	* jmp to rnd mode handler

tbl_mode:
	dc.w	rnd_near - tbl_mode
	dc.w	truncate - tbl_mode	* RZ always truncates
	dc.w	rnd_mnus - tbl_mode
	dc.w	rnd_plus - tbl_mode

***
*	ROUND PLUS INFINITY	
*	
*	If sign of fp number = 0 (positive), then add 1 to l.
***
rnd_plus:
	tst.b	FTEMP_SGN(a0)	* check for sign
	bmi.w	truncate	* if positive then truncate

	move.l	#$ffffffff, d0	* force g,r,s to be all f's
	swap	d1	* set up d1 for round prec.

	ICMP.b	d1, #s_mode	* is prec = sgl?
	beq.w	add_sgl	* yes
	bgt.w	add_dbl	* no; it's dbl
	bra.w	add_ext	* no; it's ext

***
*	ROUND MINUS INFINITY	
*	
*	If sign of fp number = 1 (negative), then add 1 to l.
***
rnd_mnus:
	tst.b	FTEMP_SGN(a0)	* check for sign	
	bpl.w	truncate	* if negative then truncate

	move.l	#$ffffffff, d0	* force g,r,s to be all f's
	swap	d1	* set up d1 for round prec.

	ICMP.b	d1, #s_mode	* is prec = sgl?
	beq.w	add_sgl	* yes
	bgt.w	add_dbl	* no; it's dbl
	bra.w	add_ext	* no; it's ext

***
*	ROUND NEAREST	
*	
*	If (g=1), then add 1 to l and if (r=s=0), then clear l
*	Note that this will round to even in case of a tie.
***
rnd_near:
	asl.l	#$1, d0	* shift g-bit to c-bit
	bcc.w	truncate	* if (g=1) then

	swap	d1	* set up d1 for round prec.

	ICMP.b	d1, #s_mode	* is prec = sgl?
	beq.w	add_sgl	* yes
	bgt.w	add_dbl	* no; it's dbl
	bra.w	add_ext	* no; it's ext

* *** LOCAL EQUATES ***
ad_1_sgl	equ	$00000100	* constant to add 1 to l-bit in sgl prec
ad_1_dbl	equ	$00000800	* constant to add 1 to l-bit in dbl prec

*************************
*	ADD SINGLE
*************************
add_sgl:
	add.l	#ad_1_sgl, FTEMP_HI(a0)
	bcc.b	scc_clr	* no mantissa overflow
	roxr.w	FTEMP_HI(a0)	* shift v-bit back in
	roxr.w	FTEMP_HI+2(a0)	* shift v-bit back in
	add.w	#$1, FTEMP_EX(a0)	* and incr exponent
scc_clr:
	tst.l	d0	* test for rs = 0
	bne.b	sgl_done
	and.w	#$fe00, FTEMP_HI+2(a0) * clear the l-bit
sgl_done:
	and.l	#$ffffff00, FTEMP_HI(a0) * truncate bits beyond sgl limit
	clr.l	FTEMP_LO(a0)	* clear d2
	rts

*************************
*	ADD EXTENDED
*************************
add_ext:
	addq.l	#1,FTEMP_LO(a0)	* add 1 to l-bit
	bcc.b	xcc_clr	* test for carry out
	addq.l	#1,FTEMP_HI(a0)	* propogate carry
	bcc.b	xcc_clr
	roxr.w	FTEMP_HI(a0)	* mant is 0 so restore v-bit
	roxr.w	FTEMP_HI+2(a0)	* mant is 0 so restore v-bit
	roxr.w	FTEMP_LO(a0)
	roxr.w	FTEMP_LO+2(a0)
	add.w	#$1,FTEMP_EX(a0)	* and inc exp
xcc_clr:
	tst.l	d0	* test rs = 0
	bne.b	add_ext_done
	and.b	#$fe,FTEMP_LO+3(a0)	* clear the l bit
add_ext_done:
	rts

*************************
*	ADD DOUBLE
*************************
add_dbl:
	add.l	#ad_1_dbl, FTEMP_LO(a0) * add 1 to lsb
	bcc.b	dcc_clr	* no carry
	addq.l	#$1, FTEMP_HI(a0)	* propogate carry
	bcc.b	dcc_clr	* no carry

	roxr.w	FTEMP_HI(a0)	* mant is 0 so restore v-bit
	roxr.w	FTEMP_HI+2(a0)	* mant is 0 so restore v-bit
	roxr.w	FTEMP_LO(a0)
	roxr.w	FTEMP_LO+2(a0)
	addq.w	#$1, FTEMP_EX(a0)	* incr exponent
dcc_clr:
	tst.l	d0	* test for rs = 0
	bne.b	dbl_done
	and.w	#$f000, FTEMP_LO+2(a0) * clear the l-bit

dbl_done:
	and.l	#$fffff800,FTEMP_LO(a0) * truncate bits beyond dbl limit
	rts

***************************
* Truncate all other bits *
***************************
truncate:
	swap	d1	* select rnd prec

	ICMP.b	d1, #s_mode	* is prec sgl?
	beq.w	sgl_done	* yes
	bgt.b	dbl_done	* no; it's dbl
	rts		* no; it's ext


*
* ext_grs(): extract guard, round and sticky bits according to
*	     rounding precision.
*
* INPUT
*	d0	   = extended precision g,r,s (in d0{31:29})
*	d1 	   = {PREC,ROUND}
* OUTPUT
*	d0{31:29}  = guard, round, sticky
*
* The ext_grs extract the guard/round/sticky bits according to the
* selected rounding precision. It is called by the round subroutine
* only.  All registers except d0 are kept intact. d0 becomes an
* updated guard,round,sticky in d0{31:29}
*
* Notes: the ext_grs uses the round PREC, and therefore has to swap d1
*	 prior to usage, and needs to restore d1 to original. this
*	 routine is tightly tied to the round routine and not meant to
*	 uphold standard subroutine calling practices.
*

ext_grs:
	swap	d1	* have d1.w point to round precision
	tst.b	d1	* is rnd prec = extended?
	bne.b	ext_grs_not_ext	* no; go handle sgl or dbl

*
* d0 actually already hold g,r,s since _round() had it before calling
* this function. so, as dc.l as we don't disturb it, we are "returning" it.
*
ext_grs_ext:
	swap	d1	* yes; return to correct positions
	rts

ext_grs_not_ext:
	movem.l	d2-d3, -(sp)	* make some temp registers {d2/d3}

	ICMP.b	d1, #s_mode	* is rnd prec = sgl?
	bne.b	ext_grs_dbl	* no; go handle dbl

*
* sgl:
*	96	64	  40	32	0
*	-----------------------------------------------------
*	| EXP	|XXXXXXX|	  |xx	|	|grs|
*	-----------------------------------------------------
*	<--(24)--->nn\	   /
*	   ee ---------------------
*	   ww	|
*		v
*	   gr	   new sticky
*
ext_grs_sgl:
	bfextu	FTEMP_HI(a0){24:2}, d3 * sgl prec. g-r are 2 bits right
	move.l	#30, d2	* of the sgl prec. limits
	lsl.l	d2, d3	* shift g-r bits to MSB of d3
	move.l	FTEMP_HI(a0), d2	* get word 2 for s-bit test
	and.l	#$0000003f, d2	* s bit is the or of all other 
	bne.b	ext_grs_st_stky	* bits to the right of g-r
	tst.l	FTEMP_LO(a0)	* test lower mantissa
	bne.b	ext_grs_st_stky	* if any are set, set sticky
	tst.l	d0	* test original g,r,s
	bne.b	ext_grs_st_stky	* if any are set, set sticky
	bra.b	ext_grs_end_sd	* if words 3 and 4 are clr, exit

*
* dbl:
*	96	64	  	32	 11	0
*	-----------------------------------------------------
*	| EXP	|XXXXXXX|	  	|	 |xx	|grs|
*	-----------------------------------------------------
*		  nn\	    /
*		  ee -------
*		  ww	|
*		v
*		  gr	new sticky
*
ext_grs_dbl:
	bfextu	FTEMP_LO(a0){21:2}, d3 * dbl-prec. g-r are 2 bits right
	move.l	#30, d2	* of the dbl prec. limits
	lsl.l	d2, d3	* shift g-r bits to the MSB of d3
	move.l	FTEMP_LO(a0), d2	* get lower mantissa  for s-bit test
	and.l	#$000001ff, d2	* s bit is the or-ing of all 
	bne.b	ext_grs_st_stky	* other bits to the right of g-r
	tst.l	d0	* test word original g,r,s
	bne.b	ext_grs_st_stky	* if any are set, set sticky
	bra.b	ext_grs_end_sd	* if clear, exit

ext_grs_st_stky:
	bset	#rnd_stky_bit, d3	* set sticky bit
ext_grs_end_sd:
	move.l	d3, d0	* return grs to d0

	movem.l	(sp)+, d2-d3	* restore scratch registers {d2/d3}

	swap	d1	* restore d1 to original
	rts

**-------------------------------------------------------------------------------------------------
* norm(): normalize the mantissa of an extended precision input. the
*	  input operand should not be normalized already.
*		
* XDEF **
*	norm()	
*		
* xdef ** *
*	none	
*		
* INPUT *************************************************************** *
*	a0 = pointer fp extended precision operand to normalize
*		
* OUTPUT ************************************************************** *
* 	d0 = number of bit positions the mantissa was shifted
*	a0 = the input operand's mantissa is normalized; the exponent
*	     is unchanged.	
*		
**-------------------------------------------------------------------------------------------------
	xdef	norm
norm:
	move.l	d2, -(sp)	* create some temp regs
	move.l	d3, -(sp)

	move.l	FTEMP_HI(a0), d0	* load hi(mantissa)
	move.l	FTEMP_LO(a0), d1	* load lo(mantissa)

	bfffo	d0{0:32}, d2	* how many places to shift?
	beq.b	norm_lo	* hi(man) is all zeroes!

norm_hi:
	lsl.l	d2, d0	* left shift hi(man)
	bfextu	d1{0:20}, d3	* extract lo bits

	or.l	d3, d0	* create hi(man)
	lsl.l	d2, d1	* create lo(man)

	move.l	d0, FTEMP_HI(a0)	* store new hi(man)
	move.l	d1, FTEMP_LO(a0)	* store new lo(man)

	move.l	d2, d0	* return shift amount
	
	move.l	(sp)+, d3	* restore temp regs
	move.l	(sp)+, d2

	rts

norm_lo:
	bfffo	d1{0:32}, d2	* how many places to shift?
	lsl.l	d2, d1	* shift lo(man)
	add.l	#32, d2	* add 32 to shft amount

	move.l	d1, FTEMP_HI(a0)	* store hi(man)
	clr.l	FTEMP_LO(a0)	* lo(man) is now zero

	move.l	d2, d0	* return shift amount
	
	move.l	(sp)+, d3	* restore temp regs
	move.l	(sp)+, d2

	rts

**-------------------------------------------------------------------------------------------------
* unnorm_fix(): - changes an UNNORM to one of NORM, DENORM, or ZERO
*	- returns corresponding optype tag
*		
* XDEF **
*	unnorm_fix()	
*		
* xdef ** *
*	norm() - normalize the mantissa	
*		
* INPUT *************************************************************** *
*	a0 = pointer to unnormalized extended precision number
*		
* OUTPUT ************************************************************** *
*	d0 = optype tag - is corrected to one of NORM, DENORM, or ZERO
*	a0 = input operand has been converted to a norm, denorm, or
*	     zero; both the exponent and mantissa are changed.
*		
**-------------------------------------------------------------------------------------------------

	xdef	unnorm_fix
unnorm_fix:
	bfffo	FTEMP_HI(a0){0:32}, d0 * how many shifts are needed?
	bne.b	unnorm_shift	* hi(man) is not all zeroes

*
* hi(man) is all zeroes so see if any bits in lo(man) are set
*
unnorm_chk_lo:
	bfffo	FTEMP_LO(a0){0:32}, d0 * is operand really a zero?
	beq.w	unnorm_zero	* yes

	add.w	#32, d0	* no; fix shift distance

*
* d0 = * shifts needed for complete normalization
*
unnorm_shift:
	clr.l	d1	* clear top word
	move.w	FTEMP_EX(a0), d1	* extract exponent
	and.w	#$7fff, d1	* strip off sgn

	ICMP.w	d0, d1	* will denorm push exp < 0?
	bgt.b	unnorm_nrm_zero	* yes; denorm only until exp = 0

*
* exponent would not go < 0. therefore, number stays normalized
*
	sub.w	d0, d1	* shift exponent value
	move.w	FTEMP_EX(a0), d0	* load old exponent
	and.w	#$8000, d0	* save old sign
	or.w	d0, d1	* {sgn,new exp}
	move.w	d1, FTEMP_EX(a0)	* insert new exponent

	bsr.l	norm	* normalize UNNORM

	move.b	#NORM, d0	* return new optype tag
	rts

*
* exponent would go < 0, so only denormalize until exp = 0
*
unnorm_nrm_zero:
	ICMP.b	d1, #32	* is exp <= 32?
	bgt.b	unnorm_nrm_zero_lrg	* no; go handle large exponent

	bfextu	FTEMP_HI(a0){d1:32}, d0 * extract new hi(man)
	move.l	d0, FTEMP_HI(a0)	* save new hi(man)

	move.l	FTEMP_LO(a0), d0	* fetch old lo(man)
	lsl.l	d1, d0	* extract new lo(man)
	move.l	d0, FTEMP_LO(a0)	* save new lo(man)

	and.w	#$8000, FTEMP_EX(a0)	* set exp = 0

	move.b	#DENORM, d0	* return new optype tag
	rts

*
* only mantissa bits set are in lo(man)
*
unnorm_nrm_zero_lrg:
	sub.w	#32, d1	* adjust shft amt by 32

	move.l	FTEMP_LO(a0), d0	* fetch old lo(man)
	lsl.l	d1, d0	* left shift lo(man)

	move.l	d0, FTEMP_HI(a0)	* store new hi(man)
	clr.l	FTEMP_LO(a0)	* lo(man) = 0

	and.w	#$8000, FTEMP_EX(a0)	* set exp = 0

	move.b	#DENORM, d0	* return new optype tag
	rts

*
* whole mantissa is zero so this UNNORM is actually a zero
*
unnorm_zero:
	and.w	#$8000, FTEMP_EX(a0) 	* force exponent to zero

	move.b	#ZERO, d0	* fix optype tag
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	set_tag_x(): return the optype of the input ext fp number
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precision operand
* 		
* OUTPUT **************************************************************
*	d0 = value of type tag	
* 	one of: NORM, INF, QNAN, SNAN, DENORM, UNNORM, ZERO
*		
* ALGORITHM ***********************************************************
*	Simply test the exponent, j-bit, and mantissa values to 
* determine the type of operand.	
*	If it's an unnormalized zero, alter the operand and force it
* to be a normal zero.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	set_tag_x
set_tag_x:
	move.w	FTEMP_EX(a0), d0	* extract exponent
	andi.w	#$7fff, d0	* strip off sign
	ICMP.w	d0, #$7fff	* is (EXP == MAX)?
	beq.b	inf_or_nan_x
not_inf_or_nan_x:
	btst	#$7,FTEMP_HI(a0)
	beq.b	not_norm_x
is_norm_x:
	move.b	#NORM, d0
	rts
not_norm_x:
	tst.w	d0	* is exponent = 0?
	bne.b	is_unnorm_x
not_unnorm_x:
	tst.l	FTEMP_HI(a0)
	bne.b	is_denorm_x
	tst.l	FTEMP_LO(a0)
	bne.b	is_denorm_x
is_zero_x:
	move.b	#ZERO, d0
	rts
is_denorm_x:
	move.b	#DENORM, d0
	rts
* must distinguish now "Unnormalized zeroes" which we
* must convert to zero.
is_unnorm_x:
	tst.l	FTEMP_HI(a0)
	bne.b	is_unnorm_reg_x
	tst.l	FTEMP_LO(a0)
	bne.b	is_unnorm_reg_x
* it's an "unnormalized zero". let's convert it to an actual zero...
	andi.w	#$8000,FTEMP_EX(a0)	* clear exponent
	move.b	#ZERO, d0
	rts
is_unnorm_reg_x:
	move.b	#UNNORM, d0
	rts
inf_or_nan_x:
	tst.l	FTEMP_LO(a0)
	bne.b	is_nan_x
	move.l	FTEMP_HI(a0), d0
	and.l	#$7fffffff, d0	* msb is a don't care!
	bne.b	is_nan_x
is_inf_x:
	move.b	#INF, d0
	rts
is_nan_x:
	btst	#$6, FTEMP_HI(a0)
	beq.b	is_snan_x
	move.b	#QNAN, d0
	rts
is_snan_x:
	move.b	#SNAN, d0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	set_tag_d(): return the optype of the input dbl fp number
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0 = points to double precision operand
* 		
* OUTPUT **************************************************************
*	d0 = value of type tag	
* 	one of: NORM, INF, QNAN, SNAN, DENORM, ZERO
*		
* ALGORITHM ***********************************************************
*	Simply test the exponent, j-bit, and mantissa values to 
* determine the type of operand.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	set_tag_d
set_tag_d:
	move.l	FTEMP(a0), d0
	move.l	d0, d1

	andi.l	#$7ff00000, d0
	beq.b	zero_or_denorm_d

	ICMP.l	d0, #$7ff00000
	beq.b	inf_or_nan_d

is_norm_d:
	move.b	#NORM, d0
	rts
zero_or_denorm_d:
	and.l	#$000fffff, d1
	bne	is_denorm_d
	tst.l	4+FTEMP(a0)
	bne	is_denorm_d
is_zero_d:
	move.b	#ZERO, d0
	rts
is_denorm_d:
	move.b	#DENORM, d0
	rts
inf_or_nan_d:
	and.l	#$000fffff, d1
	bne	is_nan_d
	tst.l	4+FTEMP(a0)
	bne	is_nan_d
is_inf_d:
	move.b	#INF, d0
	rts
is_nan_d:
	btst	#19, d1
	bne	is_qnan_d
is_snan_d:
	move.b	#SNAN, d0
	rts
is_qnan_d:
	move.b	#QNAN, d0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	set_tag_s(): return the optype of the input sgl fp number
*		
* xdef **
*	None	
*		
* INPUT ***************************************************************
*	a0 = pointer to single precision operand
* 		
* OUTPUT **************************************************************
*	d0 = value of type tag	
* 	one of: NORM, INF, QNAN, SNAN, DENORM, ZERO
*		
* ALGORITHM ***********************************************************
*	Simply test the exponent, j-bit, and mantissa values to 
* determine the type of operand.	
*		
**-------------------------------------------------------------------------------------------------

	xdef	set_tag_s
set_tag_s:
	move.l	FTEMP(a0), d0
	move.l	d0, d1

	andi.l	#$7f800000, d0
	beq.b	zero_or_denorm_s

	ICMP.l	d0, #$7f800000
	beq.b	inf_or_nan_s

is_norm_s:
	move.b	#NORM, d0
	rts
zero_or_denorm_s:
	and.l	#$007fffff, d1
	bne	is_denorm_s
is_zero_s:
	move.b	#ZERO, d0
	rts
is_denorm_s:
	move.b	#DENORM, d0
	rts
inf_or_nan_s:
	and.l	#$007fffff, d1
	bne	is_nan_s
is_inf_s:
	move.b	#INF, d0
	rts
is_nan_s:
	btst	#22, d1
	bne	is_qnan_s
is_snan_s:
	move.b	#SNAN, d0
	rts
is_qnan_s:
	move.b	#QNAN, d0
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
* 	unf_res(): routine to produce default underflow result of a 
*	 	   scaled extended precision number; this is used by 
*	   fadd/fdiv/fmul/etc. emulation routines.
* 	unf_res4(): same as above but for fsglmul/fsgldiv which use
*	    single round prec and extended prec mode.
*		
* xdef **
*	_denorm() - denormalize according to scale factor
* 	_round() - round denormalized number according to rnd prec
*		
* INPUT ***************************************************************
*	a0 = pointer to extended precison operand
*	d0 = scale factor	
*	d1 = rounding precision/mode	
*		
* OUTPUT **************************************************************
*	a0 = pointer to default underflow result in extended precision
*	d0.b = result EXC_LV+FPSR_cc which caller may or may not want to save
*		
* ALGORITHM ***********************************************************
* 	Convert the input operand to "internal format" which means the
* exponent is extended to 16 bits and the sign is stored in the unused
* portion of the extended precison operand. Denormalize the number
* according to the scale factor passed in d0. Then, round the 
* denormalized result.	
* 	Set the EXC_LV+FPSR_exc bits as appropriate but return the cc bits in
* d0 in case the caller doesn't want to save them (as is the case for
* fmove out).	
* 	unf_res4() for fsglmul/fsgldiv forces the denorm to extended
* precision and the rounding mode to single.
*		
**-------------------------------------------------------------------------------------------------
	xdef	unf_res
unf_res:
	move.l	d1, -(sp)	* save rnd prec,mode on stack

	btst	#$7, FTEMP_EX(a0)	* make "internal" format
	sne	FTEMP_SGN(a0)

	move.w	FTEMP_EX(a0), d1	* extract exponent
	and.w	#$7fff, d1
	sub.w	d0, d1
	move.w	d1, FTEMP_EX(a0)	* insert 16 bit exponent

	move.l	a0, -(sp)	* save operand ptr during calls

	move.l	$4(sp),d0	* pass rnd prec.
	andi.w	#$00c0,d0
	lsr.w	#$4,d0
	bsr.l	_denorm	* denorm result

	move.l	(sp),a0
	move.w	$6(sp),d1	* load prec:mode into d1
	andi.w	#$c0,d1	* extract rnd prec
	lsr.w	#$4,d1
	swap	d1
	move.w	$6(sp),d1
	andi.w	#$30,d1
	lsr.w	#$4,d1
	bsr.l	_round	* round the denorm

	move.l	(sp)+, a0

* result is now rounded properly. convert back to normal format
	bclr	#$7, FTEMP_EX(a0)	* clear sgn first; may have residue
	tst.b	FTEMP_SGN(a0)	* is "internal result" sign set?
	beq.b	unf_res_chkifzero	* no; result is positive
	bset	#$7, FTEMP_EX(a0)	* set result sgn
	clr.b	FTEMP_SGN(a0)	* clear temp sign

* the number may have become zero after rounding. set ccodes accordingly.
unf_res_chkifzero:
	clr.l	d0
	tst.l	FTEMP_HI(a0)	* is value now a zero?
	bne.b	unf_res_cont	* no
	tst.l	FTEMP_LO(a0)
	bne.b	unf_res_cont	* no
*	bset	#z_bit, EXC_LV+FPSR_CC(a6)	* yes; set zero ccode bit
	bset	#z_bit, d0	* yes; set zero ccode bit

unf_res_cont:

*
* can inex1 also be set along with unfl and inex2???
*
* we know that underflow has occurred. aunfl should be set if INEX2 is also set.
*
	btst	#inex2_bit, EXC_LV+FPSR_EXCEPT(a6) * is INEX2 set?
	beq.b	unf_res_end	* no
	bset	#aunfl_bit, EXC_LV+FPSR_AEXCEPT(a6) * yes; set aunfl

unf_res_end:
	add.l	#$4, sp	* clear stack
	rts

* unf_res() for fsglmul() and fsgldiv().
	xdef	unf_res4
unf_res4:
	move.l	d1,-(sp)	* save rnd prec,mode on stack

	btst	#$7,FTEMP_EX(a0)	* make "internal" format
	sne	FTEMP_SGN(a0)

	move.w	FTEMP_EX(a0),d1	* extract exponent
	and.w	#$7fff,d1
	sub.w	d0,d1
	move.w	d1,FTEMP_EX(a0)	* insert 16 bit exponent

	move.l	a0,-(sp)	* save operand ptr during calls

	clr.l	d0	* force rnd prec = ext
	bsr.l	_denorm	* denorm result

	move.l	(sp),a0
	move.w	#s_mode,d1	* force rnd prec = sgl
	swap	d1
	move.w	$6(sp),d1	* load rnd mode
	andi.w	#$30,d1	* extract rnd prec
	lsr.w	#$4,d1
	bsr.l	_round	* round the denorm

	move.l	(sp)+,a0

* result is now rounded properly. convert back to normal format
	bclr	#$7,FTEMP_EX(a0)	* clear sgn first; may have residue
	tst.b	FTEMP_SGN(a0)	* is "internal result" sign set?
	beq.b	unf_res4_chkifzero	* no; result is positive
	bset	#$7,FTEMP_EX(a0)	* set result sgn
	clr.b	FTEMP_SGN(a0)	* clear temp sign

* the number may have become zero after rounding. set ccodes accordingly.
unf_res4_chkifzero:
	clr.l	d0
	tst.l	FTEMP_HI(a0)	* is value now a zero?
	bne.b	unf_res4_cont	* no
	tst.l	FTEMP_LO(a0)
	bne.b	unf_res4_cont	* no
*	bset	#z_bit,EXC_LV+FPSR_CC(a6)	* yes; set zero ccode bit
	bset	#z_bit,d0	* yes; set zero ccode bit

unf_res4_cont:

*
* can inex1 also be set along with unfl and inex2???
*
* we know that underflow has occurred. aunfl should be set if INEX2 is also set.
*
	btst	#inex2_bit,EXC_LV+FPSR_EXCEPT(a6) * is INEX2 set?
	beq.b	unf_res4_end	* no
	bset	#aunfl_bit,EXC_LV+FPSR_AEXCEPT(a6) * yes; set aunfl

unf_res4_end:
	add.l	#$4,sp	* clear stack
	rts

**-------------------------------------------------------------------------------------------------
* XDEF **
*	ovf_res(): routine to produce the default overflow result of
*	   an overflowing number.
*	ovf_res2(): same as above but the rnd mode/prec are passed
*	    differently.	
*		
* xdef **
*	none	
*		
* INPUT ***************************************************************
*	d1.b 	= '-1' => (-); '0' => (+)
*   ovf_res():	
*	d0 	= rnd mode/prec	
*   ovf_res2():	
*	hi(d0) 	= rnd prec	
*	lo(d0)	= rnd mode	
*		
* OUTPUT **************************************************************
*	a0   	= points to extended precision result
*	d0.b 	= condition code bits	
*		
* ALGORITHM ***********************************************************
*	The default overflow result can be determined by the sign of
* the result and the rounding mode/prec in effect. These bits are
* concatenated together to create an index into the default result 
* table. A pointer to the correct result is returned in a0. The
* resulting condition codes are returned in d0 in case the caller 
* doesn't want EXC_LV+FPSR_cc altered (as is the case for fmove out).
*		
**-------------------------------------------------------------------------------------------------

	xdef	ovf_res
ovf_res:
	andi.w	#$10,d1	* keep result sign
	lsr.b	#$4,d0	* shift prec/mode
	or.b	d0,d1	* concat the two
	move.w	d1,d0	* make a copy
	lsl.b	#$1,d1	* multiply d1 by 2
	bra.b	ovf_res_load

	xdef	ovf_res2
ovf_res2:
	and.w	#$10, d1	* keep result sign
	or.b	d0, d1	* insert rnd mode
	swap	d0
	or.b	d0, d1	* insert rnd prec
	move.w	d1, d0	* make a copy
	lsl.b	#$1, d1	* shift left by 1

*
* use the rounding mode, precision, and result sign as in index into the
* two tables below to fetch the default result and the result ccodes.
*
ovf_res_load:
	move.b	((tbl_ovfl_cc).b,pc,d0.w*1), d0 * fetch result ccodes
	lea	((tbl_ovfl_result).b,pc,d1.w*8), a0 * return result ptr
	
	rts

tbl_ovfl_cc:
	dc.b	$2, $0, $0, $2
	dc.b	$2, $0, $0, $2
	dc.b	$2, $0, $0, $2
	dc.b	$0, $0, $0, $0
	dc.b	$2+$8, $8, $2+$8, $8
	dc.b	$2+$8, $8, $2+$8, $8
	dc.b	$2+$8, $8, $2+$8, $8

tbl_ovfl_result:
	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RN
	dc.l	$7ffe0000,$ffffffff,$ffffffff,$00000000 * +EXT; RZ
	dc.l	$7ffe0000,$ffffffff,$ffffffff,$00000000 * +EXT; RM
	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RP

	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RN
	dc.l	$407e0000,$ffffff00,$00000000,$00000000 * +SGL; RZ
	dc.l	$407e0000,$ffffff00,$00000000,$00000000 * +SGL; RM
	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RP

	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RN
	dc.l	$43fe0000,$ffffffff,$fffff800,$00000000 * +DBL; RZ
	dc.l	$43fe0000,$ffffffff,$fffff800,$00000000 * +DBL; RM
	dc.l	$7fff0000,$00000000,$00000000,$00000000 * +INF; RP

	dc.l	$00000000,$00000000,$00000000,$00000000
	dc.l	$00000000,$00000000,$00000000,$00000000
	dc.l	$00000000,$00000000,$00000000,$00000000
	dc.l	$00000000,$00000000,$00000000,$00000000

	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RN
	dc.l	$fffe0000,$ffffffff,$ffffffff,$00000000 * -EXT; RZ
	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RM
	dc.l	$fffe0000,$ffffffff,$ffffffff,$00000000 * -EXT; RP

	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RN
	dc.l	$c07e0000,$ffffff00,$00000000,$00000000 * -SGL; RZ
	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RM
	dc.l	$c07e0000,$ffffff00,$00000000,$00000000 * -SGL; RP

	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RN
	dc.l	$c3fe0000,$ffffffff,$fffff800,$00000000 * -DBL; RZ
	dc.l	$ffff0000,$00000000,$00000000,$00000000 * -INF; RM
	dc.l	$c3fe0000,$ffffffff,$fffff800,$00000000 * -DBL; RP

**-------------------------------------------------------------------------------------------------
* XDEF **
*	get_packed(): fetch a packed operand from memory and then
*	      convert it to a floating-point binary number.
*		
* xdef **
*	_dcalc_ea() - calculate the correct <ea>
*	_mem_read() - fetch the packed operand from memory
*	facc_in_x() - the fetch failed so jump to special exit code
*	decbin()    - convert packed to binary extended precision
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	If no failure on _mem_read():	
* 	EXC_LV+FP_SRC(a6) = packed operand now as a binary FP number
*		
* ALGORITHM ***********************************************************
*	Get the correct <ea> whihc is the value on the exception stack 
* frame w/ maybe a correction factor if the <ea> is -(an) or (an)+.
* Then, fetch the operand from memory. If the fetch fails, exit
* through facc_in_x().	
*	If the packed operand is a ZERO,NAN, or INF, convert it to
* its binary representation here. Else, call decbin() which will 
* convert the packed value to an extended precision binary value.
*		
**-------------------------------------------------------------------------------------------------

* the stacked <ea> for packed is correct except for -(An).
* the base reg must be updated for both -(An) and (An)+.
	xdef	get_packed
get_packed:
	move.l	#$c,d0	* packed is 12 bytes
	bsr.l	_dcalc_ea	* fetch <ea>; correct An

	lea	EXC_LV+FP_SRC(a6),a1	* pass: ptr to super dst
	move.l	#$c,d0	* pass: 12 bytes
	bsr.l	_dmem_read	* read packed operand

	tst.l	d1	* did dfetch fail?
	bne.l	facc_in_x	* yes

* The packed operand is an INF or a NAN if the exponent field is all ones.
	bfextu	EXC_LV+FP_SRC(a6){1:15},d0	* get exp
	ICMP.w	d0,#$7fff	* INF or NAN?
	bne.b	gp_try_zero	* no
	rts		* operand is an INF or NAN

* The packed operand is a zero if the mantissa is all zero, else it's
* a normal packed op.
gp_try_zero:
	move.b	3+EXC_LV+FP_SRC(a6),d0	* get byte 4
	andi.b	#$0f,d0	* clear all but last nybble
	bne.b	gp_not_spec	* not a zero
	tst.l	EXC_LV+FP_SRC_HI(a6)	* is lw 2 zero?
	bne.b	gp_not_spec	* not a zero
	tst.l	EXC_LV+FP_SRC_LO(a6)	* is lw 3 zero?
	bne.b	gp_not_spec	* not a zero
	rts		* operand is a ZERO
gp_not_spec:
	lea	EXC_LV+FP_SRC(a6),a0	* pass: ptr to packed op
	bsr.l	decbin	* convert to extended
	fmovem.x	fp0,EXC_LV+FP_SRC(a6)	* make this the srcop
	rts

**-------------------------------------------------------------------------------------------------
* decbin(): Converts normalized packed bcd value pointed to by register
*	    a0 to extended-precision value in fp0.
*		
* INPUT ***************************************************************
*	a0 = pointer to normalized packed bcd value
*		
* OUTPUT **************************************************************
*	fp0 = exact fp representation of the packed bcd value.
*		
* ALGORITHM ***********************************************************
*	Expected is a normal bcd (i.e. non-exceptional; all inf, zero,
*	and NaN operands are dispatched without entering this routine)
*	value in 68881/882 format at location (a0).
*		
*	A1. Convert the bcd exponent to binary by successive adds and 
*	muls. Set the sign according to SE. Subtract 16 to compensate
*	for the mantissa which is to be interpreted as 17 integer
*	digits, rather than 1 integer and 16 fraction digits.
*	Note: this operation can never overflow.
*		
*	A2. Convert the bcd mantissa to binary by successive
*	adds and muls in FP0. Set the sign according to SM.
*	The mantissa digits will be converted with the decimal point
*	assumed following the least-significant digit.
*	Note: this operation can never overflow.
*		
*	A3. Count the number of leading/trailing zeros in the
*	bcd string.  If SE is positive, count the leading zeros;
*	if negative, count the trailing zeros.  Set the adjusted
*	exponent equal to the exponent from A1 and the zero count
*	added if SM = 1 and subtracted if SM = 0.  Scale the
*	mantissa the equivalent of forcing in the bcd value:
*		
*	SM = 0	a non-zero digit in the integer position
*	SM = 1	a non-zero digit in Mant0, lsd of the fraction
*		
*	this will insure that any value, regardless of its
*	representation (ex. 0.1E2, 1E1, 10E0, 100E-1), is converted
*	consistently.	
*		
*	A4. Calculate the factor 10^exp in FP1 using a table of
*	10^(2^n) values.  To reduce the error in forming factors
*	greater than 10^27, a directed rounding scheme is used with
*	tables rounded to RN, RM, and RP, according to the table
*	in the comments of the pwrten section.
*		
*	A5. Form the final binary number by scaling the mantissa by
*	the exponent factor.  This is done by multiplying the
*	mantissa in FP0 by the factor in FP1 if the adjusted
*	exponent sign is positive, and dividing FP0 by FP1 if
*	it is negative.	
*		
*	Clean up and return. Check if the final mul or div was inexact.
*	If so, set INEX1 in USER_FPSR.	
*		
**-------------------------------------------------------------------------------------------------

*
*	PTENRN, PTENRM, and PTENRP are arrays of powers of 10 rounded
*	to nearest, minus, and plus, respectively.  The tables include
*	10**{1,2,4,8,16,32,64,128,256,512,1024,2048,4096}.  No rounding
*	is required until the power is greater than 27, however, all
*	tables include the first 5 for ease of indexing.
*
RTABLE:
	dc.b	0,0,0,0
	dc.b	2,3,2,3
	dc.b	2,3,3,2
	dc.b	3,2,2,3

FNIBS	equ	7
FSTRT	equ	0

ESTRT	equ	4
EDIGITS	equ	2
	xdef	decbin
decbin:
	move.l	$0(a0),EXC_LV+FP_SCR0_EX(a6) * make a copy of input 
	move.l	$4(a0),EXC_LV+FP_SCR0_HI(a6) * so we don't alter it
	move.l	$8(a0),EXC_LV+FP_SCR0_LO(a6)

	lea	EXC_LV+FP_SCR0(a6),a0

	movem.l	d2-d5,-(sp)	* save d2-d5
	fmovem.x	fp1,-(sp)	* save fp1
*
* Calculate exponent:
*  1. Copy bcd value in memory for use as a working copy.
*  2. Calculate absolute value of exponent in d1 by mul and add.
*  3. Correct for exponent sign.
*  4. Subtract 16 to compensate for interpreting the mant as all integer digits.
*     (i.e., all digits assumed left of the decimal point.)
*
* Register usage:
*
*  calc_e:
*	(*)  d0: temp digit storage
*	(*)  d1: accumulator for binary exponent
*	(*)  d2: digit count
*	(*)  d3: offset pointer
*	( )  d4: first word of bcd
*	( )  a0: pointer to working bcd value
*	( )  a6: pointer to original bcd value
*	(*)  EXC_LV+FP_SCR1: working copy of original bcd value
*	(*)  EXC_LV+L_SCR1: copy of original exponent word
*
calc_e:
	move.l	#EDIGITS,d2	* * of nibbles (digits) in fraction part
	move.l	#ESTRT,d3	* counter to pick up digits
	move.l	(a0),d4	* get first word of bcd
	clr.l	d1	* zero d1 for accumulator
e_gd:
	mulu.l	#$a,d1	* mul partial product by one digit place
	bfextu	d4{d3:4},d0	* get the digit and zero extend into d0
	add.l	d0,d1	* d1 = d1 + d0
	addq.b	#4,d3	* advance d3 to the next digit
	dbf.w	d2,e_gd	* if we have used all 3 digits, exit loop
	btst	#30,d4	* get SE
	beq.b	e_pos	* don't negate if pos
	neg.l	d1	* negate before subtracting
e_pos:
	sub.l	#16,d1	* sub to compensate for shift of mant
	bge.b	e_save	* if still pos, do not neg
	neg.l	d1	* now negative, make pos and set SE
	or.l	#$40000000,d4	* set SE in d4,
	or.l	#$40000000,(a0)	* and in working bcd
e_save:
	move.l	d1,-(sp)	* save exp on stack
*
*
* Calculate mantissa:
*  1. Calculate absolute value of mantissa in fp0 by mul and add.
*  2. Correct for mantissa sign.
*     (i.e., all digits assumed left of the decimal point.)
*
* Register usage:
*
*  calc_m:
*	(*)  d0: temp digit storage
*	(*)  d1: lword counter
*	(*)  d2: digit count
*	(*)  d3: offset pointer
*	( )  d4: words 2 and 3 of bcd
*	( )  a0: pointer to working bcd value
*	( )  a6: pointer to original bcd value
*	(*) fp0: mantissa accumulator
*	( )  EXC_LV+FP_SCR1: working copy of original bcd value
*	( )  EXC_LV+L_SCR1: copy of original exponent word
*
calc_m:
	move.l	#1,d1	* word counter, init to 1
	fmove.s	#$00000000,fp0	* accumulator
*
*
*  Since the packed number has a dc.l word between the first # second parts,
*  get the integer digit then skip down # get the rest of the
*  mantissa.  We will unroll the loop once.
*
	bfextu	(a0){28:4},d0	* integer part is ls digit in dc.l word
	fadd.b	d0,fp0	* add digit to sum in fp0
*
*
*  Get the rest of the mantissa.
*
loadlw:
	move.l	(a0,d1.L*4),d4	* load mantissa lonqword into d4
	move.l	#FSTRT,d3	* counter to pick up digits
	move.l	#FNIBS,d2	* reset number of digits per a0 ptr
md2b:
	fmul.s	#$41200000,fp0	* fp0 = fp0 * 10
	bfextu	d4{d3:4},d0	* get the digit and zero extend
	fadd.b	d0,fp0	* fp0 = fp0 + digit
*
*
*  If all the digits (8) in that dc.l word have been converted (d2=0),
*  then inc d1 (=2) to point to the next dc.l word and reset d3 to 0
*  to initialize the digit offset, and set d2 to 7 for the digit count;
*  else continue with this dc.l word.
*
	addq.b	#4,d3	* advance d3 to the next digit
	dbf.w	d2,md2b	* check for last digit in this lw
nextlw:
	addq.l	#1,d1	* inc lw pointer in mantissa
	ICMP.l	d1,#2	* test for last lw
	ble.b	loadlw	* if not, get last one
*
*  Check the sign of the mant and make the value in fp0 the same sign.
*
m_sign:
*	btst	#31,(a0)	* test sign of the mantissa

	beq.b	ap_st_z	* if clear, go to append/strip zeros
	fneg.x	fp0	* if set, negate fp0
*
* Append/strip zeros:
*
*  For adjusted exponents which have an absolute value greater than 27*,
*  this routine calculates the amount needed to normalize the mantissa
*  for the adjusted exponent.  That number is subtracted from the exp
*  if the exp was positive, and added if it was negative.  The purpose
*  of this is to reduce the value of the exponent and the possibility
*  of error in calculation of pwrten.
*
*  1. Branch on the sign of the adjusted exponent.
*  2p.(positive exp)
*   2. Check M16 and the digits in lwords 2 and 3 in decending order.
*   3. Add one for each zero encountered until a non-zero digit.
*   4. Subtract the count from the exp.
*   5. Check if the exp has crossed zero in *3 above; make the exp abs
*	   and set SE.
*	6. Multiply the mantissa by 10**count.
*  2n.(negative exp)
*   2. Check the digits in lwords 3 and 2 in decending order.
*   3. Add one for each zero encountered until a non-zero digit.
*   4. Add the count to the exp.
*   5. Check if the exp has crossed zero in *3 above; clear SE.
*   6. Divide the mantissa by 10**count.
*
*  *Why 27?  If the adjusted exponent is within -28 < expA < 28, than
*   any adjustment due to append/strip zeros will drive the resultane
*   exponent towards zero.  Since all pwrten constants with a power
*   of 27 or less are exact, there is no need to use this routine to
*   attempt to lessen the resultant exponent.
*
* Register usage:
*
*  ap_st_z:
*	(*)  d0: temp digit storage
*	(*)  d1: zero count
*	(*)  d2: digit count
*	(*)  d3: offset pointer
*	( )  d4: first word of bcd
*	(*)  d5: lword counter
*	( )  a0: pointer to working bcd value
*	( )  EXC_LV+FP_SCR1: working copy of original bcd value
*	( )  EXC_LV+L_SCR1: copy of original exponent word
*
*
* First check the absolute value of the exponent to see if this
* routine is necessary.  If so, then check the sign of the exponent
* and do append (+) or strip (-) zeros accordingly.
* This section handles a positive adjusted exponent.
*
ap_st_z:
	move.l	(sp),d1	* load expA for range test
	ICMP.l	d1,#27	* test is with 27
	ble.w	pwrten	* if abs(expA) <28, skip ap/st zeros
	btst	#0,(a0)	* check sign of exp
	bne.b	ap_st_n	* if neg, go to neg side
	clr.l	d1	* zero count reg
	move.l	(a0),d4	* load lword 1 to d4
	bfextu	d4{28:4},d0	* get M16 in d0
	bne.b	ap_p_fx	* if M16 is non-zero, go fix exp
	addq.l	#1,d1	* inc zero count
	move.l	#1,d5	* init lword counter
	move.l	(a0,d5.L*4),d4	* get lword 2 to d4
	bne.b	ap_p_cl	* if lw 2 is zero, skip it
	addq.l	#8,d1	* and inc count by 8
	addq.l	#1,d5	* inc lword counter
	move.l	(a0,d5.L*4),d4	* get lword 3 to d4
ap_p_cl:
	clr.l	d3	* init offset reg
	move.l	#7,d2	* init digit counter
ap_p_gd:
	bfextu	d4{d3:4},d0	* get digit
	bne.b	ap_p_fx	* if non-zero, go to fix exp
	addq.l	#4,d3	* point to next digit
	addq.l	#1,d1	* inc digit counter
	dbf.w	d2,ap_p_gd	* get next digit
ap_p_fx:
	move.l	d1,d0	* copy counter to d2
	move.l	(sp),d1	* get adjusted exp from memory
	sub.l	d0,d1	* subtract count from exp
	bge.b	ap_p_fm	* if still pos, go to pwrten
	neg.l	d1	* now its neg; get abs
	move.l	(a0),d4	* load lword 1 to d4
	or.l	#$40000000,d4	* and set SE in d4
	or.l	#$40000000,(a0)	* and in memory
*
* Calculate the mantissa multiplier to compensate for the striping of
* zeros from the mantissa.
*
ap_p_fm:
	lea.l	PTENRN(pc),a1	* get address of power-of-ten table
	clr.l	d3	* init table index
	fmove.s	#$3f800000,fp1	* init fp1 to 1
	move.l	#3,d2	* init d2 to count bits in counter
ap_p_el:
	asr.l	#1,d0	* shift lsb into carry
	bcc.b	ap_p_en	* if 1, mul fp1 by pwrten factor
	fmul.x	(a1,d3),fp1	* mul by 10**(d3_bit_no)
ap_p_en:
	add.l	#12,d3	* inc d3 to next rtable entry
	tst.l	d0	* check if d0 is zero
	bne.b	ap_p_el	* if not, get next bit
	fmul.x	fp1,fp0	* mul mantissa by 10**(no_bits_shifted)
	bra.b	pwrten	* go calc pwrten
*
* This section handles a negative adjusted exponent.
*
ap_st_n:
	clr.l	d1	* clr counter
	move.l	#2,d5	* set up d5 to point to lword 3
	move.l	(a0,d5.L*4),d4	* get lword 3
	bne.b	ap_n_cl	* if not zero, check digits
	sub.l	#1,d5	* dec d5 to point to lword 2
	addq.l	#8,d1	* inc counter by 8
	move.l	(a0,d5.L*4),d4	* get lword 2
ap_n_cl:
	move.l	#28,d3	* point to last digit
	move.l	#7,d2	* init digit counter
ap_n_gd:
	bfextu	d4{d3:4},d0	* get digit
	bne.b	ap_n_fx	* if non-zero, go to exp fix
	subq.l	#4,d3	* point to previous digit
	addq.l	#1,d1	* inc digit counter
	dbf.w	d2,ap_n_gd	* get next digit
ap_n_fx:
	move.l	d1,d0	* copy counter to d0
	move.l	(sp),d1	* get adjusted exp from memory
	sub.l	d0,d1	* subtract count from exp
	bgt.b	ap_n_fm	* if still pos, go fix mantissa
	neg.l	d1	* take abs of exp and clr SE
	move.l	(a0),d4	* load lword 1 to d4
	and.l	#$bfffffff,d4	* and clr SE in d4
	and.l	#$bfffffff,(a0)	* and in memory
*
* Calculate the mantissa multiplier to compensate for the appending of
* zeros to the mantissa.
*
ap_n_fm:
	lea.l	PTENRN(pc),a1	* get address of power-of-ten table
	clr.l	d3	* init table index
	fmove.s	#$3f800000,fp1	* init fp1 to 1
	move.l	#3,d2	* init d2 to count bits in counter
ap_n_el:
	asr.l	#1,d0	* shift lsb into carry
	bcc.b	ap_n_en	* if 1, mul fp1 by pwrten factor
	fmul.x	(a1,d3),fp1	* mul by 10**(d3_bit_no)
ap_n_en:
	add.l	#12,d3	* inc d3 to next rtable entry
	tst.l	d0	* check if d0 is zero
	bne.b	ap_n_el	* if not, get next bit
	fdiv.x	fp1,fp0	* div mantissa by 10**(no_bits_shifted)
*
*
* Calculate power-of-ten factor from adjusted and shifted exponent.
*
* Register usage:
*
*  pwrten:
*	(*)  d0: temp
*	( )  d1: exponent
*	(*)  d2: {FPCR[6:5],SM,SE} as index in RTABLE; temp
*	(*)  d3: FPCR work copy
*	( )  d4: first word of bcd
*	(*)  a1: RTABLE pointer
*  calc_p:
*	(*)  d0: temp
*	( )  d1: exponent
*	(*)  d3: PWRTxx table index
*	( )  a0: pointer to working copy of bcd
*	(*)  a1: PWRTxx pointer
*	(*) fp1: power-of-ten accumulator
*
* Pwrten calculates the exponent factor in the selected rounding mode
* according to the following table:
*	
*	Sign of Mant  Sign of Exp  Rounding Mode  PWRTEN Rounding Mode
*
*	ANY	  ANY	RN	RN
*
*	 +	   +	RP	RP
*	 -	   +	RP	RM
*	 +	   -	RP	RM
*	 -	   -	RP	RP
*
*	 +	   +	RM	RM
*	 -	   +	RM	RP
*	 +	   -	RM	RP
*	 -	   -	RM	RM
*
*	 +	   +	RZ	RM
*	 -	   +	RZ	RM
*	 +	   -	RZ	RP
*	 -	   -	RZ	RP
*
*
pwrten:
	move.l	EXC_LV+USER_FPCR(a6),d3	* get user's FPCR
	bfextu	d3{26:2},d2	* isolate rounding mode bits
	move.l	(a0),d4	* reload 1st bcd word to d4
	asl.l	#2,d2	* format d2 to be
	bfextu	d4{0:2},d0	* {FPCR[6],FPCR[5],SM,SE}
	add.l	d0,d2	* in d2 as index into RTABLE
	lea.l	RTABLE(pc),a1	* load rtable base
	move.b	(a1,d2),d0	* load new rounding bits from table
	clr.l	d3	* clear d3 to force no exc and extended
	bfins	d0,d3{26:2}	* stuff new rounding bits in FPCR
	fmove.l	d3,fpcr	* write new FPCR
	asr.l	#1,d0	* write correct PTENxx table
	bcc.b	not_rp	* to a1
	lea.l	PTENRP(pc),a1	* it is RP
	bra.b	calc_p	* go to init section
not_rp:
	asr.l	#1,d0	* keep checking
	bcc.b	not_rm
	lea.l	PTENRM(pc),a1	* it is RM
	bra.b	calc_p	* go to init section
not_rm:
	lea.l	PTENRN(pc),a1	* it is RN
calc_p:
	move.l	d1,d0	* copy exp to d0;use d0
	bpl.b	no_neg	* if exp is negative,
	neg.l	d0	* invert it
	or.l	#$40000000,(a0)	* and set SE bit
no_neg:
	clr.l	d3	* table index
	fmove.s	#$3f800000,fp1	* init fp1 to 1
e_loop:
	asr.l	#1,d0	* shift next bit into carry
	bcc.b	e_next	* if zero, skip the mul
	fmul.x	(a1,d3),fp1	* mul by 10**(d3_bit_no)
e_next:
	add.l	#12,d3	* inc d3 to next rtable entry
	tst.l	d0	* check if d0 is zero
	bne.b	e_loop	* not zero, continue shifting
*
*
*  Check the sign of the adjusted exp and make the value in fp0 the
*  same sign. If the exp was pos then multiply fp1*fp0;
*  else divide fp0/fp1.
*
* Register Usage:
*  norm:
*	( )  a0: pointer to working bcd value
*	(*) fp0: mantissa accumulator
*	( ) fp1: scaling factor - 10**(abs(exp))
*
pnorm:
	btst	#0,(a0)	* test the sign of the exponent
	beq.b	mul	* if clear, go to multiply
div:
	fdiv.x	fp1,fp0	* exp is negative, so divide mant by exp
	bra.b	end_dec
mul:
	fmul.x	fp1,fp0	* exp is positive, so multiply by exp
*
*
* Clean up and return with result in fp0.
*
* If the final mul/div in decbin incurred an inex exception,
* it will be inex2, but will be reported as inex1 by get_op.
*
end_dec:
	fmove.l	fpsr,d0	* get status register	
	bclr	#inex2_bit+8,d0	* test for inex2 and clear it
	beq.b	no_exc	* skip this if no exc
	ori.w	#inx1a_mask,2+EXC_LV+USER_FPSR(a6) * set INEX1/AINEX
no_exc:
	add.l	#$4,sp	* clear 1 lw param
	fmovem.x	(sp)+,fp1	* restore fp1
	movem.l	(sp)+,d2-d5	* restore d2-d5
	fmove.l	#$0,fpcr
	fmove.l	#$0,fpsr
	rts

**-------------------------------------------------------------------------------------------------
* bindec(): Converts an input in extended precision format to bcd format*
*		
* INPUT ***************************************************************
*	a0 = pointer to the input extended precision value in memory.
*	     the input may be either normalized, unnormalized, or 
*	     denormalized.	
*	d0 = contains the k-factor sign-extended to 32-bits. 
*		
* OUTPUT **************************************************************
*	EXC_LV+FP_SCR0(a6) = bcd format result on the stack.
*		
* ALGORITHM ***********************************************************
*		
*	A1.	Set RM and size ext;  Set SIGMA = sign of input.  
*	The k-factor is saved for use in d7. Clear the
*	BINDEC_FLG for separating normalized/denormalized
*	input.  If input is unnormalized or denormalized,
*	normalize it.	
*		
*	A2.	Set X = abs(input).	
*		
*	A3.	Compute ILOG.	
*	ILOG is the log base 10 of the input value.  It is
*	approximated by adding e + 0.f when the original 
*	value is viewed as 2^^e * 1.f in extended precision.  
*	This value is stored in d6.
*		
*	A4.	Clr INEX bit.	
*	The operation in A3 above may have set INEX2.  
*		
*	A5.	Set ICTR = 0;	
*	ICTR is a flag used in A13.  It must be set before the 
*	loop entry A6.	
*		
*	A6.	Calculate LEN.	
*	LEN is the number of digits to be displayed.  The
*	k-factor can dictate either the total number of digits,
*	if it is a positive number, or the number of digits
*	after the decimal point which are to be included as
*	significant.  See the 68882 manual for examples.
*	If LEN is computed to be greater than 17, set OPERR in
*	USER_FPSR.  LEN is stored in d4.
*		
*	A7.	Calculate SCALE.	
*	SCALE is equal to 10^ISCALE, where ISCALE is the number
*	of decimal places needed to insure LEN integer digits
*	in the output before conversion to bcd. LAMBDA is the
*	sign of ISCALE, used in A9. Fp1 contains
*	10^^(abs(ISCALE)) using a rounding mode which is a
*	function of the original rounding mode and the signs
*	of ISCALE and X.  A table is given in the code.
*		
*	A8.	Clr INEX; Force RZ.	
*	The operation in A3 above may have set INEX2.  
*	RZ mode is forced for the scaling operation to insure
*	only one rounding error.  The grs bits are collected in *
*	the INEX flag for use in A10.
*		
*	A9.	Scale X -> Y.	
*	The mantissa is scaled to the desired number of
*	significant digits.  The excess digits are collected
*	in INEX2.	
*		
*	A10.	Or in INEX.	
*	If INEX is set, round error occured.  This is
*	compensated for by 'or-ing' in the INEX2 flag to
*	the lsb of Y.	
*		
*	A11.	Restore original FPCR; set size ext.
*	Perform FINT operation in the user's rounding mode.
*	Keep the size to extended.
*		
*	A12.	Calculate YINT = FINT(Y) according to user's rounding
*	mode.  The FPSP routine sintd0 is used.  The output
*	is in fp0.	
*		
*	A13.	Check for LEN digits.	
*	If the int operation results in more than LEN digits,
*	or less than LEN -1 digits, adjust ILOG and repeat from
*	A6.  This test occurs only on the first pass.  If the
*	result is exactly 10^LEN, decrement ILOG and divide
*	the mantissa by 10.	
*		
*	A14.	Convert the mantissa to bcd.
*	The binstr routine is used to convert the LEN digit 
*	mantissa to bcd in memory.  The input to binstr is
*	to be a fraction; i.e. (mantissa)/10^LEN and adjusted
*	such that the decimal point is to the left of bit 63.
*	The bcd digits are stored in the correct position in 
*	the final string area in memory.
*		
*	A15.	Convert the exponent to bcd.
*	As in A14 above, the exp is converted to bcd and the
*	digits are stored in the final string.
*	Test the length of the final exponent string.  If the
*	length is 4, set operr.	
*		
*	A16.	Write sign bits to final string.
*		
**-------------------------------------------------------------------------------------------------

BINDEC_FLG	equ	EXC_LV+EXC_TEMP	* DENORM flag

* Constants in extended precision
PLOG2:
	dc.l	$3FFD0000,$9A209A84,$FBCFF798,$00000000
PLOG2UP1:
	dc.l	$3FFD0000,$9A209A84,$FBCFF799,$00000000

* Constants in single precision
FONE:
	dc.l	$3F800000,$00000000,$00000000,$00000000
FTWO:
	dc.l	$40000000,$00000000,$00000000,$00000000
FTEN:
	dc.l	$41200000,$00000000,$00000000,$00000000
F4933:
	dc.l	$459A2800,$00000000,$00000000,$00000000

RBDTBL:
	dc.b	0,0,0,0
	dc.b	3,3,2,2
	dc.b	3,2,2,3
	dc.b	2,3,3,2

*	Implementation Notes:
*
*	The registers are used as follows:
*
*	d0: scratch; LEN input to binstr
*	d1: scratch
*	d2: upper 32-bits of mantissa for binstr
*	d3: scratch;lower 32-bits of mantissa for binstr
*	d4: LEN
*      	d5: LAMBDA/ICTR
*	d6: ILOG
*	d7: k-factor
*	a0: ptr for original operand/final result
*	a1: scratch pointer
*	a2: pointer to EXC_LV+FP_X; abs(original value) in ext
*	fp0: scratch
*	fp1: scratch
*	fp2: scratch
*	F_SCR1:
*	F_SCR2:
*	EXC_LV+L_SCR1:
*	EXC_LV+L_SCR2:

	xdef	bindec
bindec:
	movem.l	d2-d7/a2,-(sp)	*  {d2-d7/a2}
	fmovem.x	fp0-fp2,-(sp)	*  {fp0-fp2}

* A1. Set RM and size ext. Set SIGMA = sign input;
*     The k-factor is saved for use in d7.  Clear BINDEC_FLG for
*     separating  normalized/denormalized input.  If the input
*     is a denormalized number, set the BINDEC_FLG memory word
*     to signal denorm.  If the input is unnormalized, normalize
*     the input and test for denormalized result.
*
	fmove.l	#rm_mode*$10,fpcr	* set RM and ext
	move.l	(a0),EXC_LV+L_SCR2(a6)	* save exponent for sign check
	move.l	d0,d7	* move k-factor to d7

	clr.b	BINDEC_FLG(a6)	* clr norm/denorm flag
	ICMP.b	EXC_LV+STAG(a6),#DENORM * is input a DENORM?
	bne.w	A2_str	* no; input is a NORM

*
* Normalize the denorm
*
un_de_norm:
	move.w	(a0),d0
	and.w	#$7fff,d0	* strip sign of normalized exp
	move.l	4(a0),d1
	move.l	8(a0),d2
norm_loop:
	sub.w	#1,d0
	lsl.l	#1,d2
	roxl.l	#1,d1
	tst.l	d1
	bge.b	norm_loop
*
* Test if the normalized input is denormalized
*
	tst.w	d0
	bgt.b	pos_exp	* if greater than zero, it is a norm
	st	BINDEC_FLG(a6)	* set flag for denorm
pos_exp:
	and.w	#$7fff,d0	* strip sign of normalized exp
	move.w	d0,(a0)
	move.l	d1,4(a0)
	move.l	d2,8(a0)

* A2. Set X = abs(input).
*
A2_str:
	move.l	(a0),EXC_LV+FP_SCR1(a6)	* move input to work space
	move.l	4(a0),EXC_LV+FP_SCR1+4(a6)	* move input to work space
	move.l	8(a0),EXC_LV+FP_SCR1+8(a6)	* move input to work space
	and.l	#$7fffffff,EXC_LV+FP_SCR1(a6)	* create abs(X)

* A3. Compute ILOG.
*     ILOG is the log base 10 of the input value.  It is approx-
*     imated by adding e + 0.f when the original value is viewed
*     as 2^^e * 1.f in extended precision.  This value is stored
*     in d6.
*
* Register usage:
*	Input/Output
*	d0: k-factor/exponent
*	d2: x/x
*	d3: x/x
*	d4: x/x
*	d5: x/x
*	d6: x/ILOG
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/final result
*	a1: x/x
*	a2: x/x
*	fp0: x/float(ILOG)
*	fp1: x/x
*	fp2: x/x
*	F_SCR1:x/x
*	F_SCR2:Abs(X)/Abs(X) with $3fff exponent
*	EXC_LV+L_SCR1:x/x
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

	tst.b	BINDEC_FLG(a6)	* check for denorm
	beq.b	A3_cont	* if clr, continue with norm
	move.l	#-4933,d6	* force ILOG = -4933
	bra.b	A4_str
A3_cont:
	move.w	EXC_LV+FP_SCR1(a6),d0	* move exp to d0
	move.w	#$3fff,EXC_LV+FP_SCR1(a6)	* replace exponent with $3fff
	fmove.x	EXC_LV+FP_SCR1(a6),fp0	* now fp0 has 1.f
	sub.w	#$3fff,d0	* strip off bias
	fadd.w	d0,fp0	* add in exp
	fsub.s	FONE(pc),fp0	* subtract off 1.0
	fbge.w	pos_res	* if pos, branch 
	fmul.x	PLOG2UP1(pc),fp0	* if neg, mul by LOG2UP1
	fmove.l	fp0,d6	* put ILOG in d6 as a lword
	bra.b	A4_str	* go move out ILOG
pos_res:
	fmul.x	PLOG2(pc),fp0	* if pos, mul by LOG2
	fmove.l	fp0,d6	* put ILOG in d6 as a lword


* A4. Clr INEX bit.
*     The operation in A3 above may have set INEX2.  

A4_str:
	fmove.l	#0,fpsr	* zero all of fpsr - nothing needed


* A5. Set ICTR = 0;
*     ICTR is a flag used in A13.  It must be set before the 
*     loop entry A6. The lower word of d5 is used for ICTR.

	clr.w	d5	* clear ICTR

* A6. Calculate LEN.
*     LEN is the number of digits to be displayed.  The k-factor
*     can dictate either the total number of digits, if it is
*     a positive number, or the number of digits after the
*     original decimal point which are to be included as
*     significant.  See the 68882 manual for examples.
*     If LEN is computed to be greater than 17, set OPERR in
*     USER_FPSR.  LEN is stored in d4.
*
* Register usage:
*	Input/Output
*	d0: exponent/Unchanged
*	d2: x/x/scratch
*	d3: x/x
*	d4: exc picture/LEN
*	d5: ICTR/Unchanged
*	d6: ILOG/Unchanged
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/final result
*	a1: x/x
*	a2: x/x
*	fp0: float(ILOG)/Unchanged
*	fp1: x/x
*	fp2: x/x
*	F_SCR1:x/x
*	F_SCR2:Abs(X) with $3fff exponent/Unchanged
*	EXC_LV+L_SCR1:x/x
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A6_str:
	tst.l	d7	* branch on sign of k
	ble.b	k_neg	* if k <= 0, LEN = ILOG + 1 - k
	move.l	d7,d4	* if k > 0, LEN = k
	bra.b	len_ck	* skip to LEN check
k_neg:
	move.l	d6,d4	* first load ILOG to d4
	sub.l	d7,d4	* subtract off k
	addq.l	#1,d4	* add in the 1
len_ck:
	tst.l	d4	* LEN check: branch on sign of LEN
	ble.b	LEN_ng	* if neg, set LEN = 1
	ICMP.l	d4,#17	* test if LEN > 17
	ble.b	A7_str	* if not, forget it
	move.l	#17,d4	* set max LEN = 17
	tst.l	d7	* if negative, never set OPERR
	ble.b	A7_str	* if positive, continue
	or.l	#opaop_mask,EXC_LV+USER_FPSR(a6)	* set OPERR # AIOP in USER_FPSR
	bra.b	A7_str	* finished here
LEN_ng:
	move.l	#1,d4	* min LEN is 1


* A7. Calculate SCALE.
*     SCALE is equal to 10^ISCALE, where ISCALE is the number
*     of decimal places needed to insure LEN integer digits
*     in the output before conversion to bcd. LAMBDA is the sign
*     of ISCALE, used in A9.  Fp1 contains 10^^(abs(ISCALE)) using
*     the rounding mode as given in the following table (see
*     Coonen, p. 7.23 as ref.; however, the SCALE variable is
*     of opposite sign in bindec.sa from Coonen).
*
*	Initial		USE
*	FPCR[6:5]	LAMBDA	SIGN(X)	FPCR[6:5]
*	----------------------------------------------
*	 RN	00	   0	   0	00/0	RN
*	 RN	00	   0	   1	00/0	RN
*	 RN	00	   1	   0	00/0	RN
*	 RN	00	   1	   1	00/0	RN
*	 RZ	01	   0	   0	11/3	RP
*	 RZ	01	   0	   1	11/3	RP
*	 RZ	01	   1	   0	10/2	RM
*	 RZ	01	   1	   1	10/2	RM
*	 RM	10	   0	   0	11/3	RP
*	 RM	10	   0	   1	10/2	RM
*	 RM	10	   1	   0	10/2	RM
*	 RM	10	   1	   1	11/3	RP
*	 RP	11	   0	   0	10/2	RM
*	 RP	11	   0	   1	11/3	RP
*	 RP	11	   1	   0	11/3	RP
*	 RP	11	   1	   1	10/2	RM
*
* Register usage:
*	Input/Output
*	d0: exponent/scratch - final is 0
*	d2: x/0 or 24 for A9
*	d3: x/scratch - offset ptr into PTENRM array
*	d4: LEN/Unchanged
*	d5: 0/ICTR:LAMBDA
*	d6: ILOG/ILOG or k if ((k<=0)#(ILOG<k))
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/final result
*	a1: x/ptr to PTENRM array
*	a2: x/x
*	fp0: float(ILOG)/Unchanged
*	fp1: x/10^ISCALE
*	fp2: x/x
*	F_SCR1:x/x
*	F_SCR2:Abs(X) with $3fff exponent/Unchanged
*	EXC_LV+L_SCR1:x/x
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A7_str:
	tst.l	d7	* test sign of k
	bgt.b	k_pos	* if pos and > 0, skip this
	ICMP.l	d7,d6	* test k - ILOG
	blt.b	k_pos	* if ILOG >= k, skip this
	move.l	d7,d6	* if ((k<0) # (ILOG < k)) ILOG = k
k_pos:
	move.l	d6,d0	* calc ILOG + 1 - LEN in d0
	addq.l	#1,d0	* add the 1
	sub.l	d4,d0	* sub off LEN
	swap	d5	* use upper word of d5 for LAMBDA
	clr.w	d5	* set it zero initially
	clr.w	d2	* set up d2 for very small case
	tst.l	d0	* test sign of ISCALE
	bge.b	iscale	* if pos, skip next inst
	addq.w	#1,d5	* if neg, set LAMBDA true
	ICMP.l	d0,#$ffffecd4	* test iscale <= -4908
	bgt.b	no_inf	* if false, skip rest
	add.l	#24,d0	* add in 24 to iscale
	move.l	#24,d2	* put 24 in d2 for A9
no_inf:
	neg.l	d0	* and take abs of ISCALE
iscale:
	fmove.s	FONE(pc),fp1	* init fp1 to 1
	bfextu	EXC_LV+USER_FPCR(a6){26:2},d1	* get initial rmode bits
	lsl.w	#1,d1	* put them in bits 2:1
	add.w	d5,d1	* add in LAMBDA
	lsl.w	#1,d1	* put them in bits 3:1
	tst.l	EXC_LV+L_SCR2(a6)	* test sign of original x
	bge.b	x_pos	* if pos, don't set bit 0
	addq.l	#1,d1	* if neg, set bit 0
x_pos:
	lea.l	RBDTBL(pc),a2	* load rbdtbl base
	move.b	(a2,d1),d3	* load d3 with new rmode
	lsl.l	#4,d3	* put bits in proper position
	fmove.l	d3,fpcr	* load bits into fpu
	lsr.l	#4,d3	* put bits in proper position
	tst.b	d3	* decode new rmode for pten table
	bne.b	not_rn	* if zero, it is RN
	lea.l	PTENRN(pc),a1	* load a1 with RN table base
	bra.b	rmode	* exit decode
not_rn:
	lsr.b	#1,d3	* get lsb in carry
	bcc.b	not_rp2	* if carry clear, it is RM
	lea.l	PTENRP(pc),a1	* load a1 with RP table base
	bra.b	rmode	* exit decode
not_rp2:
	lea.l	PTENRM(pc),a1	* load a1 with RM table base
rmode:
	clr.l	d3	* clr table index
e_loop2:
	lsr.l	#1,d0	* shift next bit into carry
	bcc.b	e_next2	* if zero, skip the mul
	fmul.x	(a1,d3),fp1	* mul by 10**(d3_bit_no)
e_next2:
	add.l	#12,d3	* inc d3 to next pwrten table entry
	tst.l	d0	* test if ISCALE is zero
	bne.b	e_loop2	* if not, loop

* A8. Clr INEX; Force RZ.
*     The operation in A3 above may have set INEX2.  
*     RZ mode is forced for the scaling operation to insure
*     only one rounding error.  The grs bits are collected in 
*     the INEX flag for use in A10.
*
* Register usage:
*	Input/Output

	fmove.l	#0,fpsr	* clr INEX 
	fmove.l	#rz_mode*$10,fpcr	* set RZ rounding mode

* A9. Scale X -> Y.
*     The mantissa is scaled to the desired number of significant
*     digits.  The excess digits are collected in INEX2. If mul,
*     Check d2 for excess 10 exponential value.  If not zero, 
*     the iscale value would have caused the pwrten calculation
*     to overflow.  Only a negative iscale can cause this, so
*     multiply by 10^(d2), which is now only allowed to be 24,
*     with a multiply by 10^8 and 10^16, which is exact since
*     10^24 is exact.  If the input was denormalized, we must
*     create a busy stack frame with the mul command and the
*     two operands, and allow the fpu to complete the multiply.
*
* Register usage:
*	Input/Output
*	d0: FPCR with RZ mode/Unchanged
*	d2: 0 or 24/unchanged
*	d3: x/x
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA
*	d6: ILOG/Unchanged
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/final result
*	a1: ptr to PTENRM array/Unchanged
*	a2: x/x
*	fp0: float(ILOG)/X adjusted for SCALE (Y)
*	fp1: 10^ISCALE/Unchanged
*	fp2: x/x
*	F_SCR1:x/x
*	F_SCR2:Abs(X) with $3fff exponent/Unchanged
*	EXC_LV+L_SCR1:x/x
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A9_str:
	fmove.x	(a0),fp0	* load X from memory
	fabs.x	fp0	* use abs(X)
	tst.w	d5	* LAMBDA is in lower word of d5
	bne.b	sc_mul	* if neg (LAMBDA = 1), scale by mul
	fdiv.x	fp1,fp0	* calculate X / SCALE -> Y to fp0
	bra.w	A10_st	* branch to A10

sc_mul:
	tst.b	BINDEC_FLG(a6)	* check for denorm
	beq.w	A9_norm	* if norm, continue with mul

* for DENORM, we must calculate:
*	fp0 = input_op * 10^ISCALE * 10^24
* since the input operand is a DENORM, we can't multiply it directly.
* so, we do the multiplication of the exponents and mantissas separately.
* in this way, we avoid underflow on intermediate EXC_LV+STAGes of the
* multiplication and guarantee a result without exception.
	fmovem.x	fp1,-(sp)	* save 10^ISCALE to stack

	move.w	(sp),d3	* grab exponent
	andi.w	#$7fff,d3	* clear sign
	ori.w	#$8000,(a0)	* make DENORM exp negative
	add.w	(a0),d3	* add DENORM exp to 10^ISCALE exp
	subi.w	#$3fff,d3	* subtract BIAS
	add.w	36(a1),d3
	subi.w	#$3fff,d3	* subtract BIAS
	add.w	48(a1),d3
	subi.w	#$3fff,d3	* subtract BIAS

	bmi.w	sc_mul_err	* is result is DENORM, punt!!!

	andi.w	#$8000,(sp)	* keep sign
	or.w	d3,(sp)	* insert new exponent
	andi.w	#$7fff,(a0)	* clear sign bit on DENORM again
	move.l	$8(a0),-(sp) * put input op mantissa on stk
	move.l	$4(a0),-(sp)
	move.l	#$3fff0000,-(sp) * force exp to zero
	fmovem.x	(sp)+,fp0	* load normalized DENORM into fp0
	fmul.x	(sp)+,fp0

*	fmul.x	36(a1),fp0	* multiply fp0 by 10^8
*	fmul.x	48(a1),fp0	* multiply fp0 by 10^16
	move.l	36+8(a1),-(sp) * get 10^8 mantissa
	move.l	36+4(a1),-(sp)
	move.l	#$3fff0000,-(sp) * force exp to zero
	move.l	48+8(a1),-(sp) * get 10^16 mantissa
	move.l	48+4(a1),-(sp)
	move.l	#$3fff0000,-(sp) * force exp to zero
	fmul.x	(sp)+,fp0	* multiply fp0 by 10^8
	fmul.x	(sp)+,fp0	* multiply fp0 by 10^16
	bra.b	A10_st

sc_mul_err:
	bra.b	sc_mul_err

A9_norm:
	tst.w	d2	* test for small exp case
	beq.b	A9_con	* if zero, continue as normal
	fmul.x	36(a1),fp0	* multiply fp0 by 10^8
	fmul.x	48(a1),fp0	* multiply fp0 by 10^16
A9_con:
	fmul.x	fp1,fp0	* calculate X * SCALE -> Y to fp0

* A10. Or in INEX.
*      If INEX is set, round error occured.  This is compensated
*      for by 'or-ing' in the INEX2 flag to the lsb of Y.
*
* Register usage:
*	Input/Output
*	d0: FPCR with RZ mode/FPSR with INEX2 isolated
*	d2: x/x
*	d3: x/x
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA
*	d6: ILOG/Unchanged
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/final result
*	a1: ptr to PTENxx array/Unchanged
*	a2: x/ptr to EXC_LV+FP_SCR1(a6)
*	fp0: Y/Y with lsb adjusted
*	fp1: 10^ISCALE/Unchanged
*	fp2: x/x

A10_st:
	fmove.l	fpsr,d0	* get FPSR
	fmove.x	fp0,EXC_LV+FP_SCR1(a6)	* move Y to memory
	lea.l	EXC_LV+FP_SCR1(a6),a2	* load a2 with ptr to EXC_LV+FP_SCR1
	btst	#9,d0	* check if INEX2 set
	beq.b	A11_st	* if clear, skip rest
	or.l	#1,8(a2)	* or in 1 to lsb of mantissa
	fmove.x	EXC_LV+FP_SCR1(a6),fp0	* write adjusted Y back to fpu


* A11. Restore original FPCR; set size ext.
*      Perform FINT operation in the user's rounding mode.  Keep
*      the size to extended.  The sintdo entry point in the sint
*      routine expects the FPCR value to be in EXC_LV+USER_FPCR for
*      mode and precision.  The original FPCR is saved in EXC_LV+L_SCR1.

A11_st:
	move.l	EXC_LV+USER_FPCR(a6),EXC_LV+L_SCR1(a6)	* save it for later
	and.l	#$00000030,EXC_LV+USER_FPCR(a6)	* set size to ext,
*		;block exceptions


* A12. Calculate YINT = FINT(Y) according to user's rounding mode.
*      The FPSP routine sintd0 is used.  The output is in fp0.
*
* Register usage:
*	Input/Output
*	d0: FPSR with AINEX cleared/FPCR with size set to ext
*	d2: x/x/scratch
*	d3: x/x
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA/Unchanged
*	d6: ILOG/Unchanged
*	d7: k-factor/Unchanged
*	a0: ptr for original operand/src ptr for sintdo
*	a1: ptr to PTENxx array/Unchanged
*	a2: ptr to EXC_LV+FP_SCR1(a6)/Unchanged
*	a6: temp pointer to EXC_LV+FP_SCR1(a6) - orig value saved and restored
*	fp0: Y/YINT
*	fp1: 10^ISCALE/Unchanged
*	fp2: x/x
*	F_SCR1:x/x
*	F_SCR2:Y adjusted for inex/Y with original exponent
*	EXC_LV+L_SCR1:x/original EXC_LV+USER_FPCR
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A12_st:
	movem.l	d0-d1/a0-a1,-(sp)	* save regs used by sintd0	 {d0-d1/a0-a1}
	move.l	EXC_LV+L_SCR1(a6),-(sp)
	move.l	EXC_LV+L_SCR2(a6),-(sp)

	lea.l	EXC_LV+FP_SCR1(a6),a0	* a0 is ptr to EXC_LV+FP_SCR1(a6)
	fmove.x	fp0,(a0)	* move Y to memory at EXC_LV+FP_SCR1(a6)
	tst.l	EXC_LV+L_SCR2(a6)	* test sign of original operand
	bge.b	do_fint12	* if pos, use Y 
	or.l	#$80000000,(a0)	* if neg, use -Y
do_fint12:
	move.l	EXC_LV+USER_FPSR(a6),-(sp)
*	bsr	sintdo	* sint routine returns int in fp0

	fmove.l	EXC_LV+USER_FPCR(a6),fpcr
	fmove.l	#$0,fpsr	* clear the AEXC bits!!!
**	move.l	EXC_LV+USER_FPCR(a6),d0	* ext prec/keep rnd mode
**	andi.l	#$00000030,d0
**	fmove.l	d0,fpcr
	fint.x	EXC_LV+FP_SCR1(a6),fp0	* do fint()
	fmove.l	fpsr,d0
	or.w	d0,EXC_LV+FPSR_EXCEPT(a6)
**	fmove.l	#$0,fpcr
**	fmove.l	fpsr,d0	* don't keep ccodes
**	or.w	d0,EXC_LV+FPSR_EXCEPT(a6)

	move.b	(sp),EXC_LV+USER_FPSR(a6)
	add.l	#4,sp

	move.l	(sp)+,EXC_LV+L_SCR2(a6)
	move.l	(sp)+,EXC_LV+L_SCR1(a6)
	movem.l	(sp)+,d0-d1/a0-a1	* restore regs used by sint	 {d0-d1/a0-a1}

	move.l	EXC_LV+L_SCR2(a6),EXC_LV+FP_SCR1(a6)	* restore original exponent
	move.l	EXC_LV+L_SCR1(a6),EXC_LV+USER_FPCR(a6)	* restore user's FPCR

* A13. Check for LEN digits.
*      If the int operation results in more than LEN digits,
*      or less than LEN -1 digits, adjust ILOG and repeat from
*      A6.  This test occurs only on the first pass.  If the
*      result is exactly 10^LEN, decrement ILOG and divide
*      the mantissa by 10.  The calculation of 10^LEN cannot
*      be inexact, since all powers of ten upto 10^27 are exact
*      in extended precision, so the use of a previous power-of-ten
*      table will introduce no error.
*
*
* Register usage:
*	Input/Output
*	d0: FPCR with size set to ext/scratch final = 0
*	d2: x/x
*	d3: x/scratch final = x
*	d4: LEN/LEN adjusted
*	d5: ICTR:LAMBDA/LAMBDA:ICTR
*	d6: ILOG/ILOG adjusted
*	d7: k-factor/Unchanged
*	a0: pointer into memory for packed bcd string formation
*	a1: ptr to PTENxx array/Unchanged
*	a2: ptr to EXC_LV+FP_SCR1(a6)/Unchanged
*	fp0: int portion of Y/abs(YINT) adjusted
*	fp1: 10^ISCALE/Unchanged
*	fp2: x/10^LEN
*	F_SCR1:x/x
*	F_SCR2:Y with original exponent/Unchanged
*	EXC_LV+L_SCR1:original EXC_LV+USER_FPCR/Unchanged
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A13_st:
	swap	d5	* put ICTR in lower word of d5
	tst.w	d5	* check if ICTR = 0
	bne	not_zr	* if non-zero, go to second test
*
* Compute 10^(LEN-1)
*
	fmove.s	FONE(pc),fp2	* init fp2 to 1.0
	move.l	d4,d0	* put LEN in d0
	subq.l	#1,d0	* d0 = LEN -1
	clr.l	d3	* clr table index
l_loop:
	lsr.l	#1,d0	* shift next bit into carry
	bcc.b	l_next	* if zero, skip the mul
	fmul.x	(a1,d3),fp2	* mul by 10**(d3_bit_no)
l_next:
	add.l	#12,d3	* inc d3 to next pwrten table entry
	tst.l	d0	* test if LEN is zero
	bne.b	l_loop	* if not, loop
*
* 10^LEN-1 is computed for this test and A14.  If the input was
* denormalized, check only the case in which YINT > 10^LEN.
*
	tst.b	BINDEC_FLG(a6)	* check if input was norm
	beq.b	A13_con	* if norm, continue with checking
	fabs.x	fp0	* take abs of YINT
	bra	test_2
*
* Compare abs(YINT) to 10^(LEN-1) and 10^LEN
*
A13_con:
	fabs.x	fp0	* take abs of YINT
	fcmp.x	fp0,fp2	* compare abs(YINT) with 10^(LEN-1)
	fbge.w	test_2	* if greater, do next test
	subq.l	#1,d6	* subtract 1 from ILOG
	move.w	#1,d5	* set ICTR
	fmove.l	#rm_mode*$10,fpcr	* set rmode to RM
	fmul.s	FTEN(pc),fp2	* compute 10^LEN 
	bra.w	A6_str	* return to A6 and recompute YINT
test_2:
	fmul.s	FTEN(pc),fp2	* compute 10^LEN
	fcmp.x	fp0,fp2	* compare abs(YINT) with 10^LEN
	fblt.w	A14_st	* if less, all is ok, go to A14
	fbgt.w	fix_ex	* if greater, fix and redo
	fdiv.s	FTEN(pc),fp0	* if equal, divide by 10
	addq.l	#1,d6	* and inc ILOG
	bra.b	A14_st	* and continue elsewhere
fix_ex:
	addq.l	#1,d6	* increment ILOG by 1
	move.w	#1,d5	* set ICTR
	fmove.l	#rm_mode*$10,fpcr	* set rmode to RM
	bra.w	A6_str	* return to A6 and recompute YINT
*
* Since ICTR <> 0, we have already been through one adjustment, 
* and shouldn't have another; this is to check if abs(YINT) = 10^LEN
* 10^LEN is again computed using whatever table is in a1 since the
* value calculated cannot be inexact.
*
not_zr:
	fmove.s	FONE(pc),fp2	* init fp2 to 1.0
	move.l	d4,d0	* put LEN in d0
	clr.l	d3	* clr table index
z_loop:
	lsr.l	#1,d0	* shift next bit into carry
	bcc.b	z_next	* if zero, skip the mul
	fmul.x	(a1,d3),fp2	* mul by 10**(d3_bit_no)
z_next:
	add.l	#12,d3	* inc d3 to next pwrten table entry
	tst.l	d0	* test if LEN is zero
	bne.b	z_loop	* if not, loop
	fabs.x	fp0	* get abs(YINT)
	fcmp.x	fp0,fp2	* check if abs(YINT) = 10^LEN
	fbne.w	A14_st	* if not, skip this
	fdiv.s	FTEN(pc),fp0	* divide abs(YINT) by 10
	addq.l	#1,d6	* and inc ILOG by 1
	addq.l	#1,d4	* and inc LEN
	fmul.s	FTEN(pc),fp2	* if LEN++, the get 10^^LEN

* A14. Convert the mantissa to bcd.
*      The binstr routine is used to convert the LEN digit 
*      mantissa to bcd in memory.  The input to binstr is
*      to be a fraction; i.e. (mantissa)/10^LEN and adjusted
*      such that the decimal point is to the left of bit 63.
*      The bcd digits are stored in the correct position in 
*      the final string area in memory.
*
*
* Register usage:
*	Input/Output
*	d0: x/LEN call to binstr - final is 0
*	d1: x/0
*	d2: x/ms 32-bits of mant of abs(YINT)
*	d3: x/ls 32-bits of mant of abs(YINT)
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA/LAMBDA:ICTR
*	d6: ILOG
*	d7: k-factor/Unchanged
*	a0: pointer into memory for packed bcd string formation
*	    /ptr to first mantissa byte in result string
*	a1: ptr to PTENxx array/Unchanged
*	a2: ptr to EXC_LV+FP_SCR1(a6)/Unchanged
*	fp0: int portion of Y/abs(YINT) adjusted
*	fp1: 10^ISCALE/Unchanged
*	fp2: 10^LEN/Unchanged
*	F_SCR1:x/Work area for final result
*	F_SCR2:Y with original exponent/Unchanged
*	EXC_LV+L_SCR1:original EXC_LV+USER_FPCR/Unchanged
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A14_st:
	fmove.l	#rz_mode*$10,fpcr	* force rz for conversion
	fdiv.x	fp2,fp0	* divide abs(YINT) by 10^LEN
	lea.l	EXC_LV+FP_SCR0(a6),a0
	fmove.x	fp0,(a0)	* move abs(YINT)/10^LEN to memory
	move.l	4(a0),d2	* move 2nd word of EXC_LV+FP_RES to d2
	move.l	8(a0),d3	* move 3rd word of EXC_LV+FP_RES to d3
	clr.l	4(a0)	* zero word 2 of EXC_LV+FP_RES
	clr.l	8(a0)	* zero word 3 of EXC_LV+FP_RES
	move.l	(a0),d0	* move exponent to d0
	swap	d0	* put exponent in lower word
	beq.b	no_sft	* if zero, don't shift
	sub.l	#$3ffd,d0	* sub bias less 2 to make fract
	tst.l	d0	* check if > 1
	bgt.b	no_sft	* if so, don't shift
	neg.l	d0	* make exp positive
m_loop:
	lsr.l	#1,d2	* shift d2:d3 right, add 0s 
	roxr.l	#1,d3	* the number of places
	dbf.w	d0,m_loop	* given in d0
no_sft:
	tst.l	d2	* check for mantissa of zero
	bne.b	no_zr	* if not, go on
	tst.l	d3	* continue zero check
	beq.b	zer_m	* if zero, go directly to binstr
no_zr:
	clr.l	d1	* put zero in d1 for addx
	add.l	#$00000080,d3	* inc at bit 7
	addx.l	d1,d2	* continue inc
	and.l	#$ffffff80,d3	* strip off lsb not used by 882
zer_m:
	move.l	d4,d0	* put LEN in d0 for binstr call
	addq.l	#3,a0	* a0 points to M16 byte in result
	bsr	binstr	* call binstr to convert mant


* A15. Convert the exponent to bcd.
*      As in A14 above, the exp is converted to bcd and the
*      digits are stored in the final string.
*
*      Digits are stored in EXC_LV+L_SCR1(a6) on return from BINDEC as:
*
*  	 32               16 15                0
*	-----------------------------------------
*  	|  0 | e3 | e2 | e1 | e4 |  X |  X |  X |
*	-----------------------------------------
*
* And are moved into their proper places in EXC_LV+FP_SCR0.  If digit e4
* is non-zero, OPERR is signaled.  In all cases, all 4 digits are
* written as specified in the 881/882 manual for packed decimal.
*
* Register usage:
*	Input/Output
*	d0: x/LEN call to binstr - final is 0
*	d1: x/scratch (0);shift count for final exponent packing
*	d2: x/ms 32-bits of exp fraction/scratch
*	d3: x/ls 32-bits of exp fraction
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA/LAMBDA:ICTR
*	d6: ILOG
*	d7: k-factor/Unchanged
*	a0: ptr to result string/ptr to EXC_LV+L_SCR1(a6)
*	a1: ptr to PTENxx array/Unchanged
*	a2: ptr to EXC_LV+FP_SCR1(a6)/Unchanged
*	fp0: abs(YINT) adjusted/float(ILOG)
*	fp1: 10^ISCALE/Unchanged
*	fp2: 10^LEN/Unchanged
*	F_SCR1:Work area for final result/BCD result
*	F_SCR2:Y with original exponent/ILOG/10^4
*	EXC_LV+L_SCR1:original EXC_LV+USER_FPCR/Exponent digits on return from binstr
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A15_st:
	tst.b	BINDEC_FLG(a6)	* check for denorm
	beq.b	not_denorm
	ftst.x	fp0	* test for zero
	fbeq.w	den_zero	* if zero, use k-factor or 4933
	fmove.l	d6,fp0	* float ILOG
	fabs.x	fp0	* get abs of ILOG
	bra.b	convrt
den_zero:
	tst.l	d7	* check sign of the k-factor
	blt.b	use_ilog	* if negative, use ILOG
	fmove.s	F4933(pc),fp0	* force exponent to 4933
	bra.b	convrt	* do it
use_ilog:
	fmove.l	d6,fp0	* float ILOG
	fabs.x	fp0	* get abs of ILOG
	bra.b	convrt
not_denorm:
	ftst.x	fp0	* test for zero
	fbne.w	not_zero	* if zero, force exponent
	fmove.s	FONE(pc),fp0	* force exponent to 1
	bra.b	convrt	* do it
not_zero:
	fmove.l	d6,fp0	* float ILOG
	fabs.x	fp0	* get abs of ILOG
convrt:
	fdiv.x	24(a1),fp0	* compute ILOG/10^4
	fmove.x	fp0,EXC_LV+FP_SCR1(a6)	* store fp0 in memory
	move.l	4(a2),d2	* move word 2 to d2
	move.l	8(a2),d3	* move word 3 to d3
	move.w	(a2),d0	* move exp to d0
	beq.b	x_loop_fin	* if zero, skip the shift
	sub.w	#$3ffd,d0	* subtract off bias
	neg.w	d0	* make exp positive
x_loop:
	lsr.l	#1,d2	* shift d2:d3 right 
	roxr.l	#1,d3	* the number of places
	dbf.w	d0,x_loop	* given in d0
x_loop_fin:
	clr.l	d1	* put zero in d1 for addx
	add.l	#$00000080,d3	* inc at bit 6
	addx.l	d1,d2	* continue inc
	and.l	#$ffffff80,d3	* strip off lsb not used by 882
	move.l	#4,d0	* put 4 in d0 for binstr call
	lea.l	EXC_LV+L_SCR1(a6),a0	* a0 is ptr to EXC_LV+L_SCR1 for exp digits
	bsr	binstr	* call binstr to convert exp
	move.l	EXC_LV+L_SCR1(a6),d0	* load EXC_LV+L_SCR1 lword to d0 
	move.l	#12,d1	* use d1 for shift count
	lsr.l	d1,d0	* shift d0 right by 12
	bfins	d0,EXC_LV+FP_SCR0(a6){4:12}	* put e3:e2:e1 in EXC_LV+FP_SCR0
	lsr.l	d1,d0	* shift d0 right by 12
	bfins	d0,EXC_LV+FP_SCR0(a6){16:4}	* put e4 in EXC_LV+FP_SCR0
	tst.b	d0	* check if e4 is zero
	beq.b	A16_st	* if zero, skip rest
	or.l	#opaop_mask,EXC_LV+USER_FPSR(a6)	* set OPERR # AIOP in USER_FPSR


* A16. Write sign bits to final string.
*	   Sigma is bit 31 of initial value; RHO is bit 31 of d6 (ILOG).
*
* Register usage:
*	Input/Output
*	d0: x/scratch - final is x
*	d2: x/x
*	d3: x/x
*	d4: LEN/Unchanged
*	d5: ICTR:LAMBDA/LAMBDA:ICTR
*	d6: ILOG/ILOG adjusted
*	d7: k-factor/Unchanged
*	a0: ptr to EXC_LV+L_SCR1(a6)/Unchanged
*	a1: ptr to PTENxx array/Unchanged
*	a2: ptr to EXC_LV+FP_SCR1(a6)/Unchanged
*	fp0: float(ILOG)/Unchanged
*	fp1: 10^ISCALE/Unchanged
*	fp2: 10^LEN/Unchanged
*	F_SCR1:BCD result with correct signs
*	F_SCR2:ILOG/10^4
*	EXC_LV+L_SCR1:Exponent digits on return from binstr
*	EXC_LV+L_SCR2:first word of X packed/Unchanged

A16_st:
	clr.l	d0	* clr d0 for collection of signs
	and.b	#$0f,EXC_LV+FP_SCR0(a6)	* clear first nibble of EXC_LV+FP_SCR0 
	tst.l	EXC_LV+L_SCR2(a6)	* check sign of original mantissa
	bge.b	mant_p	* if pos, don't set SM
	move.l	#2,d0	* move 2 in to d0 for SM
mant_p:
	tst.l	d6	* check sign of ILOG
	bge.b	wr_sgn	* if pos, don't set SE
	addq.l	#1,d0	* set bit 0 in d0 for SE 
wr_sgn:
	bfins	d0,EXC_LV+FP_SCR0(a6){0:2}	* insert SM and SE into EXC_LV+FP_SCR0

* Clean up and restore all registers used.

	fmove.l	#0,fpsr	* clear possible inex2/ainex bits
	fmovem.x	(sp)+,fp0-fp2	*  {fp0-fp2}
	movem.l	(sp)+,d2-d7/a2	*  {d2-d7/a2}
	rts

	xdef	PTENRN
PTENRN:
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59E	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D5	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CE0	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8E	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C7	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C17	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE5	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979B	* 10 ^ 4096

	xdef	PTENRP
PTENRP:
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59E	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D6	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CE0	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8E	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C7	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C18	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE5	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979B	* 10 ^ 4096

	xdef	PTENRM
PTENRM:
	dc.l	$40020000,$A0000000,$00000000	* 10 ^ 1
	dc.l	$40050000,$C8000000,$00000000	* 10 ^ 2
	dc.l	$400C0000,$9C400000,$00000000	* 10 ^ 4
	dc.l	$40190000,$BEBC2000,$00000000	* 10 ^ 8
	dc.l	$40340000,$8E1BC9BF,$04000000	* 10 ^ 16
	dc.l	$40690000,$9DC5ADA8,$2B70B59D	* 10 ^ 32
	dc.l	$40D30000,$C2781F49,$FFCFA6D5	* 10 ^ 64
	dc.l	$41A80000,$93BA47C9,$80E98CDF	* 10 ^ 128
	dc.l	$43510000,$AA7EEBFB,$9DF9DE8D	* 10 ^ 256
	dc.l	$46A30000,$E319A0AE,$A60E91C6	* 10 ^ 512
	dc.l	$4D480000,$C9767586,$81750C17	* 10 ^ 1024
	dc.l	$5A920000,$9E8B3B5D,$C53D5DE4	* 10 ^ 2048
	dc.l	$75250000,$C4605202,$8A20979A	* 10 ^ 4096

**-------------------------------------------------------------------------------------------------
* binstr(): Converts a 64-bit binary integer to bcd.
*		
* INPUT *************************************************************** *
*	d2:d3 = 64-bit binary integer	
*	d0    = desired length (LEN)	
*	a0    = pointer to start in memory for bcd characters
*          	(This pointer must point to byte 4 of the first
*          	 lword of the packed decimal memory string.)
*		
* OUTPUT ************************************************************** *
*	a0 = pointer to LEN bcd digits representing the 64-bit integer.
*		
* ALGORITHM ***********************************************************
*	The 64-bit binary is assumed to have a decimal point before
*	bit 63.  The fraction is multiplied by 10 using a mul by 2
*	shift and a mul by 8 shift.  The bits shifted out of the
*	msb form a decimal digit.  This process is iterated until
*	LEN digits are formed.	
*		
* A1. Init d7 to 1.  D7 is the byte digit counter, and if 1, the
*     digit formed will be assumed the least significant.  This is
*     to force the first byte formed to have a 0 in the upper 4 bits.
*		
* A2. Beginning of the loop:	
*     Copy the fraction in d2:d3 to d4:d5.
*		
* A3. Multiply the fraction in d2:d3 by 8 using bit-field
*     extracts and shifts.  The three msbs from d2 will go into d1.
*		
* A4. Multiply the fraction in d4:d5 by 2 using shifts.  The msb
*     will be collected by the carry.	
*		
* A5. Add using the carry the 64-bit quantities in d2:d3 and d4:d5
*     into d2:d3.  D1 will contain the bcd digit formed.
*		
* A6. Test d7.  If zero, the digit formed is the ms digit.  If non-
*     zero, it is the ls digit.  Put the digit in its place in the
*     upper word of d0.  If it is the ls digit, write the word
*     from d0 to memory.	
*		
* A7. Decrement d6 (LEN counter) and repeat the loop until zero.
*		
**-------------------------------------------------------------------------------------------------

*	Implementation Notes:
*
*	The registers are used as follows:
*
*	d0: LEN counter
*	d1: temp used to form the digit
*	d2: upper 32-bits of fraction for mul by 8
*	d3: lower 32-bits of fraction for mul by 8
*	d4: upper 32-bits of fraction for mul by 2
*	d5: lower 32-bits of fraction for mul by 2
*	d6: temp for bit-field extracts
*	d7: byte digit formation word;digit count {0,1}
*	a0: pointer into memory for packed bcd string formation
*

	xdef	binstr
binstr:
	movem.l	d0-d7,-(sp)	*  {d0-d7}

*
* A1: Init d7
*
	move.l	#1,d7	* init d7 for second digit
	subq.l	#1,d0	* for dbf d0 would have LEN+1 passes
*
* A2. Copy d2:d3 to d4:d5.  Start loop.
*
loop:
	move.l	d2,d4	* copy the fraction before muls
	move.l	d3,d5	* to d4:d5
*
* A3. Multiply d2:d3 by 8; extract msbs into d1.
*
	bfextu	d2{0:3},d1	* copy 3 msbs of d2 into d1
	asl.l	#3,d2	* shift d2 left by 3 places
	bfextu	d3{0:3},d6	* copy 3 msbs of d3 into d6
	asl.l	#3,d3	* shift d3 left by 3 places
	or.l	d6,d2	* or in msbs from d3 into d2
*
* A4. Multiply d4:d5 by 2; add carry out to d1.
*
	asl.l	#1,d5	* mul d5 by 2
	roxl.l	#1,d4	* mul d4 by 2
	swap	d6	* put 0 in d6 lower word
	addx.w	d6,d1	* add in extend from mul by 2
*
* A5. Add mul by 8 to mul by 2.  D1 contains the digit formed.
*
	add.l	d5,d3	* add lower 32 bits
	nop	* ERRATA FIX *13 (Rev. 1.2 6/6/90)
	addx.l	d4,d2	* add with extend upper 32 bits
	nop	* ERRATA FIX *13 (Rev. 1.2 6/6/90)
	addx.w	d6,d1	* add in extend from add to d1
	swap	d6	* with d6 = 0; put 0 in upper word
*
* A6. Test d7 and branch.
*
	tst.w	d7	* if zero, store digit # to loop
	beq.b	first_d	* if non-zero, form byte # write
sec_d:
	swap	d7	* bring first digit to word d7b
	asl.w	#4,d7	* first digit in upper 4 bits d7b
	add.w	d1,d7	* add in ls digit to d7b
	move.b	d7,(a0)+	* store d7b byte in memory
	swap	d7	* put LEN counter in word d7a
	clr.w	d7	* set d7a to signal no digits done
	dbf.w	d0,loop	* do loop some more!
	bra.b	end_bstr	* finished, so exit
first_d:
	swap	d7	* put digit word in d7b
	move.w	d1,d7	* put new digit in d7b
	swap	d7	* put LEN counter in word d7a
	addq.w	#1,d7	* set d7a to signal first digit done
	dbf.w	d0,loop	* do loop some more!
	swap	d7	* put last digit in string
	lsl.w	#4,d7	* move it to upper 4 bits
	move.b	d7,(a0)+	* store it in memory string
*
* Clean up and return with result in fp0.
*
end_bstr:
	movem.l	(sp)+,d0-d7	*  {d0-d7}
	rts





**-------------------------------------------------------------------------------------------------
* XDEF **
*	facc_in_b(): dmem_read_byte failed
*	facc_in_w(): dmem_read_word failed
*	facc_in_l(): dmem_read_long failed
*	facc_in_d(): dmem_read of dbl prec failed
*	facc_in_x(): dmem_read of ext prec failed
*		
*	facc_out_b(): dmem_write_byte failed
*	facc_out_w(): dmem_write_word failed
*	facc_out_l(): dmem_write_long failed
*	facc_out_d(): dmem_write of dbl prec failed
*	facc_out_x(): dmem_write of ext prec failed
*		
* xdef **
*	_real_access() - exit through access error handler
*		
* INPUT ***************************************************************
*	None	
* 		
* OUTPUT **************************************************************
*	None	
*		
* ALGORITHM ***********************************************************
*
* 	Flow jumps here when an FP data fetch call gets an error 
* result. This means the operating system wants an access error frame
* made out of the current exception stack frame. 
*	So, we first call restore() which makes sure that any updated
* -(an)+ register gets returned to its pre-exception value and then
* we change the stack to an acess error stack frame.
*		
**-------------------------------------------------------------------------------------------------

facc_in_b:
	moveq.l	#$1,d0	* one byte
	bsr.w	restore	* fix An

	move.w	#$0121,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.w	facc_finish

facc_in_w:
	moveq.l	#$2,d0	* two bytes
	bsr.w	restore	* fix An

	move.w	#$0141,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_in_l:
	moveq.l	#$4,d0	* four bytes
	bsr.w	restore	* fix An

	move.w	#$0101,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_in_d:
	moveq.l	#$8,d0	* eight bytes
	bsr.w	restore	* fix An

	move.w	#$0161,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_in_x:
	moveq.l	#$c,d0	* twelve bytes
	bsr.w	restore	* fix An

	move.w	#$0161,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

**

facc_out_b:
	moveq.l	#$1,d0	* one byte
	bsr.w	restore	* restore An

	move.w	#$00a1,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_out_w:
	moveq.l	#$2,d0	* two bytes
	bsr.w	restore	* restore An

	move.w	#$00c1,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_out_l:
	moveq.l	#$4,d0	* four bytes
	bsr.w	restore	* restore An

	move.w	#$0081,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_out_d:
	moveq.l	#$8,d0	* eight bytes
	bsr.w	restore	* restore An

	move.w	#$00e1,EXC_LV+EXC_VOFF(a6)	* set FSLW
	bra.b	facc_finish

facc_out_x:
	move.l	#$c,d0	* twelve bytes
	bsr.w	restore	* restore An

	move.w	#$00e1,EXC_LV+EXC_VOFF(a6)	* set FSLW

* here's where we actually create the access error frame from the
* current exception stack frame.
facc_finish:
	move.l	EXC_LV+USER_FPIAR(a6),EXC_LV+EXC_PC(a6) * store current PC

	fmovem.x	EXC_LV+EXC_FPREGS(a6),fp0-fp1	* restore fp0-fp1
	fmovem.l	EXC_LV+USER_FPCR(a6),fpcr/fpsr/fpiar * restore ctrl regs
	movem.l	EXC_LV+EXC_DREGS(a6),d0-d1/a0-a1	* restore d0-d1/a0-a1

	unlk	a6

	move.l	(sp),-(sp)	* store SR, hi(PC)
	move.l	$8(sp),$4(sp)	* store lo(PC)
	move.l	$c(sp),$8(sp)	* store EA
	move.l	#$00000001,$c(sp)	* store FSLW
	move.w	$6(sp),$c(sp)	* fix FSLW (size)
	move.w	#$4008,$6(sp)	* store voff

	btst	#$5,(sp)	* supervisor or user mode?
	beq.b	facc_out2	* user
	bset	#$2,$d(sp)	* set supervisor TM bit

facc_out2:
	bra.l	_real_access

****

* if the effective addressing mode was predecrement or postincrement,
* the emulation has already changed its value to the correct post-
* instruction value. but since we're exiting to the access error
* handler, then AN must be returned to its pre-instruction value.
* we do that here.
restore:
	move.b	EXC_LV+EXC_OPWORD+$1(a6),d1
	andi.b	#$38,d1	* extract opmode
	ICMP.b	d1,#$18	* postinc?
	beq.w	rest_inc
	ICMP.b	d1,#$20	* predec?
	beq.w	rest_dec
	rts

rest_inc:
	move.b	EXC_LV+EXC_OPWORD+$1(a6),d1
	andi.w	#$0007,d1	* fetch An

	move.w	((tbl_rest_inc).b,pc,d1.w*2),d1
	jmp	((tbl_rest_inc).b,pc,d1.w*1)

tbl_rest_inc:
	dc.w	ri_a0 - tbl_rest_inc
	dc.w	ri_a1 - tbl_rest_inc
	dc.w	ri_a2 - tbl_rest_inc
	dc.w	ri_a3 - tbl_rest_inc
	dc.w	ri_a4 - tbl_rest_inc
	dc.w	ri_a5 - tbl_rest_inc
	dc.w	ri_a6 - tbl_rest_inc
	dc.w	ri_a7 - tbl_rest_inc

ri_a0:
	sub.l	d0,EXC_LV+EXC_DREGS+$8(a6)	* fix stacked a0
	rts
ri_a1:
	sub.l	d0,EXC_LV+EXC_DREGS+$c(a6)	* fix stacked a1
	rts
ri_a2:
	sub.l	d0,a2	* fix a2
	rts
ri_a3:
	sub.l	d0,a3	* fix a3
	rts
ri_a4:
	sub.l	d0,a4	* fix a4
	rts
ri_a5:
	sub.l	d0,a5	* fix a5
	rts
ri_a6:
	sub.l	d0,(a6)	* fix stacked a6
	rts
* if it's a fmove out instruction, we don't have to fix a7
* because we hadn't changed it yet. if it's an opclass two
* instruction (data moved in) and the exception was in supervisor
* mode, then also also wasn't updated. if it was user mode, then
* restore the correct a7 which is in the USP currently.
ri_a7:
	ICMP.b	EXC_LV+EXC_VOFF(a6),#$30	* move in or out?
	bne.b	ri_a7_done	* out

	btst	#$5,EXC_LV+EXC_SR(a6)	* user or supervisor?
	bne.b	ri_a7_done	* supervisor
	movec	usp,a0	* restore USP
	sub.l	d0,a0
	movec	a0,usp	
ri_a7_done:
	rts

* need to invert adjustment value if the <ea> was predec
rest_dec:
	neg.l	d0
	bra.b	rest_inc


**------------------------------------------------------------------------------------------------------
@
