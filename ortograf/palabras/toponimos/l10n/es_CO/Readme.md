# Topónimos Colombia

La presente inclusión de topónimos colombianos sigue como parámetros las especificaciones dadas en la página de la wiki [Topónimos en el diccionario](https://github.com/sbosio/rla-es/wiki/Topónimos-en-el-diccionario).  

## Fuente

La fuente de datos usada para la generación de los archivos (respectivas categorías y lemas) corresponde a la actualización del 30 de septiembre de 2015 de la [Codificación de la División Político-administrativa de Colombia (Divipola)](https://geoportal.dane.gov.co/v2/?page=elementoHistoricoDivipola), disponible en el Geoportal del DANE.  

La información se encuentra disponible para descarga como un archivo de excel, en el cual se clasifican los entes territoriales y se listan agrupados según pertenencia a un ente de mayor orden.  

## Generación

A continuación se describe la metodología seguida para la generación de los archivos. Esto ayudará al futuro mantenimiento de estos.  

### Lista de topónimos (compuestos)

Una vez se realiza la descarga del archivo, es necesario convertirlo a un archivo de texto plano (en este caso CSV para facilitar la extracción de datos).  

    soffice --convert-to csv --infilter=CSV:44,34,76,1 Listado_2015.xls

Hay que tener en cuenta que las dos primeras filas y las dos últimas filas del archivo no corresponden a información de interés para la generación del diccionario (cabeceras de las columnas y fecha de actualización). De esta manera procedemos a removerlas.  

    tail -n +3 Listado_2015.csv | head -n -2 > sin_cabeceras.csv

El delimitador `","` es usado para la separación de las columnas de este archivo. Como la instrucción `cut` solo admite delimitadores de un cáracter y los campos no poseen `,` podemos convertir sin problema `","` en `,`.  

    sed -i 's/","/,/g' sin_cabeceras.csv

Las categorías de entes territoriales en Colombia se corresponden a _Departamentos_, _Municipios_ y _Centros poblados_, que en el archivo se ubican en las columnas 4 a 6 respectivamente. Los datos sobre las columnas se encuentran repetidos por coincidencia en nombre de los entes territoriales (Municipios y Centros poblados) pero también por ser entes de mayor jerarquía (Departamentos y Municipios). Se requiere no solo extraer sino ordenar y eliminar repetidos.  

    cut -d ',' -f 4 archivo_entrada.csv | sort -u > archivo_salida.txt

El procedimiento se realiza para los 3 archivos cambiando el valor del campo (número al lado de `-f` según el orden del ente que corresponda).  

## Lista de lemas (descompuestos)

Los topónimos pueden ser nombres compuestos y contener entre sus partes números cardinales. Además, en los listados oficiales pueden tener símbolos aclaratorios adicionales (en el listado de Colombia aparecen guiones y paréntesis) que no hacen parte de los lemas.  

Se hace así necesario remover estos elementos no deseados de nuestras listas, descomponer los topónimos y nuevamente ordenar conservando elementos únicos.  

    sed -i -E \
     -e 's/([[:punct:]]|[[:digit:]])+//g' \
     -e 's/ +/\n/g' archivo_compuesto.txt
    sort -u | sed '/^$/d' archivo_compuesto.txt > archivo_descompuesto.txt

Ahora, es necesario que los lemas estén con la convención de sustantivos propios (mayúscula inicial y el resto minúscula).  

     cat archivo_descompuesto | tr "[[:upper:]]" "[[:lower:]]" | tr "ÁÉÍÓÚÜÑ" "áéíóúüñ" > toponimos.txt
     sed -i 's/^\(.\)/\u\1/g' toponimos.txt

Es posible remover algunas palabras comúnes acorde a las reglas especificadas  con la siguiente linea:  

      sed -i -E '/^(De|Del|Ciudad|Y)$/d' archivo_descompuesto.txt
