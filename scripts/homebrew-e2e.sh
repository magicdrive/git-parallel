#!/usr/bin/env bash
# Homebrew end-to-end test of the release packaging.
#
# Packages the working tree with Hephaestus exactly as the release workflow
# does (archive, checksum, formula) for the version the script reports,
# points the generated formula at the local archive (file:// url, same file
# name and sha256), then runs the real Homebrew in a throw-away tap:
# brew style, brew audit --strict, brew install, brew test, `git parallel`
# and the man page from the installed keg, and brew uninstall.
#
# It installs into the machine's Homebrew prefix and removes everything it
# created on exit. Intended for disposable CI runners and containers.
#
#   HEPHAESTUS=/path/to/hephaestus scripts/homebrew-e2e.sh
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "$0")/.." && pwd)"
heph="${HEPHAESTUS:?set HEPHAESTUS to a hephaestus executable}"
formula="git-parallel"
tap="git-parallel-e2e/t${RANDOM}${RANDOM}"

export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 \
  HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 \
  HOMEBREW_DEVELOPER=1 HOMEBREW_NO_ASK=1

cleanup() {
  set +e
  brew uninstall --force "${tap}/${formula}" >/dev/null 2>&1
  brew untap --force "${tap}" >/dev/null 2>&1
}
trap cleanup EXIT

step() { printf '\n==> %s\n' "$*"; }

# The version is embedded in the script (git-parallel --version); the
# release workflow refuses a tag that does not match it.
version="$(bash "${repo}/git-parallel" --version || true)"
version="${version#git-parallel v}"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || { echo "cannot read the version from git-parallel" >&2; exit 1; }
tag="v${version}"

step "Hephaestus: archive, checksum and formula for ${tag} (nothing is published)"
cd "${repo}"
env -u GITHUB_TOKEN -u GH_TOKEN -u HOMEBREW_TAP_GITHUB_TOKEN \
  "${heph}" run --stages archive,checksum,formula --tag "${tag}" --fresh
archive="dist/${formula}_${version}_noarch.tar.gz"
generated="dist/homebrew/${formula}.rb"

step "Archive layout"
listing="$(tar -tzvf "${archive}")"
echo "${listing}"
names="$(tar -tzf "${archive}" | sort | tr '\n' ' ')"
[[ "${names}" == "README.md git-parallel git-parallel.1 " ]] || { echo "unexpected archive contents: ${names}" >&2; exit 1; }
grep -Eq -- '^-rwxr-xr-x .* git-parallel$' <<<"${listing}"
grep -Eq -- '^-rw-r--r-- .* git-parallel\.1$' <<<"${listing}"
if command -v sha256sum >/dev/null; then
  (cd dist && sha256sum -c "${formula}_${version}_checksums.txt")
else
  (cd dist && shasum -a 256 -c "${formula}_${version}_checksums.txt")
fi

step "Generated formula"
cat "${generated}"
release_url="https://github.com/magicdrive/git-parallel/releases/download/${tag}/${formula}_${version}_noarch.tar.gz"
grep -qxF "  url \"${release_url}\"" "${generated}"
if grep -q 'on_macos\|on_linux' "${generated}"; then echo "noarch formula has per-OS blocks" >&2; exit 1; fi

step "Throw-away tap ${tap} with the formula pointing at the local archive"
brew tap-new --no-git "${tap}" >/dev/null
tapdir="$(brew --repository "${tap}")"
sed "s|  url \"${release_url}\"|  url \"file://${repo}/${archive}\"|" "${generated}" > "${tapdir}/Formula/${formula}.rb"
grep -q "file://" "${tapdir}/Formula/${formula}.rb"

step "brew style"
# Only the formula: `brew style <tap>` also lints the tap's generated
# workflows with actionlint.
brew style --formula "${tap}/${formula}"

step "brew audit --strict"
brew audit --strict --formula "${tap}/${formula}"

step "brew install"
brew install --formula "${tap}/${formula}"

step "brew test"
brew test "${tap}/${formula}"

step "Installed command, git subcommand and man page"
prefix="$(brew --prefix)"
out="$("${prefix}/bin/git-parallel" --version || true)"
[[ "${out}" == "git-parallel ${tag}" ]] || { echo "unexpected --version: ${out}" >&2; exit 1; }
out="$(PATH="${prefix}/bin:${PATH}" git parallel -V || true)"
[[ "${out}" == "git-parallel ${tag}" ]] || { echo "unexpected git parallel -V: ${out}" >&2; exit 1; }
[[ -f "$(brew --prefix "${tap}/${formula}")/share/man/man1/git-parallel.1" ]]
work="$(mktemp -d)"
git -C "${work}" init -q one && git -C "${work}" init -q two
out="$(cd "${work}" && PATH="${prefix}/bin:${PATH}" git parallel --jobs 2 -- status --short)"
rm -rf "${work}"
if ! grep -q '::: one' <<<"${out}" || ! grep -q '::: two' <<<"${out}"; then
  echo "unexpected git parallel output: ${out}" >&2; exit 1
fi

step "brew uninstall"
brew uninstall "${tap}/${formula}"
[[ ! -e "${prefix}/bin/git-parallel" ]]

echo
echo "Homebrew E2E passed for ${tag} on $(uname -s)/$(uname -m)"
