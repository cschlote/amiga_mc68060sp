head	1.9;
access;
symbols;
locks; strict;
comment	@* @;


1.9
date	97.04.28.20.11.18;	author schlote;	state Exp;
branches;
next	1.8;

1.8
date	97.04.21.20.40.36;	author schlote;	state Exp;
branches;
next	1.7;

1.7
date	97.04.15.02.35.37;	author schlote;	state Exp;
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
date	96.11.26.23.52.24;	author schlote;	state Exp;
branches;
next	1.1;

1.1
date	96.11.26.22.11.10;	author schlote;	state Exp;
branches;
next	;


desc
@MC68060 Software Package for Amiga Computers
Copyright 1996 by Carsten Schlote.
@


1.9
log
@Version Bump
@
text
@VERSION  EQU	40
REVISION EQU	14
DATE     MACRO
		dc.b	'28.04.97'
    ENDM
VERS     MACRO
		dc.b	'mc60 40.14'
    ENDM
VSTRING  MACRO
		dc.b	'mc60 40.14 (28.04.97)',13,10,0
    ENDM
VERSTAG  MACRO
		dc.b	0,'$VER: mc60 40.14 (28.04.97)',0
    ENDM
AUTHOR   MACRO
		dc.b	'Carsten Schlote'
    ENDM
PROJECT  MACRO
		dc.b	'mc60'
    ENDM
@


1.8
log
@Correkted the ISP / FPSP Outs to VBR Handlers....
@
text
@d2 1
a2 1
REVISION EQU	12
d4 1
a4 1
		dc.b	'21.04.97'
d7 1
a7 1
		dc.b	'mc60 40.12'
d10 1
a10 1
		dc.b	'mc60 40.12 (21.04.97)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: mc60 40.12 (21.04.97)',0
@


1.7
log
@Bumped revision for fixed CreateNestCounts() call at Memory/MMU routines :-(
@
text
@d2 1
a2 1
REVISION EQU	11
d4 1
a4 1
		dc.b	'15.04.97'
d7 1
a7 1
		dc.b	'mc60 40.11'
d10 1
a10 1
		dc.b	'mc60 40.11 (15.04.97)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: mc60 40.11 (15.04.97)',0
@


1.6
log
@Working Version 40.2, 40.10ß2
@
text
@d2 1
a2 1
REVISION EQU	10   ;*  ß 2 
d4 1
a4 1
		dc.b	'14.04.97'
d7 1
a7 1
		dc.b	'mc60 40.10 ß 2'
d10 1
a10 1
		dc.b	'mc60 40.10 ß 2 (14.04.97)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: mc60 40.10 ß 2 (14.04.97)',0
@


1.5
log
@Working version
.
@
text
@a0 22
;** $Revision Header *** Header built automatically - do not edit! ***********
;**
;** © Copyright Silicon Department
;**
;** File             : mc60_rev.i
;** Created on       : Mittwoch, 09-Apr-97
;** Created by       : Carsten Schlote
;** Current revision : V 40.04
;**
;** Purpose
;** -------
;**   - Empty log message -
;**
;** Date        Author                 Comment
;** =========   ====================   ====================
;** 09-Apr-97    Carsten Schlote        - Empty log message -
;** 09-Apr-97    Carsten Schlote        - Empty log message -
;** 09-Apr-97    Carsten Schlote        - Empty log message -
;** 09-Apr-97    Carsten Schlote        - Empty log message -
;** 09-Apr-97    Carsten Schlote        --- Initial release ---
;**
;** $Revision Header ********************************************************
d2 1
a2 1
REVISION EQU	4
d4 1
a4 1
		dc.b	'09.04.97'
d7 1
a7 1
		dc.b	'mc60 40.04'
d10 1
a10 1
		dc.b	'mc60 40.04 (09.04.97)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: mc60 40.04 (09.04.97)',0
@


1.4
log
@Working version
@
text
@@


1.3
log
@Temporärer Check weil ws geht.
@
text
@d6 1
a6 1
;** Created on       : Mittwoch, 09-Apr-97 
d8 1
a8 1
;** Current revision : V 37.04
d23 1
a23 1
VERSION  EQU	37
d29 1
a29 1
		dc.b	'mc60 37.04'
d32 1
a32 1
		dc.b	'mc60 37.04 (09.04.97)',13,10,0
d35 1
a35 1
		dc.b	0,'$VER: mc60 37.04 (09.04.97)',0
@


1.2
log
@Reviewed & commented lib startup. Fixed minor bugs
@
text
@d1 22
d24 1
a24 1
REVISION EQU	1
d26 1
a26 1
		dc.b	'26.11.96'
d29 1
a29 1
		dc.b	'mc60 37.01'
d32 1
a32 1
		dc.b	'mc60 37.01 (26.11.96)',13,10,0
d35 1
a35 1
		dc.b	0,'$VER: mc60 37.01 (26.11.96)',0
@


1.1
log
@Initial revision
@
text
@d4 1
a4 1
		dc.b	'04.11.96'
d7 1
a7 1
		dc.b	'68060 37.01'
d10 1
a10 1
		dc.b	'68060 37.01 (04.11.96)',13,10,0
d13 1
a13 1
		dc.b	0,'$VER: 68060 37.01 (04.11.96)',0
d19 1
a19 1
		dc.b	'68060'
@
