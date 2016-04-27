head	1.1;
access;
symbols
	AMIGAISP_40_3:1.1;
locks; strict;
comment	@;; @;


1.1
date	96.11.26.21.15.01;	author schlote;	state Exp;
branches;
next	;


desc
@MC68060 Software Package for Amiga Computers
Copyright 1996 by Carsten Schlote.
@


1.1
log
@Initial revision
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
** $Id$
**
**
	machine	68060
	near

	include	"mc60_system.i"
	include	"mc60_libbase.i"


**-------------------------------------------------------------------------------
	section          link_libs,code
*>	a5 = LibBase
*>	a6 = SysBase

	XDEF	_Install_Link_Libraries
_Install_Link_Libraries:
	LEA	(_060FPLSP_TOP,PC),A0
	MOVE.L	A0,(mc60_fplsp,A5)
	LEA	(_060ILSP_TOP,PC),A0
	MOVE.L	A0,(mc60_ilsp,A5)
	RTS

**-------------------------------------------------------------------------------
	cnop	0,4
_060FPLSP_TOP:	include          "fpsp_lib.sa"

**-------------------------------------------------------------------------------
	cnop	0,4
_060ILSP_TOP:	include          "isp_lib.sa"

**-------------------------------------------------------------------------------

	end
@
