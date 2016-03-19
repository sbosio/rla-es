#!/bin/bash
#
# make_dict.sh: Script para la creación del paquete de diccionario.
#
# Copyleft 2005-2015, Santiago Bosio
# Este programa se distribuye bajo licencia GNU GPL.

# Herramientas básicas para el script
MKTEMP=`which mktemp 2>/dev/null`
GREP=`which grep 2>/dev/null`
FIND=`which find 2>/dev/null`
ZIP=`which zip 2>/dev/null`

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

# Por defecto hacemos un paquete de extensión para OOo 3.x o superior
VERSION="3"
COMPLETO="NO"

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

    -2)
      VERSION="2" ;;

    --completo | -c)
      COMPLETO="SÍ" ;;

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
      echo "-2"
      echo "    Crear un paquete ZIP de instalación manual para las"
      echo "    versiones 1.x ó 2.x de OpenOffice.org."
      echo "    Por defecto se crea una extensión (.oxt) para"
      echo "    OpenOffice.org/LibreOffice versión 3.x o superior."
      echo
      echo "--completo | -c"
      echo "    Integrar los diccionarios de sinónimos y de separación"
      echo "    silábica dentro del mismo paquete (sólo para versiones 3.x"
      echo "    o posteriores)."
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
    LANG="$LOCALIZACION.UTF-8"
    echo "Creando un diccionario para la localización '$LOCALIZACION'..."
  else
    echo "No se ha implementado la localización '$LOCALIZACION'." > /dev/stderr
    echo -ne "¿Desea crear el diccionario genérico? (S/n): " > /dev/stderr
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" -o "$RESPUESTA" == "N" ]; then
      echo -e "No.\nProceso abortado.\n" > /dev/stderr
      exit 2
    else
      echo "Sí" > /dev/stderr
      LANG="es_ES.UTF-8"
      LOCALIZACION="es_ANY"
    fi
  fi
else
  # Si no se pasó el parámetro de localización, asumimos que se desea
  # generar el diccionario genérico.
  echo "No se definió una localización; creando el diccionario genérico..."
  LANG="es_ES.UTF-8"
  LOCALIZACION="es_ANY"
fi

# Crear un directorio temporal de trabajo
MDTMPDIR="`$MKTEMP -d /tmp/makedict.XXXXXXXXXX`"

# Para el fichero de afijos encadenamos los distintos segmentos (encabezado,
# prefijos y sufijos) de la localización seleccionada, eliminando los
# comentarios y espacios innecesarios.
AFFIX="$MDTMPDIR/$LOCALIZACION.aff"
echo -n "Creando el fichero de afijos... "

if [ ! -f ../afijos/l10n/$LOCALIZACION/afijos.txt ]; then
  # Si se solicitó un diccionario genérico, o la localización no ha
  # definido sus propias reglas para los afijos, utilizamos la versión
  # genérica de los ficheros.
  ./remover_comentarios.sh < ../afijos/afijos.txt > $AFFIX
else
  # Se usa la versión de la localización solicitada.
  ./remover_comentarios.sh < ../afijos/l10n/$LOCALIZACION/afijos.txt > $AFFIX
fi
echo "¡listo!"

# La lista de palabras se conforma con los distintos grupos de palabras
# comunes a todos los idiomas, más los de la localización solicitada.
# Si se crea el diccionario genérico, se incluyen todas las localizaciones.
TMPWLIST="$MDTMPDIR/wordlist.tmp"
WLIST="$MDTMPDIR/wordlist.txt"
echo -n "Creando la lista de lemas etiquetados... "

# Palabras comunes a todos los idiomas, definidas por la RAE.
cat ../palabras/RAE/*.txt | ./remover_comentarios.sh > $TMPWLIST

if [ -d "../palabras/RAE/l10n/$LOCALIZACION" ]; then
  # Incluir las palabras de la localización solicitada, definidas por la RAE.
  cat ../palabras/RAE/l10n/$LOCALIZACION/*.txt \
    | ./remover_comentarios.sh \
    >> $TMPWLIST
else
  # Diccionario genérico; incluir todas las localizaciones.
  cat `$FIND ../palabras/RAE/l10n/ -iname "*.txt" -and ! -regex '.*/\.svn.*'` \
    | ./remover_comentarios.sh \
    >> $TMPWLIST
fi

if [ "$RAE" != "SÍ" ]; then
  # Incluir palabras comunes, no definidas por la RAE
  cat ../palabras/noRAE/*.txt | ./remover_comentarios.sh >> $TMPWLIST

  # Issue #39 - Incluir topónimos
  # Se especifica un prefijo de nombre de archivo porque hay directorios que
  # contienen archivos con explicaciones (p.e.: es_ES)
  cat ../palabras/toponimos/toponimos-*.txt \
    | ./remover_comentarios.sh \
    >> $TMPWLIST

  if [ -d "../palabras/noRAE/l10n/$LOCALIZACION" ]; then
    # Incluir las palabras de la localización solicitada.
    cat ../palabras/noRAE/l10n/$LOCALIZACION/*.txt \
      | ./remover_comentarios.sh \
      >> $TMPWLIST

    # Issue #39 - Incluir topónimos de la localización (pendiente de definir
    # condiciones de inclusión)
    cat ../palabras/toponimos/l10n/$LOCALIZACION/toponimos-*.txt \
      | ./remover_comentarios.sh \
      >> $TMPWLIST
  else
    # Diccionario genérico; incluir todas las localizaciones.
    cat `$FIND ../palabras/noRAE/l10n/ \
               -iname "*.txt" -and ! -regex '.*/\.svn.*'` \
      | ./remover_comentarios.sh \
      >> $TMPWLIST

    # Issue #39 - Incluir topónimos de todas las localizaciones (pendiente de
    # definir condiciones de inclusión)
    cat `$FIND ../palabras/toponimos/l10n/ \
               -iname "toponimos-*.txt" -and ! -regex '.*/\.svn.*'` \
      | ./remover_comentarios.sh \
      >> $TMPWLIST
  fi
fi

# Generar el fichero con la lista de palabras (únicas), indicando en la
# primera línea el número de palabras que contiene.
DICFILE="$MDTMPDIR/$LOCALIZACION.dic"
sort -u < $TMPWLIST | wc -l | cut -d ' ' -f1 > $DICFILE
sort -u < $TMPWLIST >> $DICFILE
rm -f $TMPWLIST
echo "¡listo!"

# Restauramos la variable de entorno LANG
LANG=$LANG_BAK

# Crear paquete de diccionario
case $LOCALIZACION in
  es_AR)
    PAIS="Argentina"
    LOCALIZACIONES="es-AR"
    TEXTO_LOCAL="LOCALIZADA PARA ARGENTINA               "
    ICONO="Argentina.png"
    ;;
  es_BO)
    PAIS="Bolivia"
    LOCALIZACIONES="es-BO"
    TEXTO_LOCAL="LOCALIZADA PARA BOLIVIA                 "
    ICONO="Bolivia.png"
    ;;
  es_CL)
    PAIS="Chile"
    LOCALIZACIONES="es-CL"
    TEXTO_LOCAL="LOCALIZADA PARA CHILE                   "
    ICONO="Chile.png"
    ;;
  es_CO)
    PAIS="Colombia"
    LOCALIZACIONES="es-CO"
    TEXTO_LOCAL="LOCALIZADA PARA COLOMBIA                "
    ICONO="Colombia.png"
    ;;
  es_CR)
    PAIS="Costa Rica"
    LOCALIZACIONES="es-CR"
    TEXTO_LOCAL="LOCALIZADA PARA COSTA RICA              "
    ICONO="Costa_Rica.png"
    ;;
  es_CU)
    PAIS="Cuba"
    LOCALIZACIONES="es-CU"
    TEXTO_LOCAL="LOCALIZADA PARA CUBA                    "
    ICONO="Cuba.png"
    ;;
  es_DO)
    PAIS="República Dominicana"
    LOCALIZACIONES="es-DO"
    TEXTO_LOCAL="LOCALIZADA PARA REPÚBLICA DOMINICANA    "
    ICONO="República_Dominicana.png"
    ;;
  es_EC)
    PAIS="Ecuador"
    LOCALIZACIONES="es-EC"
    TEXTO_LOCAL="LOCALIZADA PARA ECUADOR                 "
    ICONO="Ecuador.png"
    ;;
  es_ES)
    PAIS="España"
    LOCALIZACIONES="es-ES"
    TEXTO_LOCAL="LOCALIZADA PARA ESPAÑA                  "
    ICONO="España.png"
    ;;
  es_GT)
    PAIS="Guatemala"
    LOCALIZACIONES="es-GT"
    TEXTO_LOCAL="LOCALIZADA PARA GUATEMALA               "
    ICONO="Guatemala.png"
    ;;
  es_HN)
    PAIS="Honduras"
    LOCALIZACIONES="es-HN"
    TEXTO_LOCAL="LOCALIZADA PARA HONDURAS                "
    ICONO="Honduras.png"
    ;;
  es_MX)
    PAIS="México"
    LOCALIZACIONES="es-MX"
    TEXTO_LOCAL="LOCALIZADA PARA MÉXICO                  "
    ICONO="México.png"
    ;;
  es_NI)
    PAIS="Nicaragua"
    LOCALIZACIONES="es-NI"
    TEXTO_LOCAL="LOCALIZADA PARA NICARAGUA               "
    ICONO="Nicaragua.png"
    ;;
  es_PA)
    PAIS="Panamá"
    LOCALIZACIONES="es-PA"
    TEXTO_LOCAL="LOCALIZADA PARA PANAMÁ                  "
    ICONO="Panamá.png"
    ;;
  es_PE)
    PAIS="Perú"
    LOCALIZACIONES="es-PE"
    TEXTO_LOCAL="LOCALIZADA PARA PERÚ                    "
    ICONO="Perú.png"
    ;;
  es_PR)
    PAIS="Puerto Rico"
    LOCALIZACIONES="es-PR"
    TEXTO_LOCAL="LOCALIZADA PARA PUERTO RICO             "
    ICONO="Puerto_Rico.png"
    ;;
  es_PY)
    PAIS="Paraguay"
    LOCALIZACIONES="es-PY"
    TEXTO_LOCAL="LOCALIZADA PARA PARAGUAY                "
    ICONO="Paraguay.png"
    ;;
  es_SV)
    PAIS="El Salvador"
    LOCALIZACIONES="es-SV"
    TEXTO_LOCAL="LOCALIZADA PARA EL SALVADOR             "
    ICONO="El_Salvador.png"
    ;;
  es_UY)
    PAIS="Uruguay"
    LOCALIZACIONES="es-UY"
    TEXTO_LOCAL="LOCALIZADA PARA URUGUAY                 "
    ICONO="Uruguay.png"
    ;;
  es_VE)
    PAIS="Venezuela"
    LOCALIZACIONES="es-VE"
    TEXTO_LOCAL="LOCALIZADA PARA VENEZUELA               "
    ICONO="Venezuela.png"
    ;;
  *)
    PAIS="España y América Latina"
    LOCALIZACIONES="es-AR es-BO es-CL es-CO es-CR es-CU es-DO es-EC es-ES es-GT"
    LOCALIZACIONES="$LOCALIZACIONES es-HN es-MX es-NI es-PA es-PE es-PR es-PY"
    LOCALIZACIONES="$LOCALIZACIONES es-SV es-UY es-VE"
    TEXTO_LOCAL="GENÉRICA PARA TODAS LAS LOCALIZACIONES  "
    ICONO="Iberoamérica.png"
    ;;
esac

cat ../docs/README_base.txt \
  | sed -n --expression="
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
    /__LOCALE_TEXT__/ {s//$TEXTO_LOCAL/g; p; };
    /__COUNTRY__/ { s//$PAIS/g; p; }" \
  > $MDTMPDIR/README.txt
cp ../docs/Changelog.txt ../docs/GPLv3.txt ../docs/LGPLv3.txt \
  ../docs/MPL-1.1.txt $MDTMPDIR

if [ "$VERSION" != "2" ]; then
  if [ "$COMPLETO" != "SÍ" ]; then
    DESCRIPCION="Español ($PAIS): Ortografía"
    cat ../docs/dictionaries.xcu \
      | sed -n --expression="
        /__/! { p; };
        /__LOCALE__/ { s//$LOCALIZACION/g; p; };
        /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
        /__LOCALE_TEXT__/ { s//$TEXTO_LOCAL/g; p; };
        /__DESCRIPTION__/ { s//$DESCRIPCION/g; p; };
        /__ICON__/ { s//$ICONO/g; p; };
        /__COUNTRY__/ { s//$PAIS/g; p; }" \
      > $MDTMPDIR/dictionaries.xcu
    cat ../docs/package-description.txt \
      | sed -n --expression="
        /__/! { p; };
        /__LOCALE__/ { s//$LOCALIZACION/g; p; };
        /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
        /__LOCALE_TEXT__/ { s//$TEXTO_LOCAL/g; p; };
        /__DESCRIPTION__/ { s//$DESCRIPCION/g; p; };
        /__ICON__/ { s//$ICONO/g; p; };
        /__COUNTRY__/ { s//$PAIS/g; p; }" \
      > $MDTMPDIR/package-description.txt
  else
    DESCRIPCION="Español ($PAIS): Ortografía, separación y sinónimos"
    cat ../docs/dictionaries_full.xcu \
      | sed -n --expression="
        /__/! { p; };
        /__LOCALE__/ { s//$LOCALIZACION/g; p; };
        /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
        /__LOCALE_TEXT__/ { s//$TEXTO_LOCAL/g; p; };
        /__DESCRIPTION__/ { s//$DESCRIPCION/g; p; };
        /__ICON__/ { s//$ICONO/g; p; };
        /__COUNTRY__/ { s//$PAIS/g; p; }" \
      > $MDTMPDIR/dictionaries.xcu
    cat ../docs/package-description_full.txt \
      | sed -n --expression="
        /__/! { p; };
        /__LOCALE__/ { s//$LOCALIZACION/g; p; };
        /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
        /__LOCALE_TEXT__/ { s//$TEXTO_LOCAL/g; p; };
        /__DESCRIPTION__/ { s//$DESCRIPCION/g; p; };
        /__ICON__/ { s//$ICONO/g; p; };
        /__COUNTRY__/ { s//$PAIS/g; p; }" \
      > $MDTMPDIR/package-description.txt
    cp ../../separacion/hyph_es_ANY.dic \
      ../../separacion/README_hyph_es_ANY.txt $MDTMPDIR
    cp ../../sinonimos/palabras/README_th_es_ES.txt \
      ../../sinonimos/palabras/COPYING_th_es_ES \
      ../../sinonimos/palabras/th_es_ES_v2.* $MDTMPDIR
  fi
  cat ../docs/description.xml \
    | sed -n --expression="
      /__/! { p; };
      /__LOCALE__/ { s//$LOCALIZACION/g; p; };
      /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
      /__LOCALE_TEXT__/ { s//$TEXTO_LOCAL/g; p; };
      /__DESCRIPTION__/ { s//$DESCRIPCION/g; p; };
      /__ICON__/ { s//$ICONO/g; p; };
      /__COUNTRY__/ { s//$PAIS/g; p; }" \
    > $MDTMPDIR/description.xml
  cp ../docs/$ICONO $MDTMPDIR
  mkdir "$MDTMPDIR/META-INF"
  cp ../docs/manifest.xml $MDTMPDIR/META-INF
fi

DIRECTORIO_TRABAJO="`pwd`"

if [ "$VERSION" != "3" ]; then
  echo -n "Creando paquete comprimido para las versiones 1.x o 2.x de OpenOffice.org... "
  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.zip"
else
  echo -n "Creando extensión para Apache OpenOffice/LibreOffice 3.x o superior (.oxt)... "
  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.oxt"
fi

cd $MDTMPDIR
$ZIP -r -q $ZIPFILE *
cd $DIRECTORIO_TRABAJO
echo "¡listo!"

# Eliminar la carpeta temporal
rm -Rf $MDTMPDIR

echo "¡Proceso finalizado!"
