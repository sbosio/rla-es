#!/usr/bin/bash

# Se usa como fuente los patrones para patgen de tex-hyphen-spanish
wget https://raw.githubusercontent.com/jbezos/tex-hyphen-spanish/refs/heads/master/tex/hyph-es.tex
# Se hace uso de `substrings.pl` de Hunspell para convertir a Libhnj
wget https://raw.githubusercontent.com/hunspell/hyphen/refs/heads/master/substrings.pl
perl substrings.pl hyph-es.tex hyph_es.dic
# Ajustes a `hyph_es.dic`
sed -i -e '/^}/d' -e '1s/^/UTF-8\nLEFTHYPHENMIN 2\nRIGHTHYPHENMIN 2\n/' hyph_es.dic
# Se remueven fuentes externas
rm hyph-es.tex substrings.pl
# Tests
sed '/^%/d' hyph_es.dic | tr '\n' ' ' | sed 's/UTF-8 LEFTHYPHENMIN 2 RIGHTHYPHENMIN 2 //g' > hyph_es_test.dic
python hyphenate.py
rm hyph_es_test.dic
