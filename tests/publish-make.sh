#!/usr/bin/env bash
# Tests for the make publish targets (Makefile, scripts/check-version.sh).
#
# The publish tool is replaced by a stub (PUBLISH=...) that records how it
# was called, so no git or GitHub access happens: argument handling, the
# version check that runs before the tool, make -n and make -j.
#
#   tests/publish-make.sh       (or: make test-publish)
#
# Bash 3.2 compatible (macOS /bin/bash with GNU Make 3.81).
set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/git-parallel-publish.XXXXXX")" && pwd)"
trap 'rm -rf "${work}"' EXIT

# A clean make environment: no MAKEFLAGS or jobserver from a parent
# `make check`, and no VERSION/YES/tag unless a case sets them.
unset MAKEFLAGS MFLAGS MAKELEVEL MAKEOVERRIDES VERSION YES tag \
  HEPHAESTUS_PUBLISH_ARGS HEPHAESTUS_PUBLISH_VERSION HEPHAESTUS_PUBLISH_TAG

log="${work}/calls"
stub="${work}/stub"
cat > "${stub}" <<EOF
#!/bin/sh
printf '%s|%s|%s|%s\n' "\$*" "\${HEPHAESTUS_PUBLISH_ARGS:-}" "\${HEPHAESTUS_PUBLISH_VERSION:-}" "\${HEPHAESTUS_PUBLISH_TAG:-}" >> "${log}"
EOF
chmod +x "${stub}"

# The version git-parallel reports: the only one make publish accepts.
cur="$(bash "${repo_root}/git-parallel" --version 2>&1 || true)"
cur="${cur#git-parallel }"
other="v99.0.0"
[[ "${cur}" != "${other}" ]] || { echo "git-parallel reports ${other}; pick another version" >&2; exit 2; }

passed=0 failed=0
out="" rc=0 calls=""

# mk [VAR=value ...] -- make arguments...: runs make in the repository with
# the stub and the given environment; sets out, rc and calls.
mk() {
  local env=()
  while [[ $# -gt 0 && "$1" != -- ]]; do env+=("$1"); shift; done
  shift
  rm -f "${log}"
  out="$(cd "${repo_root}" && env ${env[@]+"${env[@]}"} make --no-print-directory "PUBLISH=${stub}" "$@" 2>&1)"
  rc=$?
  calls="$(cat "${log}" 2>/dev/null || true)"
}

pass() { passed=$((passed + 1)); echo "ok   $1"; }
fail() { failed=$((failed + 1)); echo "FAIL $1"; printf '     rc=%s calls=[%s]\n' "${rc}" "${calls}"; printf '%s\n' "${out}" | sed 's/^/     | /'; }

# ok NAME WANT [VAR=value ...] -- ARGS: make succeeds and calls the tool
# exactly once, as WANT ("args|ARGS|VERSION|TAG").
ok() {
  local name="$1" want="$2"; shift 2
  mk "$@"
  if [[ "${rc}" -eq 0 && "${calls}" == "${want}" ]]; then pass "${name}"; else fail "${name} (want once: ${want})"; fi
}

# refused NAME [VAR=value ...] -- ARGS: make fails and never calls the tool.
refused() {
  local name="$1"; shift
  mk "$@"
  if [[ "${rc}" -ne 0 && -z "${calls}" ]]; then pass "${name}"; else fail "${name} (want failure, no call)"; fi
}

echo "git-parallel reports ${cur}"

ok "positional"              "publish -from-make|${cur}||" -- publish "${cur}"
ok "VERSION="                "publish -from-make||${cur}|" -- publish "VERSION=${cur}"
ok "tag= (compatible)"       "publish -from-make|||${cur}" -- publish "tag=${cur}"
ok "YES=1 on the command line" "publish -from-make -yes|${cur}||" -- publish "${cur}" YES=1
ok "YES other than 1 does not confirm" "publish -from-make|${cur}||" -- publish "${cur}" YES=yes
ok "YES and VERSION from the environment are ignored" "publish -from-make|${cur}||" YES=1 VERSION=v9.9.9 -- publish "${cur}"
ok "parallel make runs the tool once" "publish -from-make|${cur}||" -- -j4 publish "${cur}"
ok "check"                   "check -from-make|${cur}||" -- publish-check "${cur}"
ok "check with VERSION="     "check -from-make||${cur}|" -- publish-check "VERSION=${cur}"
ok "status (any version)"    "status -from-make|${other}||" -- publish-status "${other}"
ok "watch"                   "watch -from-make|${cur}||" -- publish-watch "${cur}"
ok "help"                    "help|||" -- publish-help

# The version check runs first: a tag the release workflow would refuse
# (the script reports another version) is never pushed.
refused "publish of a version the script does not report" -- publish "${other}"
refused "publish with tag= the script does not report" -- publish "tag=${other}"
# publish-check reports the preflight too, and still fails.
mk -- publish-check "${other}"
if [[ "${rc}" -ne 0 && "${calls}" == "check -from-make|${other}||" ]]; then
  pass "check of another version runs the preflight and fails"
else
  fail "check of another version runs the preflight and fails"
fi

refused "no version"                     -- publish
refused "check without a version"        -- publish-check
refused "two versions"                   -- publish "${cur}" v2.0.0
refused "a goal and VERSION="            -- publish "${cur}" "VERSION=${cur}"
refused "VERSION= and tag="              -- publish "VERSION=${cur}" "tag=${cur}"
refused "another target first"           -- lint publish "${cur}"
refused "two publish targets"            -- publish publish-check "${cur}"
refused "help takes no version"          -- publish-help "${cur}"
refused "a target as the version"        -- publish lint
refused "a word as the version"          -- publish clean
refused "no leading v"                   -- publish "${cur#v}"
refused "leading zero"                   -- publish v01.0.0
refused "build metadata"                 -- publish "${cur}+build.1"
refused "invalid version in check"       -- publish-check v1.x

# Shell metacharacters stay data: were the version pasted into a recipe,
# the shell would create the file. (No spaces: a space makes two goals.)
pwned="${work}/pwned"
case "${pwned}" in *[[:space:]]*) echo "TMPDIR must not contain spaces" >&2; exit 2;; esac
refused "metacharacters (;)"             -- publish "v1;:>${pwned}"
refused "metacharacters (\$())"          -- publish "v1.0.0\$(:>${pwned})"
refused "metacharacters in VERSION="     -- publish "VERSION=v1.0.0\`:>${pwned}\`"
# Without the version check in front, the value reaches the tool unchanged.
ok "metacharacters reach the tool as data" "status -from-make|v1;:>${pwned}||" -- publish-status "v1;:>${pwned}"
if [[ -e "${pwned}" ]]; then fail "metacharacters ran a command"; else pass "metacharacters ran no command"; fi

mk -- -n publish "${cur}"
if [[ "${rc}" -eq 0 && -z "${calls}" && "${out}" == *"publish -from-make"* ]]; then
  pass "make -n runs nothing"
else
  fail "make -n runs nothing"
fi

echo
echo "${passed} passed, ${failed} failed"
[[ "${failed}" -eq 0 ]]
