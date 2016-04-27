head	1.5;
access;
symbols;
locks
	schlote:1.5; strict;
comment	@ * @;


1.5
date	97.04.14.23.06.35;	author schlote;	state Exp;
branches;
next	1.4;

1.4
date	97.04.14.23.00.04;	author schlote;	state Exp;
branches;
next	1.3;

1.3
date	97.04.14.22.47.28;	author schlote;	state Exp;
branches;
next	1.2;

1.2
date	97.04.12.13.39.03;	author schlote;	state Exp;
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
#ifndef MYDEBUG_H
#define MYDEBUG_H

/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department         Telefax             06404-64760
**  \_ o| \_ _  Software Entwicklung      Telefon             06404-7996
**    \|| |_)|)   Carsten Schlote         Oberstedter Str 1   35423 Lich
** \__/||_/\_|     Branko Mikiç           Elisenstr 10        30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: mc60_debug.h 1.4 1997/04/14 23:00:04 schlote Exp schlote $
**
*/

/*
 * mydebug.h - #include this file sometime after stdio.h
 * Set MYDEBUG to 1 to turn on debugging, 0 to turn off debugging
 */

#define MYDEBUG  0

//**-----------------------------------------------------------------------------

#if MYDEBUG
/*
 * MYDEBUG User Options
 */

/* Set to 1 to turn second level D2(bug()) statements */
#define DEBUGLEVEL2	0

/* Set to a non-zero # of ticks if a delay is wanted after each debug message */
#define DEBUGDELAY	0

/* Always non-zero for the DDx macros */
#define DDEBUGDELAY	50

/* Set to 1 for serial debugging (link with debug.lib) */
#define KDEBUG          1

/* Set to 1 for parallel debugging (link with ddebug.lib) */
#define DDEBUG		0

#endif /* MYDEBUG */

//**-----------------------------------------------------------------------------
/* Prototypes for Delay, kprintf, dprintf. Or use proto/dos.h or functions.h. */

#include <clib/dos_protos.h>
void kprintf(UBYTE *fmt,...);
void dprintf(UBYTE *fmt,...);

//**-----------------------------------------------------------------------------
/*
 * D(bug()), D2(bug()), DQ((bug()) only generate code if MYDEBUG is non-zero
 *
 * Use D(bug()) for general debugging, D2(bug()) for extra debugging that
 * you usually won't need to see, DD(bug()) for debugging statements that
 * you always want followed by a delay, and DQ(bug()) for debugging that
 * you'll NEVER want a delay after (ie. debugging inside a Forbid, Disable,
 * Task, or Interrupt)
 *
 * Some example uses (all are used the same):
 * D(bug("about to do xyz. variable = $%lx\n",myvariable));
 * D2(bug("v1=$%lx v2=$%lx v3=$%lx\n",v1,v2,v3));
 * DQ(bug("in subtask: variable = $%lx\n",myvariable));
 * DD(bug("About to do xxx\n"));
 *
 * Set MYDEBUG above to 1 when debugging is desired and recompile the modules
 *  you wish to debug.  Set to 0 and recompile to turn off debugging.
 *
 * User options set above:
 * Set DEBUGDELAY to a non-zero # of ticks (ex. 50) when a delay is desired.
 * Set DEBUGLEVEL2 nonzero to turn on second level (D2) debugging statements
 * Set KDEBUG to 1 and link with debug.lib for serial debugging.
 * Set DDEBUG to 1 and link with ddebug.lib for parallel debugging.
 */

/*
 * Debugging function automaticaly set to printf, kprintf, or dprintf
 */

#if KDEBUG
#define bug kprintf
#elif DDEBUG
#define bug dprintf
#else	/* else changes all bug's to printf's */
#define bug printf
#endif

/*
 * Debugging macros
 */

/* D(bug( 	delays DEBUGDELAY if DEBUGDELAY is > 0
 * DD(bug(	always delays DDEBUGDELAY
 * DQ(bug(      (debug quick) never uses Delay.  Use in forbids,disables,ints
 * The similar macros with "2" in their names are second level debugging
 */

#if MYDEBUG    /* Turn on first level debugging */
#define D(x)  (x); if(DEBUGDELAY>0) Delay(DEBUGDELAY)
#define DD(x) (x); Delay(DDEBUGDELAY)
#define DQ(x) (x)
#else  /* First level debugging turned off */
#define D(x) ;
#define DD(x) ;
#define DQ(x) ;
#endif

#if DEBUGLEVEL2 /* Turn on second level debugging */
#define D2(x)  (x); if(DEBUGDELAY>0) Delay(DEBUGDELAY)
#define DD2(x) (x); Delay(DDEBUGDELAY)
#define DQ2(x) (x)
#else  /* Second level debugging turned off */
#define D2(x) ;
#define DD2(x) ;
#define DQ2(x) ;
#endif /* DEBUGLEVEL2 */

#endif /* MYDEBUG_H */

@


1.4
log
@Working version
.
@
text
@d13 1
a13 1
** $Id: mc60_debug.h 1.3 1997/04/14 22:47:28 schlote Exp schlote $
@


1.3
log
@Working version
@
text
@d13 1
a13 1
** $Id: mc60_debug.h 1.2 1997/04/12 13:39:03 schlote Exp schlote $
@


1.2
log
@Temporärer Check weil ws geht.
@
text
@d13 1
a13 1
** $Id: mc60_debug.h 1.1 1996/11/26 21:15:01 schlote Exp schlote $
d22 1
a22 1
#define MYDEBUG  1
@


1.1
log
@Initial revision
@
text
@d2 3
d13 1
a13 1
** $Id$
a16 1

a20 2
#ifndef MYDEBUG_H
#define MYDEBUG_H
d24 2
d32 1
a32 1
#define DEBUGLEVEL2	1
d48 1
a48 1

d55 1
a80 1

d102 1
d107 6
a121 7
#else  /* First level debugging turned off */
#define D(x) ;
#define DQ(x) ;
#define D2(x) ;
#define DD(x) ;
#endif

@
