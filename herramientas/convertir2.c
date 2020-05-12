/*
 * convertir2.c: Convierte un listado de palabras en texto plano al formato
 *               personal .dic versión 7 (texto etiquetado) de LibreOffice
 *
 * Para compilar el programa ejecute: "gcc -o convertir2 convertir2.c"
 *
 * Utilización: "convertir2 < listado.txt > archivo.dic"
 *
 * Copyleft 2010, Santiago Bosio.
 * Este programa se distribuye bajo licencia GNU GPLv3.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main (int argc, char *argv[])
{
    int largo = 0;
    unsigned char palabra[100];

    /* Colocar el encabezado para cualquier lenguaje */
    fprintf (stdout, "OOoUserDict1\n");
    fprintf (stdout, "lang: <none>\n");
    fprintf (stdout, "type: positive\n");
    fprintf (stdout, "---\n");

    while ( !feof (stdin) )
    {
	if ( fgets (palabra, sizeof(palabra), stdin) != NULL )
	{
	    largo = strlen (palabra) - 1;
	    if ( fwrite (palabra, sizeof(unsigned char), (size_t) largo, stdout) < largo )
	    {
		fprintf (stderr, "Error: No se pudo escribir en la salida estándar.\n");
		exit (1);
	    }
	    fprintf (stdout, "\n");
	}
    }

    return (0);
}
