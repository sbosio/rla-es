#!/bin/bash
#
# make_dict.sh: Script para la creación del paquete de diccionario.
#
# Copyleft 2005-2022, Santiago Bosio e Ismael Olea
# Este programa se distribuye en los términos del proyecto RLA-ES:
# https://github.com/sbosio/rla-es/blob/master/LICENSE.md

L10N_REGIONALES="es_AR es_BO es_CL es_CO es_CR es_CU es_DO es_EC es_ES es_GQ es_GT es_HN"
L10N_REGIONALES+=" es_MX es_NI es_PA es_PE es_PH es_PR es_PY es_SV es_US es_UY es_VE"
L10N_DISPONIBLES="es $L10N_REGIONALES"
DIRECTORIO_TRABAJO="$(pwd)/productos"

verifica_versiones () {
  local RESPUESTA
  # shellcheck disable=SC1091
  if [[ -f .versiones.cfg ]] && source .versiones.cfg
    then 
      echo "Publicar una nueva versión necesita de la configuración contenida en el fichero .versiones.cfg. Revise si el contenido actual es correcto antes de continuar:"
      echo "Corrector: $CORRECTOR"
      echo "Separación: $SEPARACION"
      echo "Sinónimos: $SINONIMOS"
      echo "Repositorio «dictionaries» de LibreOffice: $LO_DICTIONARIES_GIT" 
      echo -n "¿La configuración es correcta? (s/n): "
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
      echo "ERROR, no existe el fichero de configuración .versiones.cfg"  >&2
      echo "Para crear una configuración ejecute $0 con la opción --configurar | -c"  >&2
      echo "Para ver una configuración de ejemplo, consulte el fichero .versiones.cfg-EJEMPLO" >&2
      exit 1
  fi
}

vCORRECTOR="v${CORRECTOR}"
Version_penultima=""
Version_ultima=""
version_etiqueta_git () {
  # leemos las dos últimas etiquetas en el repo git
  local STR
  local STR_linea
  STR=$(git tag -l |tail -2)
  while read -r STR_linea; do
      # shellcheck disable=SC2034 
      Version_penultima=$STR_linea
      read -r Version_ultima
  done <<< "$STR"
}

imprime_ayuda () {
      echo
      echo "Sintaxis de la orden: $0 [opciones]"
      echo "Las opciones pueden ser las siguientes:"
      echo
      echo "--listado-regiones"
      echo "    Muestra todas las regiones de las variantes del español"
      echo "    más importantes del mundo expresadas con su código CLDR."
      echo 
      echo "--localizacion LOC | -l LOC"
      echo "    Localización a utilizar en la generación del diccionario."
      echo "    El argumento LOC debe ser un código CLDR de localización"
      echo "    implementado (es_AR, es_ES, es_MX, etc). Cada diccionario"
      echo "    se produce dentro del directorio productos/ emapquetado en"
      echo "    forma de extensión de LibreOffice (oxt) y de Mozilla (xpi)."
      echo
      echo "--todas | -t"
      echo "    Generar diccionarios para todas las localizaciones registradas."
      echo "    Igual que la anterior pero para todas las variantes LOC"
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
      echo "    Actualiza el repositorio de diccionarios de LibreOffice con la"
      echo "    última versión de los productos del proyecto."
      
      echo
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
  echo "ERROR: debe lanzar el script desde el directorio raiz del proyecto (normalmente rla-es/). Abortando" >&2 && \
  exit 1

PLANTILLAOXT="herramientas/plantillas-exportación/plantilla-oxt"
PLANTILLAXPI="herramientas/plantillas-exportación/plantilla-xpi"
PLANTILLALO="herramientas/plantillas-exportación/libreoffice-dictionaries-git"

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

  case $opcion in

    --localizacion | --localización | --locale | -l)
      previa="LOCALIZACIONES" ;;

    --todas | -t)
      LOCALIZACIONES=$L10N_DISPONIBLES
      TODAS="SÍ" ;;

    --listado-regiones )
      echo -e "\nMuestra los códigos CLDR con los que trabaja RLA-ES:"
      echo "$L10N_DISPONIBLES"
      exit 0 ;;      

    --configurar | -c)
      CONFIGURAR="SÍ" ;;

    --subir-a-LibreOffice | -L)
      LO_PUBLICAR="SÍ" ;;

    --changelog | -C)
      CHANGELOG="SÍ" ;;

    --publicar-version | -P)
      PUBLICAR="SÍ" ;;

    --ayuda | --help | -h)

      imprime_ayuda;
      exit 0;;

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
  
  if [[ ! "${Version_ultima//v/}" < "$CORRECTOR" ]] ; then
    echo
    echo "ERROR: el número de versión de la configuración actual ($CORRECTOR) no es menor que la última versión etiquetada en el repositorio (${Version_ultima//v})."
    echo "Se da por sentado que no ha seguido el procedimiento de publicación de esta herramienta."
    echo "Revise que tanto la configuración como la etiqueta en el repositorio git son correctos."
    exit 1
  fi
  
  echo -ne "\nConfirme: ¿el fichero Changelog.txt está actualizado para la versión $CORRECTOR? (s/n): "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    echo -e "\n Puede generar el contenido para usar en Changelog.txt usando la orden $0 --changelog | -C"
    exit 1
  fi
  echo -e "\nA continuación vamos a realizar cambios en el repositorio git del proyecto."

  echo -e "\nIMPORTANTE: ¿Está seguro de que ha añadido al repositorio todos los cambios relacionados"
  echo -n "para esta edición? (s/n): "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    echo -e "\n- repase los cambios pendientes: git status"
    echo "- añada todos los cambios necesarios: git add «fichero1» «fichero2»..."
    echo "- aplique los cambios (escribiendo una descripción de los mismos): git commit" 
    echo -e "\nVuelva a ejecutar el programa cuando esté listo."
    exit 0
  fi

  echo -e "\nVamos a actualizar el repositorio local con los últimos cambios en el repositorio"
  echo -n "remoto. Usaremos las órdenes «git fetch; git checkout master; git merge». ¿Está seguro? (s/n): "

  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
    echo -e "\nejecutando: git fetch; git checkout master; git merge"
    git fetch || exit 1
    git checkout 20230808-olea-tmp || exit 1
    git merge || exit 1
  else 
    echo -e "\nVuelva a ejecutar el programa cuando esté listo."
    exit 0
  fi  

  echo "VERSION $vCORRECTOR"
  exit 1

  echo -ne "\n¿Quiere crear la etiqueta $vCORRECTOR en el repositorio git local? (s/n): "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
    echo -e "\nejecutando: git tag -a $vCORRECTOR"
    git tag -a "$vCORRECTOR" || exit 1
    echo "La etiqueta $vCORRECTOR ha sido creada."
  else
    echo -e "\nVuelva a ejecutar el programa cuando esté listo."
    exit 0    
  fi

  echo -e "\nHay que subir al repositorio origen todos los cambios de la versión $vCORRECTOR,"
  echo -n "¿está seguro? (s/n): "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
    echo -e "\nejecutando: git push origin $vCORRECTOR"
    git push origin "$vCORRECTOR" || exit 1
    echo "La etiqueta $vCORRECTOR ha sido actualizada en el repositorio remoto principal."
  else 
    echo -e "\nVuelva a ejecutar el programa cuando esté listo."
    exit 0
  fi
  
  echo -e "\nAhora creamos los paquetes de código fuente a publicar:"
  git archive --format=zip --prefix=rla-"${vCORRECTOR}/"  -o "${DIRECTORIO_TRABAJO}/${vCORRECTOR}".zip "${vCORRECTOR}" || exit 1
  echo "${DIRECTORIO_TRABAJO}/${vCORRECTOR}.zip está listo"
  git archive --format=tgz --prefix=rla-"${vCORRECTOR}/"  -o "${DIRECTORIO_TRABAJO}/${vCORRECTOR}".tar.gz "${vCORRECTOR}" || exit 1
  echo "${DIRECTORIO_TRABAJO}/${vCORRECTOR}.tar.gz está listo"

  echo "Finalmente: "
  echo " - Genere todas las extensiones actualizadas a $vCORRECTOR: $0 --todas | -t "
  echo " - Crear una nueva «release» Github asociada a $vCORRECTOR en la URL https://github.com/sbosio/rla-es/releases/new"
  echo "    - como descripción de la release use el texto añadido a Changelog.txt"
  echo "    - suba a la release todos los contenidos creados en el directorio productos/"
  echo " - Incorpore al repositorio «dictionaries» de LibreOffice, situado en $LO_DICTIONARIES_GIT, todos los cambios: $0 --subir-a-LibreOffice | -L "
  exit 0
fi

if [ "$CHANGELOG" == "SÍ" ] ; 
  then
    verifica_versiones;
    version_etiqueta_git;
  
    if [[ "${Version_ultima//v/}" < "$CORRECTOR" ]] ;
    then
      CHANGELOG_TMP=Changelog-"${CORRECTOR}".txt
      echo
      echo
      echo "A continuación se genera el resumen del texto a añadir a Changelog.txt a partir del registro de actividad de git."
      printf "Versión %s:\n\n" "${CORRECTOR}" > "${CHANGELOG_TMP}"
      git log --pretty=format:"- %s (%h) by %an" "$Version_ultima.." >> "${CHANGELOG_TMP}"
      if [[ -f "${CHANGELOG_TMP}" ]] ;
      then
        echo "El fichero ${CHANGELOG_TMP} está disponible. Puede editar a mano y usar el contenido para actualizar Changelog.txt a su conveniencia."
        echo "Antes de publicar una nueva edición de RLA-ES asegúrese de haber actualizado Changelog.txt."
      else
        echo "ERROR, por algún motivo el fichero ${CHANGELOG_TMP} no ha podido ser generado."
      fi
      exit
    else
      echo
      echo "ERROR: el número de versión de la configuración actual ($CORRECTOR) no es mayor que la última versión etiquetada en el repositorio (${Version_ultima//v})."
      echo "Se da por sentado que si ha etiquetado la versión ya no tiene lugar añadir los cambios relacionados con la misma."
      echo "Revise que tanto la configuración como la etiqueta en el repositorio git son correctos."
      exit 1
    fi
fi

if [ "$CONFIGURAR" == "SÍ" ] ; 
  then
    # shellcheck disable=SC1091
    [[ -f .versiones.cfg ]] && source .versiones.cfg
    echo "Los códigos de versión que usamos son estilo vM.n.p. La letra v se añade por el sistema, no debe indicarla."
    echo "Para saber más del estilo de versiones semánticas consulte https://semver.org/."
    echo -n "Escriba el número de versión actual de corrector (ej.: 2.6"; [ "$CORRECTOR" ] && echo -n ", valor actual $CORRECTOR"; echo -n "): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$CORRECTOR" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$CORRECTOR" == "" ]  && CORRECTOR=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$CORRECTOR" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$CORRECTOR" == "" ]  && CORRECTOR=$RESPUESTA

    echo -n "Escriba el número de versión actual de separación (ej.: 0.2"; [ "$SEPARACION" ] && echo -n ", valor actual $SEPARACION"; echo -n "): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$SEPARACION" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$SEPARACION" == "" ]  && SEPARACION=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$SEPARACION" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$SEPARACION" == "" ]  && SEPARACION=$RESPUESTA

    echo -n "Escriba el identificador de versión actual de sinónimos (ej.: 24/02/2013"; [ "$SINONIMOS" ] && echo -n ", valor actual $SINONIMOS"; echo -n "): "
    read -r RESPUESTA
    [  "$RESPUESTA" == "" ] && [ "$SINONIMOS" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
    [ ! "$RESPUESTA" == "" ] && [ "$SINONIMOS" == "" ]  && SINONIMOS=$RESPUESTA
    [  "$RESPUESTA" == "" ] && [ ! "$SINONIMOS" == "" ]  && :
    [ ! "$RESPUESTA" == "" ] && [ ! "$SINONIMOS" == "" ]  && SINONIMOS=$RESPUESTA

    echo -n "Escriba la ruta al clon local del repositorio LibreOffice «dictionaries»"; [ "$LO_DICTIONARIES_GIT" ] && echo -n " (valor actual $LO_DICTIONARIES_GIT)"; echo -n ": "
    read -r RESPUESTA
#    [  "$RESPUESTA" == "" ] && [ "$LO_DICTIONARIES_GIT" == "" ]  && echo -e "\n \nIntroduzca un valor correcto." >&2 && exit 2
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

if [ "$LO_PUBLICAR" == "SÍ" ] ; then
  verifica_versiones;
  version_etiqueta_git;
  
  if [[ ! "${Version_ultima//v/}" = "$CORRECTOR" ]] ; then
    echo
    echo "ERROR: el número de versión de la configuración actual ($CORRECTOR) no es igual que la última versión etiquetada en el repositorio (${Version_ultima//v})."
    echo "No tiene sentido enviar a LibreOffice cambios de una versión oficial no publicada oficialmente."
    echo "Revise que tanto la configuración como la etiqueta en el repositorio git son correctos."
    exit 1
  fi

  echo -e "\nPara publicar en el repositorio git de LibreOffice es imprescindible haber"
  echo "generado todas las extensiones LibreOffice (oxt)."
  echo -n "Antes de continuar, ¿está seguro de que ha creado TODAS las extensiones? (s/n): "
  read -r  -n 1 RESPUESTA
  if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    echo -e "\nPor favor genere todas las extensiones con la orden:"
    echo "$0 --todas | -t"
    exit 1
  fi
  if [ ! -d "$LO_DICTIONARIES_GIT" ] ; then
    echo -e "\nERROR: no existe el directorio $LO_DICTIONARIES_GIT"
    echo 
    echo "Si no ha descargado el repositorio a su sistema deberá usar una orden semejante a esta pero con sus propios datos de usuario:"
    echo "  git clone \"ssh://USUARIO@gerrit.libreoffice.org:29418/dictionaries\" && scp -p -P 29418 USUARIO@gerrit.libreoffice.org:hooks/commit-msg \"dictionaries/.git/hooks/\""
    echo "En cualquier caso configure el directorio correcto con $0 --configurar | -c"
    exit 2;
  fi

  RAMA_GIT="hunspell-es-$CORRECTOR"
  echo -e "\nPreparamos el repositorio git al estado más reciente con una rama nueva para la actualización:"
  pushd "$LO_DICTIONARIES_GIT" > /dev/null || exit
  git fetch || exit
  git checkout master || exit
  git rebase origin/master || exit
  git checkout -b "$RAMA_GIT" || exit
  popd > /dev/null || exit
  echo "¡listo!"

  # configuración de diccionarios para el repo diccionarios de LibreOffice:
  rm -f "$LO_DICTIONARIES_GIT"Dictionary_es.mk || exit 1
  install -m 644 "$PLANTILLALO"/Dictionary_es.mk "$LO_DICTIONARIES_GIT"Dictionary_es.mk

  DESTINO="$LO_DICTIONARIES_GIT"/es
  
  # limpieza de la versión anterior
  rm -rf "$DESTINO" || exit 1
  mkdir "$DESTINO" || exit 1

  # copiamos metadatos
  install -m 644 -d "$PLANTILLAOXT"META-INF/manifest.xml "$DESTINO"/META-INF/manifest.xml
  install -m 644 "$PLANTILLALO"/description.xml "$DESTINO"
  install -m 644 "$PLANTILLALO"/dictionaries.xcu "$DESTINO"
  install -m 644 "$PLANTILLALO"/package-description.txt "$DESTINO"
  install -m 644 herramientas/plantillas-exportación/iconos/RLA-ES.png "$DESTINO"

  # copiamos licencias:
  install -m 644 LICENSE.md LICENSE/* "$DESTINO"

  # copiamos descripciones
  install -m 644 "$PLANTILLAOXT"/README*txt "$DESTINO"

  # extraemos hyph_es.dic th_es_v2.dat 
  unzip productos/es.oxt hyph_es.dic th_es_v2.dat -d "$DESTINO" > /dev/null

  # extraemos los diccionarios regionales
  for item in $L10N_DISPONIBLES; do
  
    echo -n "Volcando el contenido de $item al repositorio local de LibreOffice. "
    unzip productos/"$item".oxt "$item".dic "$item".aff  \
        -d "$DESTINO" > /dev/null
    echo "¡listo!"

  done
  pushd "$LO_DICTIONARIES_GIT" > /dev/null || exit
  echo "Preparamos el commit:"
  git add "$LO_DICTIONARIES_GIT"Dictionary_es.mk "$DESTINO" || exit

  echo "A continuación examine el estado de los cambios:"
  git status

  echo "Si son correctos hay que añadirlos al repositorio local."
  echo "Ejecute las siguientes órdenes _manualmente_:"
  echo
  echo "cd $LO_DICTIONARIES_GIT"
  echo "git commit"
  echo "(se abrirá un editor en el que debe describir _en inglés_ los cambios relacionados con la versión)"
  echo
  echo "Finalmente, para para enviar los cambios a gerrit ejecute:"
  echo
  echo "git push origin $RAMA_GIT:refs/for/master"
  echo   
  echo "El cambio será evaluado en https://gerrit.libreoffice.org/q/project:dictionaries antes" \
    " de ser incorporado a la rama principal del repositorio."
  echo "Si lo desea también podría avisar del cambio escribiendo a mailto:libreoffice@lists.freedesktop.org."
  popd || exit
  exit 0
fi

# Si no hay ninguna opción nos despedimos imprimiendo la ayuda 
if [  "$LOCALIZACIONES" == "" ] && [ ! "$TODAS" == "SÍ" ]; then
  imprime_ayuda;
  exit 0
fi

# a partir de aquí se generan los diccionarios empaquetándolos en extensiones OXT y XPI:

verifica_versiones;
echo

for item in $L10N_DISPONIBLES ; do 
    if [ "$item" = "$LOCALIZACIONES" ] ; 
      then break;
    fi
done

if [ ! "$item" = "$LOCALIZACIONES" ] && [ ! "$TODAS" = "SÍ" ] 
  then echo "ERROR: RLA-ES no contempla $LOCALIZACIONES. Use un código regional del español disponible: $L10N_DISPONIBLES"  >&2; exit 1;
fi

unset LANG

# Verificar si se pasó una localización como parámetro.
if [ "$LOCALIZACIONES" != "" ]; then
  # Verificar que la localización solicitada esté implementada.
  if ! [ -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" -o \
       -d "ortografia/palabras/noRAE/l10n/$LOCALIZACION" ]; then
    echo "No se ha implementado la localización '$LOCALIZACION'." >&2
    echo -ne "¿Desea crear el diccionario general? (S/n): " >&2
    read -r -s -n 1 RESPUESTA
    if [ "$RESPUESTA" == "n" ] || [ "$RESPUESTA" == "N" ]; then
      echo -e "\nVuelva a ejecutar el programa cuando esté listo."
      exit 0    
    else
      echo "Sí" >&2
      LOCALIZACIONES="es"
    fi
  fi
else
  # Si no se pasó el parámetro de localización, asumimos que se desea
  # generar el diccionario general.
  LOCALIZACIONES="es"
fi

for LOCALIZACION in $LOCALIZACIONES; do
  if [ "$LOCALIZACION" != "es" ]; then
    # Cambiamos la localización y codificación de caracteres.
    LANG="$LOCALIZACION.UTF-8"
    echo "Creando un diccionario para la localización '$LOCALIZACION'..."
  else
    echo "No se definió una localización; creando el diccionario general..."
    LANG="es.UTF-8"
    # echo "No se ha indicado ninguna variante que generar. No hay nada más que hacer."
    # exit 0
  fi

  # Crear un directorio temporal de trabajo
  OXTTMPDIR="$($MKTEMP -d /tmp/makedict.XXXXXXXXXX)"
  XPITMPDIR="$($MKTEMP -d /tmp/makedict.XXXXXXXXXX)"
  mkdir "$XPITMPDIR/dictionaries/"
  # En los metadatos de las extensiones se usa CLDR estilo XX-YY en lugar de XX_YY
  CLDR2="${LOCALIZACION//_/-}"

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
    # Si se solicitó el diccionario general, o la localización no ha
    # definido sus propias reglas para los afijos, utilizamos la versión
    # genérica de los ficheros.
    herramientas/remover_comentarios.sh < ortografia/afijos/afijos.txt > "$AFFIX"
  else
    # Se usa la versión de la localización solicitada.
    herramientas/remover_comentarios.sh < ortografia/afijos/l10n/$LOCALIZACION/afijos.txt > "$AFFIX"
  fi
  cp "$AFFIX" "$XPITMPDIR/dictionaries/$CLDR2.aff"
  echo "¡listo!"

  # La lista de palabras se conforma con los distintos grupos de palabras
  # comunes a todos los idiomas, más los de la localización solicitada.
  # Si se crea el diccionario general, se incluyen todas las localizaciones.
  TMPWLIST="$OXTTMPDIR/wordlist.tmp"
  echo -n "Creando la lista de lemas etiquetados... "

  # Palabras comunes a todos los idiomas, definidas por la RAE.
  cat ortografia/palabras/RAE/*.txt | herramientas/remover_comentarios.sh > "$TMPWLIST"

  if [ -d "ortografia/palabras/RAE/l10n/$LOCALIZACION" ]; then
    # Incluir las palabras de la localización solicitada, definidas por la RAE.
    cat ortografia/palabras/RAE/l10n/"$LOCALIZACION"/*.txt \
      | herramientas/remover_comentarios.sh \
      >> "$TMPWLIST"
  else
    # Diccionario general; incluir todas las localizaciones.
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
      cat ortografia/palabras/noRAE/l10n/"$LOCALIZACION"/*.txt \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"

      # Issue #39 - Incluir topónimos de la localización (pendiente de definir
      # condiciones de inclusión)
      if [ -d "ortografia/palabras/toponimos/l10n/$LOCALIZACION" ]; then
        cat ortografia/palabras/toponimos/l10n/"$LOCALIZACION"/toponimos-*.txt \
          | herramientas/remover_comentarios.sh \
          >> "$TMPWLIST"
      fi
    else
      # Diccionario general; incluir todas las localizaciones.
      cat $($FIND ortografia/palabras/noRAE/l10n/ -iname "*.txt" -and ! -regex '.*/\.svn.*') \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"

      # Issue #39 - Incluir topónimos de todas las localizaciones (pendiente de
      # definir condiciones de inclusión)
      cat $($FIND ortografia/palabras/toponimos/l10n/ -iname "toponimos-*.txt" -and ! -regex '.*/\.svn.*') \
        | herramientas/remover_comentarios.sh \
        >> "$TMPWLIST"
    fi
  fi

  # Generar el fichero con la lista de palabras (únicas), indicando en la
  # primera línea el número de palabras que contiene.
  DICFILE="$OXTTMPDIR/$LOCALIZACION.dic"
  sort -u < "$TMPWLIST" | wc -l | cut -d ' ' -f1 > "$DICFILE"
  sort -u < "$TMPWLIST" >> "$DICFILE"
  cp "$DICFILE" "$XPITMPDIR/dictionaries/$CLDR2.dic"
  rm -f "$TMPWLIST"  || exit 1
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
      PAIS="español general"
      CLDR=$L10N_DISPONIBLES
      TEXTO_LOCAL="ESPAÑOL general INCLUYENDO TODAS LAS VARIANTES REGIONALES"
      ICONO="RLA-ES.png"
      ;;
  esac

  sed  -e "s/__LOCALE__/$CLDR2/g" -e "s/__PAIS__/$PAIS/g" \
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

  CLDR3="${CLDR//_/-}"

  sed -n -e "
    /__/! { p; };
    /__LOCALE__/ { s//$LOCALIZACION/g; p; };
    /__LOCALES__/ {s//$CLDR3/g; p; }" \
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

  cp herramientas/plantillas-exportación/iconos/$ICONO "$OXTTMPDIR"
  cp -a "$PLANTILLAOXT/META-INF" "$OXTTMPDIR/"

  if [ ! -d "$DIRECTORIO_TRABAJO" ]; then
    mkdir "$DIRECTORIO_TRABAJO"
  fi

  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.oxt"
  echo -n "Creando $ZIPFILE "

  rm -f "$ZIPFILE" || exit 1
  pushd "$OXTTMPDIR" > /dev/null || exit 1
  $ZIP -r -q "$ZIPFILE" ./*
  popd > /dev/null || exit 1
  echo "¡listo!"

  ZIPFILE="$DIRECTORIO_TRABAJO/$LOCALIZACION.xpi"
  echo -n "Creando $ZIPFILE "

  rm -f "$ZIPFILE" || exit 1
  pushd "$XPITMPDIR" > /dev/null || exit 1
  $ZIP -r -q "$ZIPFILE" ./*
  popd > /dev/null || exit 1
  echo "¡listo!"

  # Eliminar la carpeta temporal
  rm -Rf "$OXTTMPDIR" || exit 1
  rm -Rf "$XPITMPDIR" || exit 1
done

echo "Proceso finalizado."
