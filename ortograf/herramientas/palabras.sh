#!/bin/bash
#
# palabras.sh: Script para agregar, mover o eliminar palabras del directorio
# general o las localizaciones.
#
# Copyleft 2005-2010, Santiago Bosio
# Este script se distribuye bajo licencia GNU GPL.

# Herramientas básicas para el script
MKTEMP=`which mktemp 2>/dev/null`
GREP=`which grep 2>/dev/null`
SED=`which sed 2>/dev/null`
SVN=`which svn 2>/dev/null`

# Abandonar si no se encuentra alguna de las herramientas
if [ "$MKTEMP" == "" ]; then
  echo "No se encontró el comando 'mktemp'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$GREP" == "" ]; then
  echo "No se encontró el comando 'grep'... Abortando." > /dev/stderr
  exit 1
fi
if [ "$SED" == "" ]; then
  echo "No se encontró el comando 'sed'... Abortando." > /dev/stderr
  exit 1
fi

# La función verifica si existe el fichero cuyo nombre se pasa como parámetro.
# Si no existe, solicita confirmación para crearlo.
# Después de crear el fichero, se ejecuta el comando "add" de subversion para
# añadir el fichero al repositorio en el próximo "commit", si está instalado.
crear_fichero () {
  if [ ! -f "$1" ]; then
    echo > /dev/stderr
    echo "El fichero "$1" no existe." > /dev/stderr
    echo -ne "¿Desea crearlo? (S/n): " > /dev/stderr
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" -o "$RESPUESTA" == "N" ]; then
      echo "No." > /dev/stderr
    else
      echo "Sí" > /dev/stderr
      touch "$1"
      if [ "$SVN" != "" ]; then
        $SVN add "$1"
      fi
      echo
    fi
  fi
}

# La función verifica si existe el directorio de la localización que se pasa
# como parámetro. Si no existe, solicita confirmación para crearlo.
# El directorio se crea a través del comando "mkdir" de subversion, si está
# disponible. Si no, a través del comando normal.
crear_localizacion () {
  if [ ! -d "l10n/$1" ]; then
    echo > /dev/stderr
    echo "El directorio de la localización "$1" no existe." > /dev/stderr
    echo -ne "¿Desea crearlo? (S/n): " > /dev/stderr
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" -o "$RESPUESTA" == "N" ]; then
      echo "No." > /dev/stderr
    else
      echo "Sí" > /dev/stderr
      if [ "$SVN" != "" ]; then
        $SVN mkdir "l10n/$1"
      else
        mkdir "l10n/$1"
      fi
      echo
    fi
  fi
}

# Manejo de las opciones
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

    --mover | --move | -m)
      if [ "$accion" == "" ]; then
        accion="mover"
      else
        echo > /dev/stderr
        echo "No pueden especificarse dos acciones distintas." > /dev/stderr
        echo > /dev/stderr
        exit 1
      fi ;;

    --agregar | --append | -a)
      if [ "$accion" == "" ]; then
        accion="agregar"
      else
        echo > /dev/stderr
        echo "No pueden especificarse dos acciones distintas." > /dev/stderr
        echo > /dev/stderr
        exit 1
      fi ;;

    --eliminar | --delete | -e | -d)
      if [ "$accion" == "" ]; then
        accion="eliminar"
      else
        echo > /dev/stderr
        echo "No pueden especificarse dos acciones distintas." > /dev/stderr
        echo > /dev/stderr
        exit 1
      fi ;;

    --fichero | --file | -f)
      previa="fichero" ;;
    --fichero=* | --file=* | -f=*)
      fichero=$argumento ;;

    --localizacion | --localización | --locale | -l)
      previa="localizacion" ;;
    --localizacion=* | --localización=* | --locale=* | -l=*)
      localizacion=$argumento ;;

    --palabra | --word | -p | -w)
      previa="palabra" ;;
    --palabra=* | --word=* | -p=* | -w=*)
      palabra=$argumento ;;

    --ayuda | --help | -h)
      echo
      echo "Sintaxis del comando: $0 accion -f FICHERO -p PALABRA [-l LOC]."
      echo
      echo "Acciones:"
      echo "--mover | -m"
      echo "    Mueve la 'PALABRA' desde el 'FICHERO' en el directorio actual,"
      echo "    a un fichero del mismo nombre en la localización 'LOC'."
      echo "    En este caso, la opción '-l' es obligatoria."
      echo "    Si desea moverla a varias localizaciones al mismo tiempo,"
      echo "    escríbalas dentro de comillas dobles, separadas por espacios."
      echo "--agregar | -a"
      echo "    Agrega la 'PALABRA' al 'FICHERO' en el directorio actual,"
      echo "    o a un fichero del mismo nombre en la localización 'LOC', si"
      echo "    se especificó la opción '-l'."
      echo "--eliminar | -e"
      echo "    Elimina la 'PALABRA' del 'FICHERO' en el directorio actual,"
      echo "    o de un fichero del mismo nombre en la localización 'LOC', si"
      echo "    se especificó la opción '-l'."
      echo
      echo "Parámetros:"
      echo "--fichero FICHERO | -f FICHERO"
      echo "    Indica el nombre (sin ruta) del fichero involucrado en la"
      echo "    acción indicada."
      echo "--palabra PALABRA | -p PALABRA"
      echo "    Es la palabra sobre la cual se aplicará la acción indicada."
      echo "    Debe figurar exactamente así, o a lo sumo estar etiquetada."
      echo "--localizacion=LOC | -l LOC"
      echo "    Localización a la que se aplicará la acción indicada."
      echo "    Puede especificar más de una localización con la siguiente"
      echo "    sintaxis: '-l=\"es_XX es_YY es_ZZ ...\"'."
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

# Verificar que se haya indicado una acción
if [ "$accion" == "" ]; then
  echo > /dev/stderr
  echo "No se especificó ninguna acción." > /dev/stderr
  echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
  echo > /dev/stderr
  exit 1
fi

# Verificar que se haya indicado un fichero
if [ "$fichero" == "" ]; then
  echo > /dev/stderr
  echo "No se especificó el fichero." > /dev/stderr
  echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
  echo > /dev/stderr
  exit 1
else
  fichero="`basename $fichero`"
fi

# Verificar que se haya indicado una palabra
if [ "$palabra" == "" ]; then
  echo > /dev/stderr
  echo "No se especificó ninguna palabra." > /dev/stderr
  echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
  echo > /dev/stderr
  exit 1
fi

# Verificar que se haya indicado una localización si la acción es "mover"
if [ "$accion" = "mover" -a "$localizacion" = "" ]; then
  echo > /dev/stderr
  echo "La acción mover requiere que se indique una o más localizaciones." \
       > /dev/stderr
  echo "Consulte la ayuda del comando: '$0 --ayuda'." > /dev/stderr
  echo > /dev/stderr
  exit 1
fi

# Hacemos una copia del valor de la variable LANG para poder restaurarla.
LANG_BAK=$LANG

# Establecemos la codificación de caracteres, para las herramientas de manejo
# de cadenas de caracteres.
LANG="es_ES.ISO-8859-1"

# Obtener la palabra completa (con sus posibles etiquetas) si la acción es
# "mover", o "eliminar" del directorio actual.
if [ "$accion" == "mover" -o \
     \( "$accion" == "eliminar" -a "$localizacion" == "" \) \
   ]; then
  if [ -f "$fichero" ]; then
    palabra_real="`grep ^$palabra\$ \"$fichero\"`"
    if [ "$palabra_real" == "" ]; then
      palabra_real="`grep ^$palabra/ \"$fichero\"`"
    fi
    if [ "$palabra_real" == "" ]; then
      echo > /dev/stderr
      echo "No se encontró la palabra '$palabra' en el fichero '$fichero'." \
           > /dev/stderr
      echo "Se canceló la acción \"$accion\"." > /dev/stderr
      echo > /dev/stderr
      exit 2
    fi
  else
    echo > /dev/stderr
    echo "El fichero '$fichero' no existe." > /dev/stderr
    echo "Se canceló la acción \"$accion\"." > /dev/stderr
    echo > /dev/stderr
    exit 3
  fi
else
  palabra_real="$palabra"
fi

# Crear un directorio temporal de trabajo
PTMPDIR="`$MKTEMP -d /tmp/palabras.XXXXXXXXXX`"

# Si la acción es "agregar", o "mover", añadir la palabra a las localizaciones
# indicadas
if [ "$accion" != "eliminar" ]; then
  if [ "$localizacion" == "" ]; then
    # Agregar la palabra al fichero en el directorio actual.
    crear_fichero $fichero
    if [ ! -f "$fichero" ]; then
      echo -n "No se pudo agregar la palabra: " > /dev/stderr
      echo "El fichero '$fichero' no existe." > /dev/stderr
    else
      cp "$fichero" "$PTMPDIR"
      echo "$palabra_real" >> "$PTMPDIR/$fichero"
      sort -u < "$PTMPDIR/$fichero" > "$fichero"
      rm -f "$PTMPDIR/$fichero"
      pal_utf="`echo \"$palabra_real\" | iconv -f iso8859-1 -t utf8`"
      echo "Se agregó '$pal_utf' a '$fichero'."
    fi
  else
    # Agregar la palabra a las distintas localizaciones.
    for loc in $localizacion; do
      crear_localizacion "$loc"
      if [ ! -d "./l10n/$loc" ]; then
        echo -n "No se pudo agregar la palabra a la localización '$loc': " \
             > /dev/stderr
        echo "El directorio './l10n/$loc' no existe." > /dev/stderr
      else
        crear_fichero "./l10n/$loc/$fichero"
        if [ ! -f "./l10n/$loc/$fichero" ]; then
          echo -n "No se pudo agregar la palabra a la localización '$loc': " \
               > /dev/stderr
          echo "El fichero './l10n/$loc/$fichero' no existe." > /dev/stderr
        else
          # Todo bien, agregar la palabra
          cp "./l10n/$loc/$fichero" "$PTMPDIR"
          echo "$palabra_real" >> "$PTMPDIR/$fichero"
          sort -u < "$PTMPDIR/$fichero" > "./l10n/$loc/$fichero"
          rm -f "$PTMPDIR/$fichero"
          pal_utf="`echo \"$palabra_real\" | iconv -f iso8859-1 -t utf8`"
          echo "Se agregó '$pal_utf' a './l10n/$loc/$fichero'."
        fi
      fi
    done
  fi
fi

# Si la acción es "eliminar", o "mover", quitar la palabra de las
# localizaciones indicadas
if [ "$accion" != "agregar" ]; then
  if [ "$localizacion" == "" -o "$accion" == "mover" ]; then
    # Quitar la palabra del fichero en el directorio actual.
    if [ ! -f "$fichero" ]; then
      echo -n "No se pudo eliminar la palabra: " > /dev/stderr
      echo "El fichero '$fichero' no existe." > /dev/stderr
    else
      grep -v "^${palabra_real}\$" "$fichero" > "$PTMPDIR/$fichero"
      mv -f "$PTMPDIR/$fichero" ./
      pal_utf="`echo \"$palabra_real\" | iconv -f iso8859-1 -t utf8`"
      echo "Se eliminó '$pal_utf' de '$fichero'."
    fi
  else
    # Quitar la palabra de las distintas localizaciones.
    for loc in $localizacion; do
      if [ ! -d "./l10n/$loc" ]; then
        echo -n "No se pudo eliminar la palabra (localización '$loc'): " \
             > /dev/stderr
        echo "El directorio './l10n/$loc' no existe." > /dev/stderr
      else
        if [ ! -f "./l10n/$loc/$fichero" ]; then
          echo -n "No se pudo eliminar la palabra (localización '$loc'): " \
               > /dev/stderr
          echo "El fichero './l10n/$loc/$fichero' no existe." > /dev/stderr
        else
          # Todo bien, buscar la palabra y eliminarla
          palabra_real="`grep ^$palabra\$ \"./l10n/$loc/$fichero\"`"
          if [ "$palabra_real" == "" ]; then
            palabra_real="`grep ^$palabra/ \"./l10n/$loc/$fichero\"`"
          fi
          if [ "$palabra_real" == "" ]; then
            echo -n "No se pudo eliminar la palabra (localización '$loc'): " \
                 > /dev/stderr
            echo "No se encontró la palabra '$palabra'." \
                 > /dev/stderr
          else
            grep -v "^${palabra_real}\$" "./l10n/$loc/$fichero" \
                 > "$PTMPDIR/$fichero"
            mv -f "$PTMPDIR/$fichero" "./l10n/$loc/$fichero"
            pal_utf="`echo \"$palabra_real\" | iconv -f iso8859-1 -t utf8`"
            echo "Se eliminó '$pal_utf' de './l10n/$loc/$fichero'."
          fi
        fi
      fi
    done
  fi
fi

# Eliminamos el directorio temporal
rm -Rf $PTMPDIR

# Restauramos la variable LANG
LANG=$LANG_BAK

