VERSION  EQU	43
REVISION EQU	2   ;*  ß 1 
DATE     MACRO
		dc.b	'02.04.97'
    ENDM
VERS     MACRO
		dc.b	'Isp 43.02 ß 1'
    ENDM
VSTRING  MACRO
		dc.b	'Isp 43.02 ß 1 (02.04.97)',13,10,0
    ENDM
VERSTAG  MACRO
		dc.b	0,'$VER: Isp 43.02 ß 1 (02.04.97)',0
    ENDM
AUTHOR   MACRO
		dc.b	'Carsten Schlote'
    ENDM
PROJECT  MACRO
		dc.b	'Isp'
    ENDM
