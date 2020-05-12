/*
 * convertir.c: Convierte un listado de palabras en texto plano al formato
 *              personal .dic versión 6 (binario) de LibreOffice
 *
 * Para compilar el programa ejecute: "gcc -o convertir convertir.c"
 *
 * Utilización: "convertir < listado.txt > fichero.dic"
 *
 * Copyleft 2008, Santiago Bosio.
 * Este programa se distribuye bajo licencia GNU GPLv3.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main (int argc, char *argv[])
{
    unsigned char encabezado[11] = {'\x06', '\x00', '\x57', '\x42', '\x53',
                                    '\x57', '\x47', '\x36', '\xff', '\x00',
                                    '\x00'};
    int largo = 0;
    unsigned char palabra[100];

    /* Colocar el encabezado de once bytes para cualquier lenguaje */
    if ( fwrite (encabezado, sizeof(unsigned char), 11, stdout) < 11 )
    {
	fprintf (stderr, "Error: No se pudo escribir en la salida estándar.\n");
	exit (1);
    }

    while ( !feof (stdin) )
    {
	if ( fgets (palabra, sizeof(palabra), stdin) != NULL )
	{
	    largo = strlen (palabra) - 1;
	    if ( fwrite (&largo, 2, 1, stdout) < 1 )
	    {
		fprintf (stderr, "Error: No se pudo escribir en la salida estándar.\n");
		exit (1);
	    }
	    if ( fwrite (palabra, sizeof(unsigned char), (size_t) largo, stdout) < largo )
	    {
		fprintf (stderr, "Error: No se pudo escribir en la salida estándar.\n");
		exit (1);
	    }
	}
    }

    return (0);
}
