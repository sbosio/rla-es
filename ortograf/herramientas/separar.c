/*
 * separar.c: Convierte un archivo de texto plano en un listado de palabras,
 *            una por línea
 *
 * Para compilar el programa ejecute: "gcc -o separar separar.c"
 *
 * Utilización: "separar < archivo.txt > archivo_separado.txt"
 *
 * Copyleft 2011, Santiago Bosio.
 * Este programa se distribuye bajo licencia GNU GPLv3.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main (int argc, char *argv[])
{
    unsigned char entrada[1000];
    unsigned char palabra[1000];
    size_t cant_letras;
    unsigned char *inicio_palabra;
    unsigned char *fin_palabra;
    unsigned int insertar_salto = 0;

    while ( !feof (stdin) )
    {
	if ( fgets (entrada, sizeof(entrada), stdin) != NULL )
	{
            inicio_palabra = entrada;
            while ( fin_palabra = strpbrk (inicio_palabra, " \t\n()\"?¡!,;.:{}[]=&|$%0123456789<>#/\\+*") )
            {
                cant_letras = (size_t)(fin_palabra - inicio_palabra);
                if ( cant_letras > 0 )
                {
                    memcpy (palabra, inicio_palabra, cant_letras);
                    palabra[cant_letras] = '\0';
                    fputs (palabra, stdout);
                    fputs ("\n", stdout);
                }
                else if ( inicio_palabra == entrada && insertar_salto )
                    fputs ("\n", stdout);
                inicio_palabra = ++fin_palabra;
                fflush (stdout);
            }
            if ( *inicio_palabra != '\0' )
            {
                fputs (inicio_palabra, stdout);
                insertar_salto = 1;
            }
        }
    }

    return (0);
}
