/*
 * extraer.c: Extrae el listado de palabras de un diccionario
 *            personal .dic de Apache OpenOffice
 *
 * Para compilar el programa ejecute: "gcc -o extraer extraer.c"
 *
 * Utilización: "extraer < archivo.dic > listado.txt"
 *
 * Copyleft 2005-2010, Santiago Bosio.
 * Este programa se distribuye bajo licencia GNU GPL.
 *
 */

#include <stdio.h>
#include <stdlib.h>

int main (int argc, char *argv[])
{
    int largo = 0;
    int version = 6;
    unsigned char palabra[100];

    /* Verificar la versión del diccionario (6 o 7) */
    if ( fread (palabra, sizeof(unsigned char), 11, stdin) < 11 )
    {
	fprintf (stderr, "Error: No es un diccionario válido.\n");
	exit (1);
    }
    if ( !strncmp(palabra, "OOoUserDict", 11) )
        version = 7;

    if ( version == 6 )
    {
        /* Versión 6 (archivo binario) */
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
    }
    else
    {
        /* Versión 7 (texto etiquetado) */
        /* Descartamos las 4 primeras líneas del archivo (encabezado) */
        fgets (palabra, 100, stdin);
        fgets (palabra, 100, stdin);
        fgets (palabra, 100, stdin);
        fgets (palabra, 100, stdin);

        /* Copiar el resto del archivo a la salida */
        while ( !feof (stdin) )
        {
            fgets (palabra, 100, stdin);
            fputs (palabra, stdout);
        }
    }

    return (0);
}
