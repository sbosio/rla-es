#!/bin/bash
#
# make_dict.sh: Script para la creación del paquete de diccionario.
#
# Copyleft 2005-2020, Santiago Bosio e Ismael Olea
# Este programa se distribuye en los términos del proyecto RLA-ES:
# https://github.com/sbosio/rla-es/blob/master/LICENSE.md

L10N_REGIONALES="es_AR es_BO es_CL es_CO es_CR es_CU es_DO es_EC es_ES es_GQ es_GT es_HN"
L10N_REGIONALES+=" es_MX es_NI es_PA es_PE es_PH es_PR es_PY es_SV es_US es_UY es_VE"
L10N_DISPONIBLES="es $L10N_REGIONALES"

# Herramientas básicas para el script
MKTEMP=$(command -v mktemp 2>/dev/null)
GREP=$(command -v grep 2>/dev/null)
FIND=$(command -v find 2>/dev/null)
ZIP=$(command -v zip 2>/dev/null)

# Comprobaciones previas:
[ "$MKTEMP" == "" ] && echo "No se encontró el comando 'mktemp'... Abortando." >&2 ;exit 1
[ "$GREP" == "" ] && echo "No se encontró el comando 'grep'... Abortando." >&2; exit 1
[ "$FIND" == "" ] && echo "No se encontró el comando 'find'... Abortando." >&2; exit 1
[ "$ZIP" == "" ] && echo "No se encontró el comando 'zip'... Abortando." >&2;exit 1
[ ! -d "ortografia/palabras/" ] && \
  echo "Error: debe lanzar el script desde el directorio raiz del proyecto (normalmente rla-es/). Abortando" >&2; \
  exit 1

FUENTEOXT="plantillas-exportación/plantilla-oxt"

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

  # creo que esto ya no lo usamos
  # argumento=$(expr "z$opcion" : 'z[^=]*=\(.*\)')

  case $opcion in

    --localizacion | --localización | --locale | -l)
      previa="LOCALIZACIONES" ;;
    # --localizacion=* | --localización=* | --locale=* | -l=*)
    #   LOCALIZACIONES=$argumento 
    #   ;;

    --todas | -t)
      LOCALIZACIONES=$L10N_DISPONIBLES
      TODAS="SÍ" ;;

    --configurar | -c)
      CONFIGURAR="SÍ" ;;

    --ayuda | --help | -h)
      echo
      echo "Sintaxis de la orden: $0 [opciones]."
      echo "Las opciones pueden ser las siguientes:"
      echo
      echo "--localizacion=LOC | -l LOC"
      echo "    Localización a utilizar en la generación del diccionario."
      echo "    El argumento LOC debe ser un código CLDR de localización"
      echo "    implementado (es_AR, es_ES, es_MX, etc)."
      echo
      echo "--todos | -t"
      echo "    Generar diccionarios para todas las localizaciones registradas."
      echo
      echo "--rae | -r"
      echo "    Incluir únicamente las palabras pertenecientes al"
      echo "    diccionario de la Real Academia Española."
      echo
      echo "--configurar | -c"
      echo "    Configurar detalles de publicación de los recursos"
      exit 0 ;;

    *)
      echo
      echo "Opción no reconocida: '$opcion'." >&2
      echo "Consulte la ayuda del comando: '$0 --ayuda'." >&2
      echo
      exit 1 ;;
  esac
done


# configuración de variables

if [ "$CONFIGURAR" == "SÍ" ] ; 
  then
    # shellcheck disable=SC1091
    [[ -f .versiones.cfg ]] && . .versiones.cfg
    echo -n "Escriba el número de versión actual de corrector"; [ "$CORRECTOR" ] && echo -n " (valor actual $CORRECTOR) "; echo -n ": "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$CORRECTOR" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$CORRECTOR" == "" ]  && CORRECTOR=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$CORRECTOR" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$CORRECTOR" == "" ]  && CORRECTOR=$RESPUESTA

    echo -n "Escriba el número de versión actual de separación"; [ "$SEPARACION" ] && echo -n " (valor actual $SEPARACION): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$SEPARACION" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$SEPARACION" == "" ]  && SEPARACION=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$SEPARACION" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$SEPARACION" == "" ]  && SEPARACION=$RESPUESTA

    echo -n "Escriba el número de versión actual de corrector"; [ "$SINONIMOS" ] && echo -n " (valor actual $SINONIMOS): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$SINONIMOS" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$SINONIMOS" == "" ]  && SINONIMOS=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$SINONIMOS" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$SINONIMOS" == "" ]  && SINONIMOS=$RESPUESTA

    echo -n "Escriba la ruta al clon local del repositorio LibreOffice «dictionaries»"; [ "$LO_DICTIONARIES_GIT" ] && echo -n " (valor actual $LO_DICTIONARIES_GIT): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$LO_DICTIONARIES_GIT" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$LO_DICTIONARIES_GIT" == "" ]  && LO_DICTIONARIES_GIT=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$LO_DICTIONARIES_GIT" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$LO_DICTIONARIES_GIT" == "" ]  && LO_DICTIONARIES_GIT=$RESPUESTA

    cat << EOF > ./.versiones.cfg
# asignación de variables en lenguaje shell de Bash
#
# CORRECTOR, versión de la edición actual del corrector ortográfico
CORRECTOR="$CORRECTOR"

# SEPARACION, versión de la edición actual del patrón de silabeo
SEPARACION="$SEPARACION"

# SINONIMOS, versión de la edición actual del patrón de silabeo
SINONIMOS="$SINONIMOS"

# LO_DICTIONARIES_GIT, ruta a la copia local de https://gerrit.libreoffice.org/admin/repos/dictionaries
LO_DICTIONARIES_GIT="$LO_DICTIONARIES_GIT"

EOF
    echo "El fichero de configuración .versiones.cfg está actualizado"
    exit 0
fi

# shellcheck disable=SC1091
if [[ -f .versiones.cfg ]] && . .versiones.cfg
  then 
    echo "Configuración actual:"
    echo "Corrector: $CORRECTOR"
    echo "Separación: $SEPARACION"
    echo "Sinónimos: $SINONIMOS"
    echo "Diccionarios LibreOffice: $LO_DICTIONARIES_GIT" 
    echo -n "¿La configuración es correcta? (s/n) "
    read -r  -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" ] || [ "$RESPUESTA" == "N" ]; then
      echo -e "\n¿No?, pues ni una palabra más." >&2
      exit 2
    fi
  else 
    echo "Error, no existe el fichero de configuración .versiones.cfg" 
    echo "Para crear una configuración ejecute $0 con la opción --configurar | -c"
    exit 1
fi

for item in $L10N_DISPONIBLES ; do 
    if [ "$item" = "$LOCALIZACIONES" ] ; 
      then break;
    fi
done

if [ ! "$item" = "$LOCALIZACIONES" ] && [ ! "$TODAS" = "SÍ" ] 
  then echo "Error: RLA-ES no contempla $LOCALIZACIONES. Use un código regional del español disponible: $L10N_DISPONIBLES"; exit 1;
fi

unset LANG

# Verificar si se pasó una localización como parámetro.
if [ "$LOCALIZACIONES" != "" ]; then
  # Verificar que la localización solicitada esté implementada.
  if ! [ -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" -o \
       -d "ortografia/palabras/noRAE/l10n/$LOCALIZACION" ]; then
    echo "No se ha implementado la localización '$LOCALIZACION'." >&2
    echo -ne "¿Desea crear el diccionario genérico? (S/n): " >&2
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" -o "$RESPUESTA" == "N" ]; then
      echo -e "No.\nProceso abortado.\n" >&2
      exit 2
    else
      echo "Sí" >&2
      LOCALIZACIONES="es"
    fi
  fi
else
  # Si no se pasó el parámetro de localización, asumimos que se desea
  # generar el diccionario genérico.
  LOCALIZACIONES="es"
fi

for LOCALIZACION in $LOCALIZACIONES; do
  if [ "$LOCALIZACION" != "es" ]; then
    # Cambiamos la localización y codificación de caracteres.
    LANG="$LOCALIZACION.UTF-8"
    echo "Creando un diccionario para la localización '$LOCALIZACION'..."
  else
    echo "No se definió una localización; creando el diccionario genérico..."
    LANG="es.UTF-8"
  fi

  # Crear un directorio temporal de trabajo
  MDTMPDIR="$($MKTEMP -d /tmp/makedict.XXXXXXXXXX)"

  # Para el fichero de afijos encadenamos los distintos segmentos (encabezado,
  # prefijos y sufijos) de la localización seleccionada, eliminando los
  # comentarios y espacios innecesarios.
  AFFIX="$MDTMPDIR/$LOCALIZACION.aff"
  echo "Creando el fichero de afijos:"
  
  if [ ! -f ortografia/afijos/l10n/$LOCALIZACION/afijos.txt ]; then
    echo "Advertencia: no he encontrado el fichero ortografia/afijos/l10n/$LOCALIZACION/afijos.txt"
  fi
  if [ ! -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" ]; then
    echo "Advertenche el directorio ortografia/palabras/RAE/l10n/$LOCALIZACION"
  fi
  if [ ! -d "ortografia/palabras/noRAE/l10n/$LOCALIZACION" ]; then
    echo "Advertenche el directorio ortografia/palabras/noRAE/l10n/$LOCALIZACION"
  fi
  if [ ! -d "ortografia/palabras/toponimos/l10n/$LOCALIZACION" ]; then
    echo "Advertenche el directorio ortografia/palabras/toponimos/l10n/$LOCALIZACION"
  fi


  if [ ! -f ortografia/afijos/l10n/$LOCALIZACION/afijos.txt ]; then
    # Si se solicitó un diccionario genérico, o la localización no ha
    # definido sus propias reglas para los afijos, utilizamos la versión
    # genérica de los ficheros.
    herramientas/remover_comentarios.sh < ortografia/afijos/afijos.txt > "$AFFIX"
  else
    # Se usa la versión de la localización solicitada.
    herramientas/remover_comentarios.sh < ortografia/afijos/l10n/$LOCALIZACION/afijos.txt > "$AFFIX"
  fi
  echo "¡listo!"

  # La lista de palabras se conforma con los distintos grupos de palabras
  # comunes a todos los idiomas, más los de la localización solicitada.
  # Si se crea el diccionario genérico, se incluyen todas las localizaciones.
  TMPWLIST="$MDTMPDIR/wordlist.tmp"
  echo -n "Creando la lista de lemas etiquetados... "

  # Palabras comunes a todos los idiomas, definidas por la RAE.
  cat ortografia/palabras/RAE/*.txt | herramientas/remover_comentarios.sh > "$TMPWLIST"

  if [ -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" ]; then
    # Incluir las palabras de la localización solicitada, definidas por la RAE.
    cat ortografia/palabras/RAE/l10n/$LOCALIZACION/*.txt \
      | herramientas/remover_comentarios.sh \
      >> "$TMPWLIST"
  else
    # Diccionario genérico; incluir todas las localizaciones.
    cat $($FIND ortografia/palabras/RAE/l10n/ -iname "*.txt" -and ! -regex '.*/\.svn.*') \
      | herramientas/remover_comentarios.sh \
      >> "$TMPWLIST"
  fi

  if [ "$RAE" != "SÍ" ]; then
    # Incluir palabras comunes, no definidas por la RAE
    cat ortografia/palabras/noRAE/*.txt | herramientas/remover_comentarios.sh >> "$TMPWLIST"

    # Issue #39 - Incluir topónimos
    # Se especifica un prefijo de nombre de archivo porque hay directorios que
    # contienen archivos con explicaciones (p.e.: es_ES)
    cat ortografia/palabras/toponimos/toponimos-*.txt \
      | herramientas/remover_comentarios.sh \
      >> "$TMPWLIST"

    if [ -d "ortografia/palabras/noRAE/l10n/$LOCALIZACION" ]; then
      # Incluir las palabras de la localización solicitada.
      cat ortografia/palabras/noRAE/l10n/$LOCALIZACION/*.txt \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"

      # Issue #39 - Incluir topónimos de la localización (pendiente de definir
      # condiciones de inclusión)
      if [ -d "ortografia/palabras/toponimos/l10n/$LOCALIZACION" ]; then
        cat ortografia/palabras/toponimos/l10n/$LOCALIZACION/toponimos-*.txt \
          | herramientas/remover_comentarios.sh \
          >> "$TMPWLIST"
      fi
    else
      # Diccionario genérico; incluir todas las localizaciones.
      cat $($FIND ortografia/palabras/noRAE/l10n/ \
                 -iname "*.txt" -and ! -regex '.*/\.svn.*') \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"

      # Issue #39 - Incluir topónimos de todas las localizaciones (pendiente de
      # definir condiciones de inclusión)
      cat $($FIND ortografia/palabras/toponimos/l10n/ \
                 -iname "toponimos-*.txt" -and ! -regex '.*/\.svn.*') \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"
    fi
  fi

  # Generar el fichero con la lista de palabras (únicas), indicando en la
  # primera línea el número de palabras que contiene.
  DICFILE="$MDTMPDIR/$LOCALIZACION.dic"
  sort -u < "$TMPWLIST" | wc -l | cut -d ' ' -f1 > "$DICFILE"
  sort -u < "$TMPWLIST" >> "$DICFILE"
  rm -f "$TMPWLIST"
  echo "¡listo!"

  # Crear paquete de diccionario
  case $LOCALIZACION in
    es_AR)
      PAIS="Argentina"
      LOCALIZACIONES="es_AR"
      TEXTO_LOCAL="LOCALIZADA PARA ARGENTINA               "
      ICONO="Argentina.png"
      ;;
    es_BO)
      PAIS="Bolivia"
      LOCALIZACIONES="es_BO"
      TEXTO_LOCAL="LOCALIZADA PARA BOLIVIA                 "
      ICONO="Bolivia.png"
      ;;
    es_CL)
      PAIS="Chile"
      LOCALIZACIONES="es_CL"
      TEXTO_LOCAL="LOCALIZADA PARA CHILE                   "
      ICONO="Chile.png"
      ;;
    es_CO)
      PAIS="Colombia"
      LOCALIZACIONES="es_CO"
      TEXTO_LOCAL="LOCALIZADA PARA COLOMBIA                "
      ICONO="Colombia.png"
      ;;
    es_CR)
      PAIS="Costa Rica"
      LOCALIZACIONES="es_CR"
      TEXTO_LOCAL="LOCALIZADA PARA COSTA RICA              "
      ICONO="Costa_Rica.png"
      ;;
    es_CU)
      PAIS="Cuba"
      LOCALIZACIONES="es_CU"
      TEXTO_LOCAL="LOCALIZADA PARA CUBA                    "
      ICONO="Cuba.png"
      ;;
    es_DO)
      PAIS="República Dominicana"
      LOCALIZACIONES="es_DO"
      TEXTO_LOCAL="LOCALIZADA PARA REPÚBLICA DOMINICANA    "
      ICONO="República_Dominicana.png"
      ;;
    es_EC)
      PAIS="Ecuador"
      LOCALIZACIONES="es_EC"
      TEXTO_LOCAL="LOCALIZADA PARA ECUADOR                 "
      ICONO="Ecuador.png"
      ;;
    es_ES)
      PAIS="España"
      LOCALIZACIONES="es_ES"
      TEXTO_LOCAL="LOCALIZADA PARA ESPAÑA                  "
      ICONO="España.png"
      ;;
    es_GQ)
      PAIS="Guinea Ecuatorial"
      LOCALIZACIONES="es_GQ"
      TEXTO_LOCAL="LOCALIZADA PARA GUINEA ECUATORIAL        "
      ICONO="GuineaEcuatorial.png"
      ;;
    es_GT)
      PAIS="Guatemala"
      LOCALIZACIONES="es_GT"
      TEXTO_LOCAL="LOCALIZADA PARA GUATEMALA               "
      ICONO="Guatemala.png"
      ;;
    es_HN)
      PAIS="Honduras"
      LOCALIZACIONES="es_HN"
      TEXTO_LOCAL="LOCALIZADA PARA HONDURAS                "
      ICONO="Honduras.png"
      ;;
    es_MX)
      PAIS="México"
      LOCALIZACIONES="es_MX"
      TEXTO_LOCAL="LOCALIZADA PARA MÉXICO                  "
      ICONO="México.png"
      ;;
    es_NI)
      PAIS="Nicaragua"
      LOCALIZACIONES="es_NI"
      TEXTO_LOCAL="LOCALIZADA PARA NICARAGUA               "
      ICONO="Nicaragua.png"
      ;;
    es_PA)
      PAIS="Panamá"
      LOCALIZACIONES="es_PA"
      TEXTO_LOCAL="LOCALIZADA PARA PANAMÁ                  "
      ICONO="Panamá.png"
      ;;
    es_PE)
      PAIS="Perú"
      LOCALIZACIONES="es_PE"
      TEXTO_LOCAL="LOCALIZADA PARA PERÚ                    "
      ICONO="Perú.png"
      ;;
    es_PH)
      PAIS="Filipinas"
      LOCALIZACIONES="es_PH"
      TEXTO_LOCAL="LOCALIZADA PARA FILIPINAS                "
      ICONO="Filipinas.png"
      ;;
    es_PR)
      PAIS="Puerto Rico"
      LOCALIZACIONES="es_PR"
      TEXTO_LOCAL="LOCALIZADA PARA PUERTO RICO             "
      ICONO="Puerto_Rico.png"
      ;;
    es_PY)
      PAIS="Paraguay"
      LOCALIZACIONES="es_PY"
      TEXTO_LOCAL="LOCALIZADA PARA PARAGUAY                "
      ICONO="Paraguay.png"
      ;;
    es_SV)
      PAIS="El Salvador"
      LOCALIZACIONES="es_SV"
      TEXTO_LOCAL="LOCALIZADA PARA EL SALVADOR             "
      ICONO="El_Salvador.png"
      ;;
    es_US)
      PAIS="Estados Unidos"
      LOCALIZACIONES="es_US"
      TEXTO_LOCAL="LOCALIZADA PARA ESTADOS UNIDOS          "
      ICONO="EEUU.png"
      ;;
    es_UY)
      PAIS="Uruguay"
      LOCALIZACIONES="es_UY"
      TEXTO_LOCAL="LOCALIZADA PARA URUGUAY                 "
      ICONO="Uruguay.png"
      ;;
    es_VE)
      PAIS="Venezuela"
      LOCALIZACIONES="es_VU"
      TEXTO_LOCAL="LOCALIZADA PARA VENEZUELA               "
      ICONO="Venezuela.png"
      ;;
    es)
      PAIS="español internacional"
      LOCALIZACIONES=$L10N_REGIONALES
      TEXTO_LOCAL="ESPAÑOL INTERNACIONAL INCLUYENDO TODAS LAS VARIANTES REGIONALES"
      ICONO="Iberoamérica.png"
      ;;
  esac

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
    /__VERSION__/ {s//$CORRECTOR/g; p; }" \
    "$FUENTEOXT"/README_hunspell_es.txt > "$MDTMPDIR/README.txt"
  
  cp LICENSE/* "$MDTMPDIR"

  DESCRIPCION="Español ($PAIS): Ortografía, separación y sinónimos"
  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$LOCALIZACIONES/g; p; }" \
    "$FUENTEOXT"/dictionaries.xcu > "$MDTMPDIR/dictionaries.xcu"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };;
    /__CORRECTOR__/ {s//$CORRECTOR/g; p; };
    /__SEPARACION__/ {s//$SEPARACION/g; p; };
    /__SINONIMOS__/ {s//$SINONIMOS/g; p; }" \
    "$FUENTEOXT/package-description.txt" > "$MDTMPDIR/package-description.txt"
  
  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$LOCALIZACIONES/g; p; };
    /__VERSION__/ {s//$SEPARACION/g; p; }" \
    "$FUENTEOXT/README_hyph_es.txt" > "$MDTMPDIR/README_hyph_es.txtt"
    cp separacion/hyph_es.dic "$MDTMPDIR"

  cp "$FUENTEOXT/README_th_es.txt" \
     sinonimos/palabras/COPYING \
     sinonimos/palabras/th_es_v2.* "$MDTMPDIR"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__VERSION__/ {s//$CORRECTOR/g; p; };
    /__ICON__/ { s//$ICONO/g; p; };
    /__PAIS__/ { s//$PAIS/g; p; }" \
    "$FUENTEOXT/description.xml" > "$MDTMPDIR/description.xml"

  cp plantillas-exportación/iconos/$ICONO "$MDTMPDIR"
  cp -a "$FUENTEOXT/META-INF" "$MDTMPDIR/"

  DIRECTORIO_TRABAJO="$(pwd)/productos"

  if [ ! -d "$DIRECTORIO_TRABAJO" ]; then
    mkdir "$DIRECTORIO_TRABAJO"
  fi

  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.oxt"
  echo -n "Creando $ZIPFILE "

  pushd "$MDTMPDIR" || exit
  $ZIP -r -q "$ZIPFILE" ./*
  popd || exit
  echo "¡listo!"

  # Eliminar la carpeta temporal
  rm -Rf "$MDTMPDIR"
done

echo "¡Proceso finalizado!"
