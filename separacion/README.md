# RLA-ES Separación silábica

Este directorio posee los archivos correspondiente a la funcionalidad de
separación silábica del diccionario corrector.

La separación silábica es compatible con el [sistema de separación silábica
_TeX_](http://www.tug.org/docs/liang/), creado por Frank Liang, admitido por
Apache OpenOffice y LibreOffice.

El diccionario de separación silábica ha sido generado por Santiago Bosio,
utilizando el algoritmo de Donald Knuth.

Más información sobre diccionarios de separación silábica en el
[enlace](http://localization-guide.readthedocs.org/en/latest/guide/hyphenation.html)

## Archivos

* `entrenamiento.txt` contiene más de 8.000 palabras elegidas al azar del
  listado de palabras del diccionario, separadas manualmente de acuerdo con
  las recomendaciones más actualizadas de la RAE.

* `hyph_es_ANY.dic` es el diccionario compatible con el sistema de separación
  silábica _TeX_.

* `README_hyph_es_ANY.txt` contiene el instructivo de uso que es incluido en los
  paquetes de los diccionarios.

## Mantenimiento

En el año 2015 se ha migrado todo el diccionario a la codificación UTF-8.
Por tener certeza del correcto funcionamiento del diccionario de separación
silábica codificado en UTF-8, tal como se ha dejado constancia en el
[_issue_ #49](https://github.com/sbosio/rla-es/issues/49), se decidió mantener
la codificación ISO8859-1 mientras no haya necesidad de actualizarla.
