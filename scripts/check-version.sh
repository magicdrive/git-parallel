#!/usr/bin/env bash
# Usage: scripts/check-version.sh vX.Y.Z
#        scripts/check-version.sh --from-make
#
# The version is written into git-parallel (git::parallel::version, printed
# by --version / -V) and is not generated at release time. This check fails
# unless the script reports exactly the tag being released, so a release
# cannot ship a script that prints another version. The release workflow
# runs it before anything is packaged; make publish and make publish-check
# run it before the tag is pushed (make version-check and make preflight
# too).
#
# --from-make reads the version the publish targets of the Makefile export
# (HEPHAESTUS_PUBLISH_ARGS, _VERSION or _TAG; exactly one must be set), so
# the version never passes through a shell command line.
#
# Exit status: 0 the script reports the tag, 1 it reports another version,
# 2 usage (no version, more than one, or not a vMAJOR.MINOR.PATCH[-PRE] tag).
set -euo pipefail

usage() { echo "usage: $0 vX.Y.Z | --from-make" >&2; exit 2; }

[[ $# -eq 1 ]] || usage
if [[ "$1" == --from-make ]]; then
  tag="" given=0
  for name in HEPHAESTUS_PUBLISH_ARGS HEPHAESTUS_PUBLISH_VERSION HEPHAESTUS_PUBLISH_TAG; do
    if [[ -n "${!name:-}" ]]; then
      tag="${!name}"
      given=$((given + 1))
    fi
  done
  if [[ "${given}" -ne 1 ]]; then
    echo "error: give exactly one version: make publish vX.Y.Z (or VERSION=vX.Y.Z, or tag=vX.Y.Z)" >&2
    exit 2
  fi
else
  tag="$1"
fi

# A SemVer 2.0.0 version with a leading v and no build metadata, as
# hephaestus publish requires.
num='(0|[1-9][0-9]*)'
pre='(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
if [[ ! "${tag}" =~ ^v${num}\.${num}\.${num}(-${pre}(\.${pre})*)?$ ]]; then
  echo "error: \"${tag}\" is not a vMAJOR.MINOR.PATCH[-PRERELEASE] tag" >&2
  exit 2
fi

script="$(cd "$(dirname "$0")/.." && pwd)/git-parallel"
# --version exits 1 (historical behavior); only the output matters here.
actual="$(bash "${script}" --version 2>&1 || true)"
if [[ "${actual}" != "git-parallel ${tag}" ]]; then
  echo "error: git-parallel --version prints \"${actual}\", expected \"git-parallel ${tag}\"." >&2
  echo "Update git::parallel::version in git-parallel before tagging ${tag}." >&2
  exit 1
fi
echo "git-parallel --version matches ${tag}"
