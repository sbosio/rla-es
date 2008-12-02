#!/bin/bash
#
# remover_comentarios.sh: Script para eliminar comentarios y espacios
# innecesarios en el fichero de afijos.
#
# Copyleft 2005-2008, Santiago Bosio
# Este script se distribuye bajo licencia GNU GPL.

sed -n '/^\#.*/ { d; }; /^$/ { d; }; /^[^\#]*\#.*/! { p; };
        /^[^\#]*\ [\ ]*\#.*/ { s/\ [\ ]*\#.*//; p; };
        /^[^\#]*\t[\t]*\#.*/ { s/\t[\t]*\#.*//; p; }' | \
sed -n '/  /! { p; }; /  \( \)*/ { s// /g; p; }'
