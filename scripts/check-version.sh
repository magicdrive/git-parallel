#!/usr/bin/env bash
# Usage: scripts/check-version.sh vX.Y.Z
#
# The version is written into git-parallel (git::parallel::version, printed
# by --version / -V) and is not generated at release time. This check fails
# unless the script reports exactly the tag being released, so a release
# cannot ship a script that prints another version. The release workflow
# runs it before anything is packaged; make preflight runs it before tagging.
set -euo pipefail

tag="${1:?usage: $0 vX.Y.Z}"
if [[ ! "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "error: ${tag} is not a vMAJOR.MINOR.PATCH[-PRERELEASE] tag" >&2
  exit 1
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
