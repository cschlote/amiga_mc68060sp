
/*-------------------------------------------------------------------------------
**  /\  |\     Silicon Department      Telefax     06404-64760
**  \_ o| \_ _  Software Entwicklung    Telefon        06404-7996
**    \|| |_)|)   Carsten Schlote         Egelseeweg 52     35423 Lich
** \__/||_/\_|     Branko Mikiç            Limmerstrasse 10   30451 Hannover
**-------------------------------------------------------------------------------
** ALL RIGHTS ON THIS SOURCES RESERVED TO SILICON DEPARTMENT SOFTWARE
**
** $Id: convert.c 1.1 1996/02/24 11:41:56 schlote Exp schlote $
**
*/

#include <stdio.h>
#include <stdlib.h>
#define  USE_BUILTIN_MATH
#include <string.h>
#include <ctype.h>

#include <exec/types.h>

void TranslateBuffer(TEXT *buffer)
{
int i,x;
TEXT *p,c, work[256],work1[256];

	for ( p=buffer,i=0; *p!=0; p++,i++ )
	{
      c = buffer[i];

		if ( c == '\n' ) { *(p++) = '\n'; break ; }

		if ( isspace(c) )
		{
			if      ( i==0 ) *(p++) = '\t';
         else if ( !isspace(*(p-1)) ) *(p++) = c;
			continue;
     	}
      switch( c )
      {
      case '#'	:	*p='*'; break;
      }

	}
   *p = 0;

	if ( sscanf(buffer,"set %s, 0x%x\n",work, &x) == 2 )
		sprintf(buffer,"%s	equ	$%x\n",work,x);

}




void main(int argc, char *argv[])
{
FILE *in, *out;
TEXT buffer[256];

	printf("Intel Motorola 2 Standard Assembly Converter.\n\n");

	printf("Open file '%s'\n",argv[1]);
	if ( in = fopen( argv[1],"r") )
	{
		printf("Open file '%s'\n",argv[2]);
		if ( out = fopen( argv[2],"w") )
		{
      	while ( fgets(buffer,256,in) )
      	{
            TranslateBuffer(buffer);
            if ( fputs( buffer, out) )
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

