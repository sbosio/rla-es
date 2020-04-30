# -*- Mode: makefile-gmake; tab-width: 4; indent-tabs-mode: t -*-
#
# This file is part of the LibreOffice project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

$(eval $(call gb_Dictionary_Dictionary,dict-__LOCALE__,dictionaries/__LOCALE__))

$(eval $(call gb_Dictionary_add_root_files,dict-__LOCALE__,\
	dictionaries/__LOCALE__/__LOCALE__.aff \
	dictionaries/__LOCALE__/__LOCALE__.dic \
	dictionaries/__LOCALE__/hyph_es.dic \
	dictionaries/__LOCALE__/package-description.txt \
	dictionaries/__LOCALE__/README.txt \
	dictionaries/__LOCALE__/README_hyph_es.txt \
	dictionaries/__LOCALE__/README_th_es.txt \
	dictionaries/__LOCALE__/__ICON__ \
	dictionaries/__LOCALE__/LICENSE.md \
))

$(eval $(call gb_Dictionary_add_thesauri,dict-__LOCALE__,\
	dictionaries/__LOCALE__/th_es_v2.dat \
))

# vim: set noet sw=4 ts=4:
