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

verifica_versiones () {
  local RESPUESTA
  # shellcheck disable=SC1091
  if [[ -f .versiones.cfg ]] && source .versiones.cfg
    then 
      echo "Configuración actual:"
      echo "Corrector: $CORRECTOR"
      echo "Separación: $SEPARACION"
      echo "Sinónimos: $SINONIMOS"
      echo "Diccionarios LibreOffice: $LO_DICTIONARIES_GIT" 
      echo -n "¿La configuración es correcta? (s/n) "
      read -r  -n 1 RESPUESTA
      if [ "$RESPUESTA" == "n" ] || [ "$RESPUESTA" == "N" ]; then
        echo
        echo "La configuración no es correcta."
        echo "Si lo desea puede reconfigurar las versiones lanzando:"
        echo "$0 --configurar | -c"
        exit 
      fi
    else 
      echo
      echo "Error, no existe el fichero de configuración .versiones.cfg"  >&2
      echo "Para crear una configuración ejecute $0 con la opción --configurar | -c"  >&2
      exit 1
  fi
}

Version_penultima=""
Version_ultima=""
version_etiqueta_git () {
  # leemos las dos últimas etiquetas en el repo git
  local STR
  local STR_linea
  STR=$(git tag -l |tail -2)
  while read -r STR_linea; do
      Version_penultima=$STR_linea
      read -r Version_ultima
  done <<< "$STR"
}

# Herramientas básicas para el script
MKTEMP=$(command -v mktemp 2>/dev/null)
GREP=$(command -v grep 2>/dev/null)
FIND=$(command -v find 2>/dev/null)
ZIP=$(command -v zip 2>/dev/null)

# Comprobaciones previas:
[ "$MKTEMP" == "" ] && echo "No se encontró el comando 'mktemp'... Abortando." >&2 && exit 1
[ "$GREP" == "" ] && echo "No se encontró el comando 'grep'... Abortando." >&2 && exit 1
[ "$FIND" == "" ] && echo "No se encontró el comando 'find'... Abortando." >&2 && exit 1
[ "$ZIP" == "" ] && echo "No se encontró el comando 'zip'... Abortando." >&2 && exit 1
[ ! -d "ortografia/palabras/" ] && \
  echo "Error: debe lanzar el script desde el directorio raiz del proyecto (normalmente rla-es/). Abortando" >&2 && \
  exit 1

PLANTILLAOXT="plantillas-exportación/plantilla-oxt"
PLANTILLAXPI="plantillas-exportación/plantilla-xpi"

PLANTILLALO="plantillas-exportación/libreoffice-dictionaries-git"

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

    --subir-a-LibreOffice | -L)
      LO_PUBLICAR="SÍ" ;;

    --changelog | -C)
      CHANGELOG="SÍ" ;;

    --publicar-version | -P)
      PUBLICAR="SÍ" ;;

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
      echo "    Configurar detalles de publicación de los recursos."
      echo
      echo "--changelog | -C"
      echo "    Imprimir los cambios entre las dos últimas versiones etiquetadas."
      echo
      echo "--publicar-version | -P)"
      echo "    Asistente para la publicación de una versión oficial de RLA-ES."
      echo
      echo "--subir-a-LibreOffice | -L"
      echo "    Preparar los materiales para publicar extensiones en LibreOffice."
      echo
      exit 0 ;;

    *)
      echo
      echo "Opción no reconocida: '$opcion'." >&2
      echo "Consulte la ayuda del comando: '$0 --ayuda'." >&2
      echo
      exit 1 ;;
  esac
done

if [ "$PUBLICAR" == "SÍ" ] ; then
  verifica_versiones;
  version_etiqueta_git;
  
  if [[ ! "${Version_ultima//v/}" = "$CORRECTOR" ]] ; then
    echo
    echo "ERROR: el número de versión de la configuración actual ($CORRECTOR) no es igual que la última versión etiquetada en el repositorio (${Version_ultima//v})."
    echo "Revise que tanto la configuración como la etiqueta en el repositorio git son correctos."
    exit 1
  fi
  echo -n "Confirme ¿el fichero Changelog.txt está actualizado para la versión $CORRECTOR? (s/n) "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    echo -e "\nPuede actualizar el fichero Changelog con la orden $0 --changelog | -C"
    exit 1
  fi
  echo "A continuación vamos a realizar cambios en el repositorio git del proyecto."

  echo -e "\n¿Está seguro de que ha añadido al repositorio todos los cambios relacionados con esta versión?"
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    echo -e "\n- repase los cambios pendientes: git status"
    echo "- añada todos los cambios necesarios: git add <fichero1>, <fichero2»..."
    echo "- aplique los cambios: git commit" 
    echo "- vuelva a ejectutar $0 --publicar-version | -P"
    exit 0
  fi

  echo -n "¿Actualizar el repositorio local refrescando con los últimos cambios en origen?"
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
    echo -e "\nejecutando: git fetch; git checkout master; git merge"
    git fetch || exit 1
    git checkout master || exit 1
    git merge || exit 1
  fi  

  echo -ne "\n¿Crear en el repositorio git la etiqueta v$CORRECTOR?"
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
    echo -e "\nejecutando: git tag -a v$CORRECTOR"
    git tag -a "v$CORRECTOR" || exit 1
  fi

  echo "La etiqueta v$CORRECTOR ha sido creada."
  
  echo "Finalmente: "
  echo " - Genere todas las extensiones actualizadas a v$CORRECTOR: $0 --todos | -t "
  echo " - Crear una nueva «release» Github asociada a v$CORRECTOR en la URL https://github.com/sbosio/rla-es/releases/new"
  echo "    - como descripción de la release use el texto añadido a Changelog.txt"
  echo "    - suba a la release todos los contenidos creados en el directorio productos/"
  echo " - Incorpore al repositorio «dictionaries» de LibreOffice situado en $LO_DICTIONARIES_GIT todos los cambios: --subir-a-LibreOffice | -L "

fi

if [ "$CHANGELOG" == "SÍ" ] ; 
  then
    verifica_versiones;
    version_etiqueta_git;
  
    if [[ "${Version_ultima//v/}" < "$CORRECTOR" ]] ;
    then
      echo
      echo
      echo "A continuación aparecerá el listado de actividad desde $Version_ultima hasta v$CORRECTOR."
      echo "Copie el texto que necesite para preparar el contenido definitivo"
      echo "a incluir en el fichero Changelog.txt."
      echo "Pulse intro.";
      # shellcheck disable=SC2162
      read; 
      git log --graph --oneline --decorate --color "$Version_penultima".."$Version_ultima"
      echo -n "¿Quiere editar el fichero Changelog.txt ahora? (s/n) "
      read -r  -n 1 RESPUESTA
      if [ "$RESPUESTA" == "s" ] || [ "$RESPUESTA" == "S" ]; then
        tmp=$( stat -c %Y Changelog.txt )
        $EDITOR Changelog.txt
        [ "$( stat -c %Y Changelog.txt )" == "$tmp" ] && echo -e "\nAdvertencia: el fichero Changelog.txt parece que no ha sido modificado."
      fi
      echo
      exit
    else
      echo
      echo "ERROR: el número de versión de la configuración actual ($CORRECTOR) no es mayor que la última versión etiquetada en el repositorio (${Version_ultima//v})."
      echo "Revise que tanto la configuración como la etiqueta en el repositorio git son correctos."
      exit 1
    fi
fi

if [ "$CONFIGURAR" == "SÍ" ] ; 
  then
    # shellcheck disable=SC1091
    [[ -f .versiones.cfg ]] && source .versiones.cfg
    echo "Los códigos de versión que usamos son estilo vM.n.p."
    echo "Para saber más del estilo de versiones semánticas consulte https://semver.org/."
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

verifica_versiones

for item in $L10N_DISPONIBLES ; do 
    if [ "$item" = "$LOCALIZACIONES" ] ; 
      then break;
    fi
done

if [ ! "$item" = "$LOCALIZACIONES" ] && [ ! "$TODAS" = "SÍ" ] 
  then echo "Error: RLA-ES no contempla $LOCALIZACIONES. Use un código regional del español disponible: $L10N_DISPONIBLES"  >&2; exit 1;
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
    # echo "No se ha indicado ninguna variante que generar. No hay nada más que hacer."
    # exit 0
  fi

  # Crear un directorio temporal de trabajo
  OXTTMPDIR="$($MKTEMP -d /tmp/makedict.XXXXXXXXXX)"
  XPITMPDIR="$($MKTEMP -d /tmp/makedict.XXXXXXXXXX)"
  mkdir "$XPITMPDIR/dictionaries/"
  # Mozilla usa CLDR estilo XX-YY en lugar de XX_YY
  LOC_XPI="${LOCALIZACION//_/-}"

  # Para el fichero de afijos encadenamos los distintos segmentos (encabezado,
  # prefijos y sufijos) de la localización seleccionada, eliminando los
  # comentarios y espacios innecesarios.
  AFFIX="$OXTTMPDIR/$LOCALIZACION.aff"
  echo "Creando el fichero de afijos:"
  
  if [ ! -f ortografia/afijos/l10n/$LOCALIZACION/afijos.txt ]; then
    echo "Advertencia: no he encontrado el fichero ortografia/afijos/l10n/$LOCALIZACION/afijos.txt"
  fi
  if [ ! -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" ]; then
    echo "Advertencia: no he encontrado el directorio ortografia/palabras/RAE/l10n/$LOCALIZACION"
  fi
  if [ ! -d "ortografia/palabras/noRAE/l10n/$LOCALIZACION" ]; then
    echo "Advertencia: no he encontrado el directorio ortografia/palabras/noRAE/l10n/$LOCALIZACION"
  fi
  if [ ! -d "ortografia/palabras/toponimos/l10n/$LOCALIZACION" ]; then
    echo "Advertencia: no he encontrado el directorio ortografia/palabras/toponimos/l10n/$LOCALIZACION"
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
  cp "$AFFIX" "$XPITMPDIR/dictionaries/$LOC_XPI.aff"
  echo "¡listo!"

  # La lista de palabras se conforma con los distintos grupos de palabras
  # comunes a todos los idiomas, más los de la localización solicitada.
  # Si se crea el diccionario genérico, se incluyen todas las localizaciones.
  TMPWLIST="$OXTTMPDIR/wordlist.tmp"
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
  DICFILE="$OXTTMPDIR/$LOCALIZACION.dic"
  sort -u < "$TMPWLIST" | wc -l | cut -d ' ' -f1 > "$DICFILE"
  sort -u < "$TMPWLIST" >> "$DICFILE"
  cp "$DICFILE" "$XPITMPDIR/dictionaries/$LOC_XPI.dic"
  rm -f "$TMPWLIST"
  echo "¡listo!"

  # Crear paquete de diccionario
  case $LOCALIZACION in
    es_AR)
      PAIS="Argentina"
      CLDR="es_AR"
      TEXTO_LOCAL="LOCALIZADA PARA ARGENTINA               "
      ICONO="Argentina.png"
      ;;
    es_BO)
      PAIS="Bolivia"
      CLDR="es_BO"
      TEXTO_LOCAL="LOCALIZADA PARA BOLIVIA                 "
      ICONO="Bolivia.png"
      ;;
    es_CL)
      PAIS="Chile"
      CLDR="es_CL"
      TEXTO_LOCAL="LOCALIZADA PARA CHILE                   "
      ICONO="Chile.png"
      ;;
    es_CO)
      PAIS="Colombia"
      CLDR="es_CO"
      TEXTO_LOCAL="LOCALIZADA PARA COLOMBIA                "
      ICONO="Colombia.png"
      ;;
    es_CR)
      PAIS="Costa Rica"
      CLDR="es_CR"
      TEXTO_LOCAL="LOCALIZADA PARA COSTA RICA              "
      ICONO="Costa_Rica.png"
      ;;
    es_CU)
      PAIS="Cuba"
      CLDR="es_CU"
      TEXTO_LOCAL="LOCALIZADA PARA CUBA                    "
      ICONO="Cuba.png"
      ;;
    es_DO)
      PAIS="República Dominicana"
      CLDR="es_DO"
      TEXTO_LOCAL="LOCALIZADA PARA REPÚBLICA DOMINICANA    "
      ICONO="Republica_Dominicana.png"
      ;;
    es_EC)
      PAIS="Ecuador"
      CLDR="es_EC"
      TEXTO_LOCAL="LOCALIZADA PARA ECUADOR                 "
      ICONO="Ecuador.png"
      ;;
    es_ES)
      PAIS="España"
      CLDR="es_ES"
      TEXTO_LOCAL="LOCALIZADA PARA ESPAÑA                  "
      ICONO="Espanna.png"
      ;;
    es_GQ)
      PAIS="Guinea Ecuatorial"
      CLDR="es_GQ"
      TEXTO_LOCAL="LOCALIZADA PARA GUINEA ECUATORIAL        "
      ICONO="GuineaEcuatorial.png"
      ;;
    es_GT)
      PAIS="Guatemala"
      CLDR="es_GT"
      TEXTO_LOCAL="LOCALIZADA PARA GUATEMALA               "
      ICONO="Guatemala.png"
      ;;
    es_HN)
      PAIS="Honduras"
      CLDR="es_HN"
      TEXTO_LOCAL="LOCALIZADA PARA HONDURAS                "
      ICONO="Honduras.png"
      ;;
    es_MX)
      PAIS="México"
      CLDR="es_MX"
      TEXTO_LOCAL="LOCALIZADA PARA MÉXICO                  "
      ICONO="Mexico.png"
      ;;
    es_NI)
      PAIS="Nicaragua"
      CLDR="es_NI"
      TEXTO_LOCAL="LOCALIZADA PARA NICARAGUA               "
      ICONO="Nicaragua.png"
      ;;
    es_PA)
      PAIS="Panamá"
      CLDR="es_PA"
      TEXTO_LOCAL="LOCALIZADA PARA PANAMÁ                  "
      ICONO="Panama.png"
      ;;
    es_PE)
      PAIS="Perú"
      CLDR="es_PE"
      TEXTO_LOCAL="LOCALIZADA PARA PERÚ                    "
      ICONO="Peru.png"
      ;;
    es_PH)
      PAIS="Filipinas"
      CLDR="es_PH"
      TEXTO_LOCAL="LOCALIZADA PARA FILIPINAS                "
      ICONO="Filipinas.png"
      ;;
    es_PR)
      PAIS="Puerto Rico"
      CLDR="es_PR"
      TEXTO_LOCAL="LOCALIZADA PARA PUERTO RICO             "
      ICONO="Puerto_Rico.png"
      ;;
    es_PY)
      PAIS="Paraguay"
      CLDR="es_PY"
      TEXTO_LOCAL="LOCALIZADA PARA PARAGUAY                "
      ICONO="Paraguay.png"
      ;;
    es_SV)
      PAIS="El Salvador"
      CLDR="es_SV"
      TEXTO_LOCAL="LOCALIZADA PARA EL SALVADOR             "
      ICONO="El_Salvador.png"
      ;;
    es_US)
      PAIS="Estados Unidos"
      CLDR="es_US"
      TEXTO_LOCAL="LOCALIZADA PARA ESTADOS UNIDOS          "
      ICONO="EEUU.png"
      ;;
    es_UY)
      PAIS="Uruguay"
      CLDR="es_UY"
      TEXTO_LOCAL="LOCALIZADA PARA URUGUAY                 "
      ICONO="Uruguay.png"
      ;;
    es_VE)
      PAIS="Venezuela"
      CLDR="es_VE"
      TEXTO_LOCAL="LOCALIZADA PARA VENEZUELA               "
      ICONO="Venezuela.png"
      ;;
    es)
      PAIS="español internacional"
      CLDR=$L10N_DISPONIBLES
      TEXTO_LOCAL="ESPAÑOL INTERNACIONAL INCLUYENDO TODAS LAS VARIANTES REGIONALES"
      ICONO="Iberoamerica.png"
      ;;
  esac

    sed  -e "s/__LOCALE__/$LOC_XPI/g" -e "s/__PAIS__/$PAIS/g" \
      -e "s/__VERSION__/$CORRECTOR/g" \
      > "$XPITMPDIR"/manifest.json \
      < "$PLANTILLAXPI"/manifest.json  

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$CLDR/g; p; };
    /__VERSION__/ {s//$CORRECTOR/g; p; }" \
    "$PLANTILLAOXT"/README_hunspell_es.txt > "$OXTTMPDIR/README.txt"
  cp "$OXTTMPDIR/README.txt" "$XPITMPDIR/dictionaries/"
  
  cp LICENSE.md LICENSE/* "$OXTTMPDIR"
  cp LICENSE.md LICENSE/GPLv3.txt LICENSE/LGPLv3.txt LICENSE/MPL-1.1.txt "$XPITMPDIR/dictionaries/"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$CLDR/g; p; }" \
    "$PLANTILLAOXT"/dictionaries.xcu > "$OXTTMPDIR/dictionaries.xcu"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$CLDR/g; p; };
    /__CORRECTOR__/ { s//$CORRECTOR/g; p; };
    /__SEPARACION__/ { s//$SEPARACION/g; p; };
    /__SINONIMOS__/ {s||$SINONIMOS|g; p; };
    /__COUNTRY__/ { s//$PAIS/g; p; }" \
  "$PLANTILLAOXT"/package-description.txt > "$OXTTMPDIR/package-description.txt"    
  
  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$CLDR/g; p; };
    /__VERSION__/ {s//$SEPARACION/g; p; }" \
    "$PLANTILLAOXT/README_hyph_es.txt" > "$OXTTMPDIR/README_hyph_es.txt"
    cp separacion/hyph_es.dic "$OXTTMPDIR"

  cp "$PLANTILLAOXT/README_th_es.txt" \
     sinonimos/palabras/th_es_v2.* "$OXTTMPDIR"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__VERSION__/ {s//$CORRECTOR/g; p; };
    /__ICON__/ { s//$ICONO/g; p; };
    /__PAIS__/ { s//$PAIS/g; p; }" \
    "$PLANTILLAOXT/description.xml" > "$OXTTMPDIR/description.xml"

  cp plantillas-exportación/iconos/$ICONO "$OXTTMPDIR"
  cp -a "$PLANTILLAOXT/META-INF" "$OXTTMPDIR/"

  DIRECTORIO_TRABAJO="$(pwd)/productos"

  if [ ! -d "$DIRECTORIO_TRABAJO" ]; then
    mkdir "$DIRECTORIO_TRABAJO"
  fi

  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.oxt"
  echo -n "Creando $ZIPFILE "

  pushd "$OXTTMPDIR" > /dev/null || exit
  $ZIP -r -q "$ZIPFILE" ./*
  popd > /dev/null || exit
  echo "¡listo!"

  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.xpi"
  echo -n "Creando $ZIPFILE "

  pushd "$XPITMPDIR" > /dev/null || exit
  $ZIP -r -q "$ZIPFILE" ./*
  popd > /dev/null || exit
  echo "¡listo!"

  # Eliminar la carpeta temporal
  rm -Rf "$OXTTMPDIR"
  rm -Rf "$XPITMPDIR"
done

if [ "$LO_PUBLICAR" == "SÍ" ] ; then
  echo "Manos a la obra con el repositorio de diccionarios de LibreOffice."
  echo -n "Actualizamos el repositorio git al estado más reciente"
  pushd "$LO_DICTIONARIES_GIT" > /dev/null || exit
  git checkout master > /dev/null 2>&1 ; git pull > /dev/null 2>&1 
  popd > /dev/null || exit
  echo "¡listo!"


  for LOCALIZACION in $LOCALIZACIONES; do
    # recrear Dictionary_CLDR.mk:
    sed  -e "s/__LOCALE__/$LOCALIZACION/g" -e "s/__ICON__/$ICONO/g" \
      > "$LO_DICTIONARIES_GIT"Dictionary_"$LOCALIZACION".mk \
      < "$PLANTILLALO"/Dictionary_CLDR.mk  

    DESTINO="$LO_DICTIONARIES_GIT""$LOCALIZACION"

    # recrear cada libreoffice-dictionaries/CLDR/
    rm -rf "$DESTINO"; mkdir "$DESTINO"
    # volcar cada OXT en libreoffice-dictionaries
    echo -n "Volcando el contenido de $LOCALIZACION al repositorio local de LibreOffice. "
    unzip "$DIRECTORIO_TRABAJO"/"$LOCALIZACION".oxt -d "$DESTINO" > /dev/null
    rm "$DESTINO"/th_es_v2.idx   # aquí no lo necesitaremos
    echo "¡listo!"

  done
fi
echo "Proceso finalizado."
