
/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: convert.c 1.0 1996/02/24 11:19:50 schlote Exp schlote $
**
*/

#include <stdio.h>
#include <stdlib.h>
#define  USE_BUILTIN_MATH
#include <string.h>

#include <exec/types.h>

void TranslateBuffer(TEXT *buffer)
{
int i,x;
TEXT *p,work[256];

	for ( p=buffer; *p!=0; p++ )
	{
      switch( *p )
      {
      case '#'	:	*p='*'; break;
      }
	}

	if ( sscanf(buffer," short 0x%x %s\n",&x, work) == 2 )
		sprintf(buffer,"  	dc.w	$%x		%s\n",x,work);
}



void main(int argc, char *argv[])
{
FILE *in, *out;
TEXT buffer[256];

	printf("Intel Motorola 2 Standard Assembly Converter.\n\n");

	printf("Open file '%s'\n",argv[1]);
	if ( in = fopen( argv[1],"r") )
	{
		printf("Open file '%s'\n",argv[1]);
		if ( out = fopen( argv[2],"w") )
		{
      	while ( fgets(buffer,256,in) )
      	{
            TranslateBuffer(buffer);
            if ( !fputs( buffer, out) )
            {
            	printf("*** error on file write\n");
            	break;
            }
      	}

			fclose(out);
		}
		fclose(in);
	}
}

