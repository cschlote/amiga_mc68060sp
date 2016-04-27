head	1.3;
access;
symbols;
locks; strict;
comment	@* @;


1.3
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.1;

1.1
date	97.04.12.13.39.03;	author schlote;	state Exp;
branches;
next	;


desc
@Version Tag
@


1.3
log
@Working Version 40.2, 40.10ß2
@
text
@VERSION  EQU	40
REVISION EQU	2
DATE     MACRO
		dc.b	'14.04.97'
    ENDM
VERS     MACRO
		dc.b	'mc40 40.02'
    ENDM
VSTRING  MACRO
		dc.b	'mc40 40.02 (14.04.97)',13,10,0
    ENDM
VERSTAG  MACRO
		dc.b	0,'$VER: mc40 40.02 (14.04.97)',0
    ENDM
AUTHOR   MACRO
		dc.b	'Carsten Schlote'
    ENDM
PROJECT  MACRO
		dc.b	'mc40'
    ENDM
@


1.2
log
@Working version
.
@
text
@d4 1
a4 1
		dc.b	'09.04.97'
d10 1
a10 1
		dc.b	'mc40 40.02 (09.04.97)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: mc40 40.02 (09.04.97)',0
@


1.1
log
@Initial revision
@
text
@@
