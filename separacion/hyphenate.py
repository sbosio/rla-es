#!python3
# Actualización 2024-12-27 por Edward Villegas (cosmoscalibur)
# - ISO 8859-1 a UTF-8
# - Python2 a Python3
# - doctest con casos para `hyph_es`.

""" Hyphenation, using Frank Liang's algorithm.

    This module provides a single function to hyphenate words.  hyphenate_word takes
    a string (the word), and returns a list of parts that can be separated by hyphens.

    # Ejemplos adaptados al español por @cosmoscalibur
    >>> hyphenate_word("desayuno") #196
    ['de', 'sa', 'yuno']
    >>> hyphenate_word("submarino")
    ['sub', 'ma', 'rino']
    >>> hyphenate_word("maíz")
    ['maíz']
    >>> hyphenate_word("aeropuerto")
    ['ae', 'ro', 'puer', 'to']
    >>> hyphenate_word("aéreo") #270
    ['aé', 'reo']
    >>> hyphenate_word("disputa") #264
    ['dispu', 'ta']
    >>> hyphenate_word("espectáculo") #264
    ['es', 'pec', 'tácu', 'lo']

    Ned Batchelder, July 2007.
    This Python code is in the public domain.
"""

import re

__version__ = '1.0.20070709'

class Hyphenator:
    def __init__(self, patterns, exceptions=''):
        self.tree = {}
        for pattern in patterns.split():
            self._insert_pattern(pattern)

        self.exceptions = {}
        for ex in exceptions.split():
            # Convert the hyphenated pattern into a point array for use later.
            self.exceptions[ex.replace('-', '')] = [0] + [ int(h == '-') for h in re.split(r"[a-z]", ex) ]

    def _insert_pattern(self, pattern):
        # Convert the a pattern like 'a1bc3d4' into a string of chars 'abcd'
        # and a list of points [ 0, 1, 0, 3, 4 ].
        chars = re.sub('[0-9]', '', pattern)
        points = [ int(d or 0) for d in re.split("[.a-záéíóúüñ]", pattern) ]

        # Insert the pattern into the tree.  Each character finds a dict
        # another level down in the tree, and leaf nodes have the list of
        # points.
        t = self.tree
        for c in chars:
            if c not in t:
                t[c] = {}
            t = t[c]
        t[None] = points

    def hyphenate_word(self, word):
        """ Dada una palabra, devuelve una lista de trozos, separados en los posibles
            puntos de silabeo
        """
        # Short words aren't hyphenated.
        if len(word) <= 4:
            return [word]
        # If the word is an exception, get the stored points.
        if word.lower() in self.exceptions:
            points = self.exceptions[word.lower()]
        else:
            work = '.' + word.lower() + '.'
            points = [0] * (len(work)+1)
            for i in range(len(work)):
                t = self.tree
                for c in work[i:]:
                    if c in t:
                        t = t[c]
                        if None in t:
                            p = t[None]
                            for j in range(len(p)):
                                points[i+j] = max(points[i+j], p[j])
                    else:
                        break
            # No hyphens in the first two chars or the last two.
            points[1] = points[2] = points[-2] = points[-3] = 0

        # Examine the points to build the pieces list.
        pieces = ['']
        for c, p in zip(word, points[2:]):
            pieces[-1] += c
            if p % 2:
                pieces.append('')
        return pieces

with open('hyph_es_test.dic') as patternfile:
    # sed '/^%/d' hyph_es.dic | tr '\n' ' ' | sed 's/UTF-8 LEFTHYPHENMIN 2 RIGHTHYPHENMIN 2 //g' > hyph_es_test.dic
    patterns=(patternfile.read())

exceptions = """
"""

hyphenator = Hyphenator(patterns, exceptions)
hyphenate_word = hyphenator.hyphenate_word

del patterns
del exceptions

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        for word in sys.argv[1:]:
            print('-'.join(hyphenate_word(word)))
    else:
        import doctest
        doctest.testmod(verbose=True)
