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

El listado de patrones de separación silábica fue generado inicialmente por
Santiago Bosio, utilizando la herramienta
[_patgen_](https://linux.die.net/man/1/patgen), escrita inicialmente
por Frank Liang y basada en el algoritmo de Donald Knuth. A partir del
2024-12-27, se genera a partir de los patrones del proyecto
[tex-hyphen-spanish](https://github.com/jbezos/tex-hyphen-spanish/blob/master/tex/hyph-es.tex).

Finalmente, el listado en formato _Tex_ se procesa con la herramienta
[_substrings.pl_](https://github.com/hunspell/hyphen/blob/master/substrings.pl)
para producir el fichero con el formato correcto para _Hyphen_.

Para actualizar los patrones desde el proyecto "tex-hyphen-spanish", ejecute:

```
source build_hyph_dic.sh
```

Puede obtener más información sobre diccionarios de separación silábica
consultando
[este enlace](https://localization-guide.readthedocs.org/en/latest/guide/hyphenation.html).
