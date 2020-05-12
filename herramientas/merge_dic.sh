#!/bin/bash
#
# merge_dic.sh: Script para mezclar varios diccionarios personales
#               .dic de LibreOffice en un único diccionario.
#
# Copyleft 2010, Santiago Bosio
# Este programa se distribuye bajo licencia GNU GPL.

# Compilar las herramientas requeridas si es necesario
if [ ! -x ./extraer ]; then
    gcc -o extraer extraer.c
fi
if [ ! -x ./convertir ]; then
    gcc -o convertir convertir.c
fi
if [ ! -x ./convertir2 ]; then
    gcc -o convertir2 convertir2.c
fi

# Por defecto hacemos un diccionario versión 7
VERSION="7"

# Realizar el análisis de los parámetros de la línea de comandos
previa=
for opcion; do
  # Si la opción previa requiere un argumento, asignarlo.
  if test -n "$previa"; then
    eval "$previa=\$opcion"
    previa=
    continue
  fi

  argumento=`expr "z$opcion" : 'z[^=]*=\(.*\)'`

  case $opcion in

    --salida | --output | -o | -s )
      previa="SALIDA" ;;
    --salida=* | --output=* | -o=* | -s=* )
      SALIDA=$argumento ;;

    -6)
      VERSION="6" ;;

    --ayuda | --help | -h)
      echo
      echo "Sintaxis del comando: $0 [opciones] archivo1.dic archivo2.dic ... archivoN.dic"
      echo "Las opciones pueden ser las siguientes:"
      echo
      echo "--salida=ARCHIVO.dic | -s ARCHIVO.dic"
      echo "    Archivo en el cual se escribirá el diccionario único que"
      echo "    recoge las palabras contenidas en todos los diccionarios"
      echo "    pasados como parámetros"
      echo
      echo "-6"
      echo "    Crear un diccionario personalizada en el formato de"
      echo "    versión 6 (archivo binario)."
      echo "    De forma predeterminada se genera un diccionario"
      echo "    en el formato de versión 7 (texto etiquetado)."
      echo
      exit 0 ;;

    *)
      if [ -r $opcion ]; then
        ARCHIVOS="$ARCHIVOS $opcion"
      else
        echo
        echo "Opción no reconocida, o no se puede leer del siguiente archivo: '$opcion'." > /dev/stderr
        echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
        echo
        exit 1
      fi ;;
  esac
done

if [ "$ARCHIVOS" == "" ]; then
    echo "No se especificó ningún archivo de entrada." > /dev/stderr
    echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
    exit 1
fi

# Hacemos una copia del valor de la variable LANG para poder restaurarla.
LANG_BAK=$LANG

# Establecer la variable LANG a "C" para el ordenamiento
LANG=C

# Crear un directorio temporal de trabajo
MDTMPDIR="`mktemp -d /tmp/merge_dic.XXXXXXXXXX`"

# La lista de palabras se conforma extrayendo el contenido de los distintos
# archivos .dic pasados como parámetros en la línea de comandos.
TMPWLIST="$MDTMPDIR/wordlist.tmp"
WLIST="$MDTMPDIR/wordlist.txt"

# Palabras comunes a todos los idiomas, definidas por la RAE.
for archivo in $ARCHIVOS; do
     ./extraer < $archivo >> $TMPWLIST
done

# Generar el fichero con la lista de palabras (únicas)
sort -u < $TMPWLIST > $WLIST

# Restauramos la variable de entorno LANG
LANG=$LANG_BAK

DIRECTORIO_TRABAJO="`pwd`"

if [ "$VERSION" != "7" ]; then
  CONVERTIR="./convertir"
else
  CONVERTIR="./convertir2"
fi

if [ "$SALIDA" != "" ]; then
  $CONVERTIR < $WLIST > $SALIDA
else
  $CONVERTIR < $WLIST
fi

# Eliminar la carpeta temporal
rm -Rf $MDTMPDIR
