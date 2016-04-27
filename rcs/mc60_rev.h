head	1.8;
access;
symbols;
locks; strict;
comment	@ * @;


1.8
date	97.04.28.20.11.18;	author schlote;	state Exp;
branches;
next	1.7;

1.7
date	97.04.21.20.40.36;	author schlote;	state Exp;
branches;
next	1.6;

1.6
date	97.04.15.02.35.37;	author schlote;	state Exp;
branches;
next	1.5;

1.5
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	97.04.12.13.39.03;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	96.11.26.23.53.06;	author schlote;	state Exp;
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


1.8
log
@Version Bump
@
text
@#define VERSION		40
#define REVISION	14
#define DATE		"28.04.97"
#define VERS		"mc60 40.14"
#define VSTRING		"mc60 40.14 (28.04.97)\r\n"
#define VERSTAG		"\0$VER: mc60 40.14 (28.04.97)\r\n"
#define AUTHOR		"Carsten Schlote"
#define PROJECT		"mc60"
@


1.7
log
@Correkted the ISP / FPSP Outs to VBR Handlers....
@
text
@d2 5
a6 5
#define REVISION	12
#define DATE		"21.04.97"
#define VERS		"mc60 40.12"
#define VSTRING		"mc60 40.12 (21.04.97)\r\n"
#define VERSTAG		"\0$VER: mc60 40.12 (21.04.97)\r\n"
@


1.6
log
@Bumped revision for fixed CreateNestCounts() call at Memory/MMU routines :-(
@
text
@d2 5
a6 5
#define REVISION	11
#define DATE		"15.04.97"
#define VERS		"mc60 40.11"
#define VSTRING		"mc60 40.11 (15.04.97)\r\n"
#define VERSTAG		"\0$VER: mc60 40.11 (15.04.97)\r\n"
@


1.5
log
@Working Version 40.2, 40.10ß2
@
text
@d2 5
a6 5
#define REVISION	10   /*  ß 2 */
#define DATE		"14.04.97"
#define VERS		"mc60 40.10 ß 2"
#define VSTRING		"mc60 40.10 ß 2 (14.04.97)\r\n"
#define VERSTAG		"\0$VER: mc60 40.10 ß 2 (14.04.97)\r\n"
@


1.4
log
@Working version
.
@
text
@d1 6
a6 28
/** $Revision Header *** Header built automatically - do not edit! ***********
 **
 ** © Copyright Silicon Department
 **
 ** File             : mc60_rev.h
 ** Created on       : Mittwoch, 09-Apr-97 
 ** Created by       : Carsten Schlote
 ** Current revision : V 37.04
 **
 ** Purpose
 ** -------
 **   - Empty log message -
 **
 ** Date        Author                 Comment
 ** =========   ====================   ====================
 ** 09-Apr-97    Carsten Schlote        - Empty log message -
 ** 09-Apr-97    Carsten Schlote        - Empty log message -
 ** 09-Apr-97    Carsten Schlote        - Empty log message -
 ** 09-Apr-97    Carsten Schlote        - Empty log message -
 ** 09-Apr-97    Carsten Schlote        --- Initial release ---
 **
 ** $Revision Header *********************************************************/
#define VERSION		37
#define REVISION	4
#define DATE		"09.04.97"
#define VERS		"mc60 37.04"
#define VSTRING		"mc60 37.04 (09.04.97)\r\n"
#define VERSTAG		"\0$VER: mc60 37.04 (09.04.97)\r\n"
@


1.3
log
@Temporärer Check weil ws geht.
@
text
@@


1.2
log
@Set Version for first release V37.1 - runs on 2.04 and up
@
text
@d1 22
d24 5
a28 5
#define REVISION	1
#define DATE		"26.11.96"
#define VERS		"mc60 37.01"
#define VSTRING		"mc60 37.01 (26.11.96)\r\n"
#define VERSTAG		"\0$VER: mc60 37.01 (26.11.96)\r\n"
@


1.1
log
@Initial revision
@
text
@d3 4
a6 4
#define DATE		"04.11.96"
#define VERS		"68060 37.01"
#define VSTRING		"68060 37.01 (04.11.96)\r\n"
#define VERSTAG		"\0$VER: 68060 37.01 (04.11.96)\r\n"
d8 1
a8 1
#define PROJECT		"68060"
@
