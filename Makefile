PREFIX=${HOME}/local
CURRENTDIR=$(shell pwd -L | perl -p -e 's/ /\\ /g')

all:
	@echo "make [intall|uninstall]"

install:
	mkdir -p $(PREFIX)/bin/ $(PREFIX)/share/man/man1/
	cp -af $(CURRENTDIR)/git-parallel $(PREFIX)/bin/
	cp -af $(CURRENTDIR)/git-parallel.1 $(PREFIX)/share/man/man1/

uninstall:
	rm -f $(PREFIX)/bin/git-parallel
	rm -f  $(PREFIX)/share/man/man1/git-parallel.1


# ---------------------------------------------------------------------------
# Development and release checks. `make help` lists them. The targets above
# (all, install, uninstall) are unchanged.

# Bash used to run the tests; TEST_BASH=/bin/bash checks macOS's bash 3.2.
TEST_BASH ?= bash
SHELLCHECK ?= shellcheck
SHELL_SOURCES := git-parallel tests/run.sh scripts/check-version.sh scripts/homebrew-e2e.sh

# renovate: datasource=go depName=github.com/magicdrive/hephaestus
HEPHAESTUS_VERSION ?= v1.1.0
HEPHAESTUS ?= go run github.com/magicdrive/hephaestus@$(HEPHAESTUS_VERSION)
# renovate: datasource=go depName=github.com/rhysd/actionlint
ACTIONLINT_VERSION ?= v1.7.12
# renovate: datasource=npm depName=renovate
RENOVATE_VERSION ?= 44.149.0

.PHONY: all install uninstall help lint test check actionlint renovate-check \
	hephaestus-check snapshot version-check preflight release-check homebrew-e2e

help:
	@echo "make install|uninstall      install to / remove from PREFIX ($(PREFIX))"
	@echo "make lint                   shellcheck the scripts"
	@echo "make test [TEST_BASH=...]   run tests/run.sh with the given bash"
	@echo "make check                  lint + test"
	@echo "make actionlint             lint the GitHub Actions workflows"
	@echo "make renovate-check         validate renovate.json (needs npx)"
	@echo "make hephaestus-check       validate hephaestus.yaml"
	@echo "make snapshot               build the release archive and checksum into dist/ (no tag)"
	@echo "make version-check tag=vX.Y.Z   the script's --version matches the tag"
	@echo "make preflight tag=vX.Y.Z   version-check + hephaestus preflight --strict before tagging"
	@echo "make release-check tag=vX.Y.Z   check + hephaestus-check + snapshot + preflight"
	@echo "make homebrew-e2e           package, then brew style/audit/install/test/uninstall (CI)"

lint:
	$(SHELLCHECK) $(SHELL_SOURCES)

test:
	TEST_BASH=$(TEST_BASH) tests/run.sh

check: lint test

actionlint:
	go run github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)

renovate-check:
	npx --yes --package renovate@$(RENOVATE_VERSION) -- renovate-config-validator --strict renovate.json

hephaestus-check:
	$(HEPHAESTUS) check

# git-parallel is a script: there is no build stage, only the noarch archive.
snapshot:
	$(HEPHAESTUS) run --snapshot --stages archive,checksum --fresh

version-check:
	@test -n "$(tag)" || { echo "usage: make $@ tag=vX.Y.Z" >&2; exit 2; }
	scripts/check-version.sh "$(tag)"

preflight: version-check
	$(HEPHAESTUS) preflight --tag "$(tag)" --strict

release-check: check hephaestus-check snapshot preflight

# Installs into the machine's Homebrew prefix (removed again on exit): meant
# for CI runners and containers.
homebrew-e2e:
	GOBIN="$(CURDIR)/dist/.bin" go install github.com/magicdrive/hephaestus@$(HEPHAESTUS_VERSION)
	HEPHAESTUS="$(CURDIR)/dist/.bin/hephaestus" scripts/homebrew-e2e.sh
