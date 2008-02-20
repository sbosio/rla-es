#!/bin/bash
#
# make_dict.sh: Script para la creación del paquete de diccionario.
#
# (c) 2005, Santiago Bosio
# Este programa se distribuye bajo licencia GNU GPL.

# Herramientas básicas para el script
MKTEMP=`which mktemp 2>/dev/null`
GREP=`which grep 2>/dev/null`
FIND=`which find 2>/dev/null`
ZIP=`which zip 2>/dev/null`
MUNCH=`which munch 2>/dev/null`
UNMUNCH=`which unmunch 2>/dev/null`

# Abandonar si no se encuentra alguna de las herramientas
if [ "$MKTEMP" == "" ]; then
  echo "No se encontró el comando 'mktemp'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$GREP" == "" ]; then
  echo "No se encontró el comando 'grep'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$FIND" == "" ]; then
  echo "No se encontró el comando 'find'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$ZIP" == "" ]; then
  echo "No se encontró el comando 'zip'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$MUNCH" == "" ]; then
  if [ -x ../../MySpell-3.0/munch ]; then
    MUNCH='../../MySpell-3.0/munch'
  else
    echo "No se encontró el comando 'munch'... Abortando." > /dev/stderr
    exit 1
  fi
fi
if [ "$UNMUNCH" == "" ]; then
  if [ -x ../../MySpell-3.0/unmunch ]; then
    UNMUNCH='../../MySpell-3.0/unmunch'
  else
    echo "No se encontró el comando 'unmunch'... Abortando." > /dev/stderr
    exit 1
  fi
fi

# Realizar el análisis de los parámetros de la línea de comandos
previa=
for opcion
do
  # Si la opción previa requiere un argumento, asignarlo.
  if test -n "$previa"; then
    eval "$previa=\$opcion"
    previa=
    continue
  fi

  argumento=`expr "z$opcion" : 'z[^=]*=\(.*\)'`

  case $opcion in

    --localizacion | --localización | --locale | -l)
      previa="LOCALIZACION" ;;
    --localizacion=* | --localización=* | --locale=* | -l=*)
      LOCALIZACION=$argumento ;;

    --rae | -r)
      RAE="SÍ" ;;

    --ayuda | --help | -h)
      echo
      echo "Sintaxis del comando: $0 [opciones]."
      echo "Las opciones pueden ser las siguientes:"
      echo
      echo "--localizacion=LOC | -l LOC"
      echo "    Localización a utilizar en la generación del diccionario."
      echo "    El argumento LOC debe ser un código ISO de localización"
      echo "    implementado (es_AR, es_ES, es_MX, etc.)"
      echo
      echo "--rae | -r"
      echo "    Incluir únicamente las palabras pertenecientes al"
      echo "    diccionario de la Real Academia Española."
      echo
      exit 0 ;;

    *)
      echo
      echo "Opción no reconocida: '$opcion'." > /dev/stderr
      echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
      echo
      exit 1 ;;
  esac
done

# Hacemos una copia del valor de la variable LANG para poder restaurarla.
LANG_BAK=$LANG

# Verificar si se pasó una localización como parámetro.
if [ "$LOCALIZACION" != "" ]; then
  # Verificar que la localización solicitada esté implementada.
  if [ -d "../palabras/RAE/l10n/$LOCALIZACION" -o \
       -d "../palabras/noRAE/l10n/$LOCALIZACION" ]; then
    # Cambiamos la localización y codificación de caracteres.
    LANG="$LOCALIZACION.ISO-8859-1"
    echo "Creando un diccionario para la localización '$LOCALIZACION'..."
  else
    echo "No se ha implementado la localización '$LOCALIZACION'." \
         > /dev/stderr
    echo -ne "¿Desea crear el diccionario genérico? (S/n): " \
         > /dev/stderr
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" -o "$RESPUESTA" == "N" ]; then
      echo -e "No.\nProceso abortado.\n" > /dev/stderr
      exit 2
    else
      echo "Sí" > /dev/stderr
      LANG="es_ES.ISO-8859-1"
      LOCALIZACION="es_ANY"
    fi
  fi
else
  # Si no se pasó el parámetro de localización, asumimos que se desea
  # generar el diccionario genérico.
  echo "No se definió una localización; creando el diccionario genérico..."
  LANG="es_ES.ISO-8859-1"
  LOCALIZACION="es_ANY"
fi

# Crear un directorio temporal de trabajo
MDTMPDIR="`$MKTEMP -d /tmp/makedict.XXXXXXXXXX`"

# Para el fichero de afijos encadenamos los distintos segmentos (encabezado,
# prefijos y sufijos) de la localización seleccionada, removiendo los
# comentarios y espacios innecesarios.
AFFIXTMP="$MDTMPDIR/$LOCALIZACION.aff.tmp"
AFFIX="$MDTMPDIR/$LOCALIZACION.aff"
echo -n "Creando el fichero de afijos... "

if [ ! -d ../afijos/l10n/$LOCALIZACION ]; then
  # Si se solicitó un diccionario genérico, o la localización no ha
  # definido sus propias reglas para los afijos, utilizamos la versión
  # genérica de los ficheros.
  ./remover_comentarios.sh < ../afijos/afijos.txt > $AFFIX
else
  # Copiar la versión genérica del fichero de afijos y parcharlo con las
  # diferencias de la localización solicitada.
  cp ../afijos/afijos.txt $AFFIXTMP
  patch $AFFIXTMP \
        ../afijos/l10n/$LOCALIZACION/afijos_$LOCALIZACION-diffs.patch \
        > /dev/null 2>&1
  ./remover_comentarios.sh < $AFFIXTMP > $AFFIX
fi
echo "¡listo!"

# La lista de palabras se conforma con los distintos grupos de palabras
# comunes a todos los idiomas, más los de la localización solicitada.
# Si se crea el diccionario genérico, se incluyen todas las localizaciones.
TMPWLIST="$MDTMPDIR/wordlist.tmp"
WLIST="$MDTMPDIR/wordlist.txt"
echo -n "Creando la lista de lemas etiquetados... "

# Palabras comunes a todos los idiomas, definidas por la RAE.
cat ../palabras/RAE/*.txt | \
    ./remover_comentarios.sh \
     > $TMPWLIST

if [ -d "../palabras/RAE/l10n/$LOCALIZACION" ]; then
  # Incluir las palabras de la localización solicitada, definidas por la RAE.
  cat ../palabras/RAE/l10n/$LOCALIZACION/*.txt | \
      ./remover_comentarios.sh \
      >> $TMPWLIST
else
  # Diccionario genérico; incluir todas las localizaciones.
  cat `$FIND ../palabras/RAE/l10n/ \
             -iname *.txt -and ! -regex '.*/\.svn.*'` |
      ./remover_comentarios.sh \
      >> $TMPWLIST
fi

if [ "$RAE" != "SÍ" ]; then
  # Incluir palabras comunes, no definidas por la RAE
  cat ../palabras/noRAE/*.txt | \
      ./remover_comentarios.sh \
      >> $TMPWLIST

  if [ -d "../palabras/noRAE/l10n/$LOCALIZACION" ]; then
    # Incluir las palabras de la localización solicitada.
    cat ../palabras/noRAE/l10n/$LOCALIZACION/*.txt | \
        ./remover_comentarios.sh \
        >> $TMPWLIST
  else
    # Diccionario genérico; incluir todas las localizaciones.
    cat `$FIND ../palabras/noRAE/l10n/ \
               -iname *.txt -and ! -regex '.*/\.svn.*'` | \
        ./remover_comentarios.sh \
        >> $TMPWLIST
  fi
fi

# Generar el fichero con la lista de palabras (únicas), indicando en la
# primera línea el número de palabras que contiene.
sort -u < $TMPWLIST | wc -l | cut -d ' ' -f1 > $WLIST
sort -u < $TMPWLIST >> $WLIST

echo "¡listo!"

# Descomprimimos la lista etiquetada para obtener un conjunto de palabras
# únicas, de a una por línea, para alimentar al comando 'munch'.
echo -n "Descomprimiendo la lista con 'unmunch'... "
nice -n +19 \
     $UNMUNCH $WLIST $AFFIX 2>/dev/null | \
     sort -u | \
     grep -v ^[0-9] \
     > $TMPWLIST
wc -l $TMPWLIST | \
   cut -d ' ' -f1 \
   > $WLIST
cat $TMPWLIST >> $WLIST
rm -f $TMPWLIST

echo "¡listo!"

# Pasar la lista obtenida a través de 'munch' para obtener el fichero
# .dic final.
DICFILE="$MDTMPDIR/$LOCALIZACION.dic"
echo -n "Recomprimiendo la lista con 'munch' (esto puede demorar horas)... "
nice -n +19 \
    $MUNCH $WLIST $AFFIX 2>/dev/null | \
    sort -u \
    > $DICFILE
rm -f $WLIST
echo "¡listo!"
    
echo -n "Creando paquete comprimido... "
ZIPFILE="$MDTMPDIR/$LOCALIZACION.zip"
$ZIP -j -q $ZIPFILE $DICFILE $AFFIX \
    ../docs/README_$LOCALIZACION.txt \
    ../docs/Changelog_$LOCALIZACION.txt
echo "¡listo!"

# Mover el paquete a esta carpeta y eliminar la carpeta temporal
mv -f $ZIPFILE .
rm -Rf $MDTMPDIR

echo "¡Proceso finalizado!"

# Restauramos la variable de entorno LANG
LANG=$LANG_BAK
