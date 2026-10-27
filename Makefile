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
SHELL_SOURCES := git-parallel tests/run.sh tests/publish-make.sh scripts/check-version.sh \
	scripts/homebrew-e2e.sh .github/renovate-check/run.sh

# renovate: datasource=go depName=github.com/magicdrive/hephaestus
HEPHAESTUS_VERSION ?= v1.3.0
HEPHAESTUS ?= go run github.com/magicdrive/hephaestus@$(HEPHAESTUS_VERSION)
# renovate: datasource=go depName=github.com/rhysd/actionlint
ACTIONLINT_VERSION ?= v1.7.12

.PHONY: all install uninstall help lint test test-publish check actionlint \
	renovate-check renovate-check-test hephaestus-check snapshot version-check preflight release-check \
	homebrew-e2e

help:
	@echo "make install|uninstall      install to / remove from PREFIX ($(PREFIX))"
	@echo "make lint                   shellcheck the scripts"
	@echo "make test [TEST_BASH=...]   run tests/run.sh with the given bash"
	@echo "make test-publish           test the make publish wiring (no git or GitHub access)"
	@echo "make check                  lint + test + test-publish"
	@echo "make actionlint             lint the GitHub Actions workflows"
	@echo "make renovate-check         validate renovate.json (Node.js of .github/renovate-check/.node-version)"
	@echo "make renovate-check-test    test renovate-check's pinned install (fake registry)"
	@echo "make hephaestus-check       validate hephaestus.yaml"
	@echo "make snapshot               build the release archive and checksum into dist/ (no tag)"
	@echo "make version-check tag=vX.Y.Z   the script's --version matches the tag"
	@echo "make preflight tag=vX.Y.Z   version-check + hephaestus preflight --strict before tagging"
	@echo "make release-check tag=vX.Y.Z   check + hephaestus-check + snapshot + preflight"
	@echo "make homebrew-e2e           package, then brew style/audit/install/test/uninstall (CI)"
	@echo "make publish vX.Y.Z         release: version check, preflight, confirm, tag, push, follow, verify"
	@echo "make publish-check vX.Y.Z   version check + release preflight only (read-only)"
	@echo "make publish-status vX.Y.Z  what exists for a version (read-only)"
	@echo "make publish-watch vX.Y.Z   follow the release run of an already pushed tag"
	@echo "make publish-help           how publishing works"

lint:
	$(SHELLCHECK) $(SHELL_SOURCES)

test:
	TEST_BASH=$(TEST_BASH) tests/run.sh

test-publish:
	tests/publish-make.sh

check: lint test test-publish

actionlint:
	go run github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)

# Renovate and its whole dependency tree are pinned by
# .github/renovate-check/package-lock.json and installed with `npm ci`, which
# Renovate updates (npm manager, lockFileMaintenance).
renovate-check:
	.github/renovate-check/run.sh

# The failure-injection tests of renovate-check's install (a fake registry:
# lockfile pinning, 404 and integrity failures)
renovate-check-test:
	python3 .github/renovate-check/test_run.py

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

# ---------------------------------------------------------------------------
# Release with Hephaestus (its docs/publish.md):
#   make publish v1.2.3          (or VERSION=v1.2.3, or tag=v1.2.3)
#   make publish-check v1.2.3    version check + preflight only
#   make publish-status v1.2.3   what exists for a version
#   make publish-watch v1.2.3    follow an already pushed tag
#   make publish-help
# The version given as a goal is a no-op goal (.DEFAULT). It reaches
# scripts/check-version.sh and hephaestus through the environment, never
# through a shell command line, and both validate it. YES=1 on the command
# line skips the prompt. The release workflow is the only publisher; publish
# only pushes the tag after its checks, then follows and verifies the run.
#
# The version is written in git-parallel (--version), so publish and
# publish-check first require it to be exactly the version being released:
# a tag the release workflow would refuse is never pushed.
PUBLISH ?= $(HEPHAESTUS) publish
VERSION_CHECK ?= scripts/check-version.sh
PUBLISH_TARGETS = publish publish-check publish-status publish-watch publish-help

ifneq ($(filter $(PUBLISH_TARGETS),$(MAKECMDGOALS)),)
PUBLISH_GOAL := $(firstword $(MAKECMDGOALS))
PUBLISH_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ifeq ($(filter $(PUBLISH_TARGETS),$(PUBLISH_GOAL)),)
$(error publish targets come first and alone: make publish v1.2.3)
endif
ifneq ($(filter $(PUBLISH_TARGETS),$(PUBLISH_ARGS)),)
$(error give one publish target at a time)
endif
ifneq ($(word 2,$(PUBLISH_ARGS)),)
$(error one version is expected, got: $(PUBLISH_ARGS))
endif
ifeq ($(PUBLISH_GOAL),publish-help)
ifneq ($(PUBLISH_ARGS),)
$(error publish-help takes no version)
endif
endif
export HEPHAESTUS_PUBLISH_ARGS := $(PUBLISH_ARGS)
export HEPHAESTUS_PUBLISH_VERSION := $(if $(filter command line,$(origin VERSION)),$(VERSION))
export HEPHAESTUS_PUBLISH_TAG := $(if $(filter command line,$(origin tag)),$(tag))
PUBLISH_YES := $(if $(and $(filter command line,$(origin YES)),$(filter 1,$(YES))),-yes)
ifneq ($(PUBLISH_ARGS),)
ifeq ($(filter v0% v1% v2% v3% v4% v5% v6% v7% v8% v9% 0% 1% 2% 3% 4% 5% 6% 7% 8% 9%,$(PUBLISH_ARGS)),)
$(error "$(PUBLISH_ARGS)" is not a version: make $(PUBLISH_GOAL) v1.2.3)
endif
# The version goal has no rule of its own: it is the publish target's
# argument. (No other target may start with v<digit>.)
.DEFAULT:
	@:
endif
endif

.PHONY: publish publish-check publish-status publish-watch publish-help
publish:
	@$(VERSION_CHECK) --from-make
	@$(PUBLISH) publish -from-make $(PUBLISH_YES)
# Reports both the version check and the preflight; an invalid or missing
# version (exit 2) stops before the preflight.
publish-check:
	@rc=0; $(VERSION_CHECK) --from-make || rc=$$?; \
	if [ "$$rc" -ge 2 ]; then exit "$$rc"; fi; \
	$(PUBLISH) check -from-make || exit $$?; \
	exit "$$rc"
publish-status:
	@$(PUBLISH) status -from-make
publish-watch:
	@$(PUBLISH) watch -from-make
publish-help:
	@$(PUBLISH) help
