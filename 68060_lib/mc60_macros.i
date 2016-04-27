
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_macros.i 1.4 1997/04/14 23:06:35 schlote Exp schlote $
**
**

**-------------------------------------------------------------------------------

** Call into emu module : <modul>,<vector>,<Debug text>

CALL_IN:	MACRO

	IFGE	MYDEBUG-20				; Get Debug Output on Call In
	MOVEM.L	A0-a1,-(SP)
	MOVEA.L	(8,SP),A0				; Get Stackframe
	MOVEA.L	(8+4,SP),A1
	DBUG        20,\3,a0,a1
	MOVEM.L	(SP)+,A0-a1
	ENDC

	BRA.L	\1+(\2*8)
	ENDM

**-------------------------------------------------------------------------------

**  <call in stub for module>,<cpu exception vector in VBR A2>

SETVECTOR:	MACRO       ; vector
	LEA	(Vector_\2,PC),A1			; get old vector
	MOVE.L	(\2*4,A2),(A1)                      ; and store for further use.

	LEA	(\1,PC),A1                          ; Get Addr of call in
	MOVE.L	A1,(\2*4,A2)			; set vbr vector
	MOVE.L	A1,(\2*4).W                         ; set to 'base' vbr
	ENDM

