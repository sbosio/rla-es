#!/bin/sh

# Generación automática del diccionario español aspell6


# generamos el diccionario, por ahora sólo el de español «internacional»
pushd ../herramientas/
 ./make_dict.sh -2
popd

# extraemos los contenidos del diccionario para integrarlo en aspell
TMPFILE=`mktemp -d /tmp/rla.XXXXXXXXX` || exit 1                     
unzip  ../herramientas/es_ANY.zip -d $TMPFILE

mv $TMPFILE/es_ANY.dic es.wl
mv $TMPFILE/es_ANY.aff es_affix.dat
  
# generamos scripts aspell a partir de proc (proc forma parte de la distribucion de aspell-lang)
perl proc create
./configure

# Generamos el diccionario aspell:
 
make dist
