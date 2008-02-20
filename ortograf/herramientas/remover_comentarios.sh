#!/bin/bash
#
# remover_comentarios.sh: Script para eliminar comentarios y espacios
# innecesarios en el fichero de afijos.
#
# (c) 2005, Santiago Bosio
# Este script se distribuye bajo licencia GNU GPL.

sed -n '/^\#.*/ { d; }; /^[^\#]*\#.*/! { p; };
        /^[^\#]*\#.*/ { s/\ [\ ]*\#.*//; p; }' | \
sed -n '/  /! { p; }; /  \( \)*/ { s// /g; p; }'
