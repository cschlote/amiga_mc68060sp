head	1.4;
access;
symbols;
locks; strict;
comment	@;; @;


1.4
date	97.04.15.03.03.25;	author schlote;	state Release;
branches;
next	1.3;

1.3
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.04.14.23.00.04;	author schlote;	state Exp;
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


1.4
log
@ResidentEnd Stub.
100% bugfree code :-)
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
** $Id: mc60_tagstub.asm 1.3 1997/04/14 23:06:35 schlote Exp schlote $
**
**
	machine	68060
	near

	section          code,code
	XDEF	RomTagEnd
RomTagEnd:

	end
@


1.3
log
@Working Version 40.2, 40.10ß2
@
text
@d11 1
a11 1
** $Id: mc60_tagstub.asm 1.2 1997/04/14 23:00:04 schlote Exp schlote $
d17 1
a17 6
	include	"mc60_system.i"
	include	"mc60_libbase.i"


	section          patches,code
	
@


1.2
log
@Working version
.
@
text
@d11 1
a11 1
** $Id: mc60_tagstub.asm 1.1 1996/11/26 21:15:01 schlote Exp schlote $
@


1.1
log
@Initial revision
@
text
@d11 1
a11 1
** $Id$
@
