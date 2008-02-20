/*
 * extraer.c: Extrae el listado de palabras de un diccionario
 *            personal .dic de OpenOffice.org.
 *
 * Para compilar el programa ejecute: "gcc -o extraer extraer.c"
 *
 * Utilización: "extraer < fichero.dic > listado.txt"
 *
 * (c) 2005, Santiago Bosio.
 * Este programa se distribuye bajo licencia GNU GPL.
 *
 */

#include <stdio.h>
#include <stdlib.h>

int main (int argc, char *argv[])
{
    int largo = 0;
    unsigned char palabra[100];

    /* Ignorar los primeros once bytes: encabezado */
    if ( fread (palabra, sizeof(unsigned char), 11, stdin) < 11 )
    {
	fprintf (stderr, "Error: No es un diccionario válido.\n");
	exit (1);
    }

    if ( fread (&largo, 2, 1, stdin) <= 0 )
    {
	fprintf (stderr, "El diccionario no contiene palabras.\n");
	exit (1);
    }

    while ( !feof (stdin) )
    {
	if ( largo > 100 ) /* Saltear las palabras largas (errores) */
	{
	    fprintf (stderr, "Error: palabra demasiado larga.\n");
	    fseek (stdin, (long) largo, SEEK_CUR);
	}
	else
	{
	    fread (palabra, sizeof(unsigned char), (size_t) largo, stdin);
	    fwrite (palabra, sizeof(unsigned char), (size_t) largo, stdout);
	    fprintf (stdout, "\n");
	}
	fread (&largo, 2, 1, stdin);
    }

    return (0);
}
