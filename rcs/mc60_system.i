head	1.5;
access;
symbols;
locks; strict;
comment	@* @;


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
date	96.11.26.22.11.10;	author schlote;	state Exp;
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


1.5
log
@Working Version 40.2, 40.10ß2
@
text
@
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_system.i 1.4 1997/04/14 23:00:04 schlote Exp schlote $
**
**
**-------------------------------------------------------------------------------

_custom:	EQU	$00DFF000

	incdir	include:
	linedebug


	include 	mc60_rev.i			; Check in revision
	include	mc60_debug.i

                        NOLIST
	include	all_lvo.i                   ; All System LVO offsets

	include	exec/initializers.i		; Needed system includes follow
	include	exec/types.i
	include	exec/lists.i
	include	exec/nodes.i
	include	exec/exec.i
	include	exec/tasks.i

	include	dos/dosextens.i

	include	hardware/custom.i

	include          libraries/configvars.i
	LIST


**-------------------------------------------------------------------------------

_LVOexecPrivate4:	EQU	-$00000036			; For Operation the following privates
_LVOexecPrivate6:	EQU	-$00000042			; are patched.
_LVOexecPrivate8:	EQU	-$000001FE
_LVOexecPrivate9:	EQU	-$00000204

**-------------------------------------------------------------------------------


**-------------------------------------------------------------------------------

@


1.4
log
@Working version
.
@
text
@d10 1
a10 1
** $Id: mc60_system.i 1.3 1997/04/12 13:39:03 schlote Exp schlote $
@


1.3
log
@Temporärer Check weil ws geht.
@
text
@d10 1
a10 1
** $Id: mc60_system.i 1.2 1996/11/26 22:11:10 schlote Exp schlote $
@


1.2
log
@Changed name of REVISION Header
Now set to "mc60_rev.(i|h)"
@
text
@d10 1
a10 1
** $Id: mc60_system.i 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d29 2
d37 2
@


1.1
log
@Initial revision
@
text
@d10 1
a10 1
** $Id$
d21 1
a21 1
	include 	68060_rev.i			; Check in revision
@
