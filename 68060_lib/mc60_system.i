
**-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_system.i 1.5 1997/04/14 23:06:35 schlote Exp schlote $
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

