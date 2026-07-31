# RefXChange — convenience wrapper around install.sh and the test suite.

PREFIX ?= $(HOME)/.local
SHELL  := /bin/bash

.PHONY: help install link uninstall test lint i18n

help:
	@echo "make install    install to $(PREFIX)/bin (override with PREFIX=...)"
	@echo "make link       symlink to this checkout (development install)"
	@echo "make uninstall  remove it from $(PREFIX)"
	@echo "make test       run the smoke tests"
	@echo "make lint       shellcheck every script"
	@echo "make i18n       regenerate locale/refxchange.pot from the sources"

install:
	@./install.sh --prefix "$(PREFIX)"

link:
	@./install.sh --prefix "$(PREFIX)" --link

uninstall:
	@./install.sh --prefix "$(PREFIX)" --uninstall

test:
	@bash tests/run_tests.sh

lint:
	@shellcheck refxchange.sh install.sh lib/*.sh tests/*.sh

i18n:
	@xgettext --language=Shell --keyword=_ --from-code=UTF-8 \
		--package-name=refxchange --package-version=0.1.0 \
		-o locale/refxchange.pot refxchange.sh lib/*.sh
	@echo "wrote locale/refxchange.pot"
