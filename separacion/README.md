# RLA-ES Separación silábica

Este directorio posee los archivos correspondiente a la funcionalidad de
separación silábica del diccionario corrector.

Los ficheros que integran los patrones de separación silábica han sido
preparados para funcionar con la herramienta
[_Hyphen_](https://github.com/hunspell/hyphen), que utiliza una versión
modificada de los patrones para el [sistema de separación silábica
utilizado por _TeX_](http://www.tug.org/docs/liang/).

La biblioteca _Hyphen_ posee características avanzadas para dar soporte 
a la separación silábica de palabras compuestas y reglas no estándares,
además de admitir codificaciones de caracteres multibyte como _UTF-8_.

El listado de patrones de separación silábica ha sido generado por
Santiago Bosio, utilizando la herramienta
[_patgen_](https://linux.die.net/man/1/patgen), escrita inicialmente
por Frank Liang y basada en el algoritmo de Donald Knuth.

La herramienta __patgen__ produce un listado de patrones con el formato
_Tex_,  procesando el fichero
[_entrenamiento.txt_](https://github.com/sbosio/rla-es/blob/master/separacion/entrenamiento.txt),
que contiene más de 8.000 lemas elegidos al azar del listado de palabras
del diccionario, y que han sido separados manualmente en sílabas, intentando
respetar las reglas y recomendaciones indicadas en el apartado referido a la
[utilización del guion como signo de división de palabras](http://lema.rae.es/dpd/srv/search?id=cvqPbpreSD6esL3ahc)
del Diccionario Panhispánico de Dudas.

Finalmente, el listado en formato _Tex_ se procesa con la herramienta
[_substrings.pl_](https://github.com/hunspell/hyphen/blob/master/substrings.pl)
para producir el fichero con el formato correcto para _Hyphen_.

Puede obtener más información sobre diccionarios de separación silábica
consultando
[este enlace](http://localization-guide.readthedocs.org/en/latest/guide/hyphenation.html).
