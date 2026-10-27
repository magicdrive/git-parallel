#!/usr/bin/env bash
# Tests for git-parallel.
#
# Every test builds its own tree of throw-away git repositories under a
# temporary directory and runs git-parallel against it with the bash given in
# TEST_BASH (default: the first bash on PATH), so the suite can check bash 3.2
# (macOS /bin/bash) and bash 5 alike:
#
#   tests/run.sh                       # bash on PATH
#   TEST_BASH=/bin/bash tests/run.sh   # a specific bash
#
# The suite itself stays bash 3.2 compatible. Nothing outside the temporary
# directory is touched; git runs with HOME pointed into it and no system or
# global configuration.
set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
GP="${repo_root}/git-parallel"
TEST_BASH="${TEST_BASH:-bash}"
TEST_BASH="$(command -v "${TEST_BASH}")" || { echo "bash not found: ${TEST_BASH:-bash}" >&2; exit 2; }

# cd + pwd: the same spelling git-parallel prints (no "//" from a TMPDIR
# that ends in a slash).
work="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/git-parallel-test.XXXXXX")" && pwd)"
trap 'rm -rf "${work}"' EXIT

export HOME="${work}/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com \
  GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com \
  LC_ALL=C
mkdir -p "${HOME}"
# Defaults come from the environment; the tests must not inherit a user's.
unset GIT_PARALLEL_DEAULT_COLOR_MODE GIT_PARALLEL_DEAULT_SILENT_MODE \
  GIT_PARALLEL_DEAULT_JOBS GIT_PARALLEL_DEAULT_MAXDEPTH GIT_PARALLEL_DEAULT_START_DIR

passed=0 failed=0 current=""
out="" err="" rc=0

fail() {
  echo "  FAIL: $*"
  echo "    exit: ${rc}"
  echo "    stdout:"; printf '%s\n' "${out}" | sed 's/^/      | /'
  echo "    stderr:"; printf '%s\n' "${err}" | sed 's/^/      | /'
  failed=$((failed + 1))
  return 1
}

# run DIR ARGS...: run git-parallel in DIR; sets out, err and rc.
run() {
  local dir="$1"; shift
  out="$(cd "${dir}" && "${TEST_BASH}" "${GP}" "$@" 2>"${work}/stderr")"
  rc=$?
  err="$(cat "${work}/stderr")"
}

expect_rc() { [[ "${rc}" == "$1" ]] || fail "${current}: exit ${rc}, want $1"; }
expect_out() { [[ "${out}" == *"$1"* ]] || fail "${current}: stdout lacks: $1"; }
expect_no_out() { [[ "${out}" != *"$1"* ]] || fail "${current}: stdout has: $1"; }
expect_err() { [[ "${err}" == *"$1"* ]] || fail "${current}: stderr lacks: $1"; }
expect_eq() { [[ "$1" == "$2" ]] || fail "${current}: got [$1], want [$2]"; }

# new_tree NAME REPO...: a fresh directory with one git repository per
# (relative) path; each repository has one commit.
new_tree() {
  local root="${work}/$1" r; shift
  rm -rf "${root}"; mkdir -p "${root}"
  for r in "$@"; do
    mkdir -p "${root}/${r}"
    git -C "${root}/${r}" init -q
    echo "${r}" > "${root}/${r}/name.txt"
    git -C "${root}/${r}" add name.txt
    git -C "${root}/${r}" commit -q -m "init ${r}"
  done
  tree="${root}"
}

t() {
  current="$1"
  echo "- $1"
  local before="${failed}"
  "$2"
  [[ "${failed}" == "${before}" ]] && passed=$((passed + 1))
  return 0
}

test_version() {
  local version
  version="$(sed -n 's/^ *echo "git-parallel \(v[0-9][0-9.]*\)"$/\1/p' "${GP}")"
  [[ -n "${version}" ]] || { fail "version string not found in git-parallel"; return; }
  run "${work}" --version
  # --version, --help and --list exit 1 (historical behavior, kept).
  expect_rc 1
  expect_eq "${out}" "git-parallel ${version}"
  run "${work}" -V
  expect_rc 1
  expect_eq "${out}" "git-parallel ${version}"
}

test_help() {
  run "${work}" --help
  expect_rc 1
  expect_err "USAGE:"
  expect_err "--maxdepth"
  run "${work}" -h
  expect_rc 1
  expect_err "USAGE:"
  run "${work}"
  expect_rc 1
  expect_err "USAGE:"
  run "${work}" --jobs 2 --
  expect_rc 1
  expect_err "USAGE:"
}

test_unknown_options() {
  run "${work}" --no-such-option
  expect_rc 1
  expect_err "Unknown option --no-such-option"
  run "${work}" status
  expect_rc 1
  expect_err "Unknown option status"
  run "${work}" --jobs abc -- status
  expect_rc 1
  expect_err "Unknown option --jobs abc"
  run "${work}" -j x -- status
  expect_rc 1
  expect_err "Unknown option -j x"
  run "${work}" --maxdepth deep -- status
  expect_rc 1
  expect_err "Unknown option --maxdepth deep"
  run "${work}" --color sometimes -- status
  expect_rc 1
  expect_err "Unknown option --color sometimes"
}

test_list() {
  new_tree list alpha beta "nested/gamma" delta
  mkdir -p "${tree}/plain-dir" "${tree}/not a repo"
  run "${tree}" --list
  expect_rc 1
  local got want
  got="$(printf '%s\n' "${out}" | sort)"
  want="$(printf '%s\n' "${tree}/alpha" "${tree}/beta" "${tree}/delta" "${tree}/nested/gamma" | sort)"
  expect_eq "${got}" "${want}"
  run "${tree}" -l
  expect_rc 1
  expect_eq "$(printf '%s\n' "${out}" | sort)" "${want}"
}

test_maxdepth() {
  new_tree depth top "one/two" "one/two/three/four"
  # .git of "top" is at depth 2, of "one/two" at depth 3. Options are
  # applied in order, so --maxdepth must come before --list.
  run "${tree}" --maxdepth 2 --list
  expect_eq "${out}" "${tree}/top"
  run "${tree}" -m 3 -l
  expect_eq "$(printf '%s\n' "${out}" | sort)" "$(printf '%s\n' "${tree}/one/two" "${tree}/top" | sort)"
  run "${tree}" --maxdepth 2 -- ::: pwd
  expect_rc 0
  expect_out "${tree}/top"
  expect_no_out "${tree}/one/two"
}

test_targets() {
  new_tree targets r1 r2
  # -d, --target and --targets (as the help spells it) select the start
  # directory instead of the current one.
  run "${work}" -d "${tree}" --list
  expect_eq "$(printf '%s\n' "${out}" | sort)" "$(printf '%s\n' "${tree}/r1" "${tree}/r2")"
  run "${work}" --target "${tree}" --list
  expect_eq "$(printf '%s\n' "${out}" | sort)" "$(printf '%s\n' "${tree}/r1" "${tree}/r2")"
  run "${work}" --targets "${tree}" --list
  expect_eq "$(printf '%s\n' "${out}" | sort)" "$(printf '%s\n' "${tree}/r1" "${tree}/r2")"
  run "${work}" --targets "${tree}" -- rev-parse --abbrev-ref HEAD
  expect_rc 0
  expect_out "::: r1"
  expect_out "::: r2"
}

test_git_command() {
  new_tree gitcmd r1 r2 r3
  run "${tree}" -- log --format=%s
  expect_rc 0
  expect_out "start parallel: log --format=%s"
  local r
  for r in r1 r2 r3; do
    expect_out "result git log --format=%s ::: ${r}"
    expect_out "init ${r}"
  done
  # A leading "git" is accepted and not doubled.
  run "${tree}" -- git rev-parse --is-inside-work-tree
  expect_rc 0
  expect_out "result rev-parse --is-inside-work-tree ::: r1"
  expect_out "true"
  expect_no_out "git git"
}

test_bare_command() {
  new_tree bare r1 r2
  run "${tree}" -- ::: cat name.txt
  expect_rc 0
  expect_out "result cat name.txt ::: r1"
  expect_out "result cat name.txt ::: r2"
  # Each command runs inside its repository.
  run "${tree}" -j 1 -- ::: pwd
  expect_out "${tree}/r1"
  expect_out "${tree}/r2"
}

test_output_order() {
  # Output of each repository is printed as one block, in list order,
  # whatever order the jobs finish in.
  new_tree order r1 r2 r3 r4
  run "${tree}" --list
  local expected="" r
  while IFS= read -r r; do
    expected="${expected}$(basename "${r}") "
  done <<<"${out}"
  run "${tree}" --jobs 4 -- ::: cat name.txt
  local got
  got="$(printf '%s\n' "${out}" | sed -n 's/^result cat name.txt ::: //p' | tr '\n' ' ')"
  expect_eq "${got}" "${expected}"
}

test_paths_with_spaces() {
  new_tree "space root" "with space" "plain" "deep dir/inner repo"
  run "${tree}" --list
  expect_eq "$(printf '%s\n' "${out}" | sort)" \
    "$(printf '%s\n' "${tree}/deep dir/inner repo" "${tree}/plain" "${tree}/with space" | sort)"
  run "${tree}" -- log --format=%s
  expect_rc 0
  expect_out "::: with space"
  expect_out "init with space"
  expect_out "::: inner repo"
  expect_out "init deep dir/inner repo"
  run "${tree}" -- ::: pwd
  expect_out "${tree}/with space"
  run "${work}" --targets "${tree}" -- ::: cat name.txt
  expect_out "deep dir/inner repo"
}

test_argument_quoting() {
  new_tree quoting r1
  # The command is joined into one string and split again on white space
  # (historical behavior): quoting inside an argument is not preserved, and
  # a command given as a single quoted argument works the same as separate
  # words.
  run "${tree}" -- "log --format=%s"
  expect_rc 0
  expect_out "init r1"
  run "${tree}" -- ::: printf '<%s>' "a b" c
  expect_out "<a><b><c>"
  run "${tree}" -- "::: printf <%s> x y"
  expect_out "<x><y>"
  # Shell metacharacters are passed as plain words, never evaluated.
  # shellcheck disable=SC2016
  run "${tree}" -- ::: echo '$(touch pwned)' ';' 'touch pwned2'
  expect_rc 0
  [[ ! -e "${tree}/r1/pwned" && ! -e "${tree}/r1/pwned2" && ! -e "${tree}/pwned" ]] \
    || fail "${current}: command text was evaluated by a shell"
  # shellcheck disable=SC2016
  expect_out '$(touch pwned) ; touch pwned2'
}

test_error_propagation() {
  new_tree errors good1 bad good2
  rm -f "${tree}/bad/name.txt"
  # A failing command in one repository does not stop the others; its
  # error output (stderr) is shown in that repository's block.
  run "${tree}" --jobs 2 -- ::: cat name.txt
  expect_out "::: bad"
  expect_out "name.txt: No such file or directory"
  expect_out "good1"
  expect_out "good2"
  # Historical behavior, kept for compatibility: the exit status is 0 even
  # when the command fails in some or all repositories.
  expect_rc 0
  run "${tree}" -- rev-parse --verify no-such-ref
  expect_rc 0
  expect_out "fatal: Needed a single revision"
  # A command that is not found is reported, not fatal.
  run "${tree}" -- ::: git-parallel-no-such-command
  expect_rc 0
  expect_out "::: good1"
}

test_parallel_jobs() {
  # Four jobs wait at a barrier until all four have started: only true
  # parallelism with --jobs 4 gets them through. With --jobs 1 they run one
  # at a time and each gives up after its timeout.
  new_tree parallel p1 p2 p3 p4
  local barrier="${work}/barrier"
  cat > "${work}/barrier.sh" <<EOF
#!/bin/sh
mkdir -p "${barrier}"
touch "${barrier}/\$(basename "\$PWD")"
i=0
while [ "\$(ls "${barrier}" | wc -l | tr -d ' ')" -lt "\$1" ]; do
  i=\$((i + 1))
  if [ "\$i" -gt \$2 ]; then echo "barrier-timeout"; exit 1; fi
  sleep 0.1
done
echo "barrier-passed"
EOF
  rm -rf "${barrier}"
  run "${tree}" --jobs 4 -- ::: sh "${work}/barrier.sh" 4 300
  expect_rc 0
  [[ "$(grep -c barrier-passed <<<"${out}")" == 4 ]] || fail "${current}: --jobs 4 did not run 4 jobs at once"
  rm -rf "${barrier}"
  run "${tree}" -j 1 -- ::: sh "${work}/barrier.sh" 2 3
  expect_rc 0
  expect_out "barrier-timeout"
  # More repositories than jobs: every repository is still processed.
  new_tree batches b1 b2 b3 b4 b5
  run "${tree}" --jobs 2 -- ::: cat name.txt
  local r
  for r in b1 b2 b3 b4 b5; do expect_out "::: ${r}"; done
  [[ "$(grep -c '^result ' <<<"${out}")" == 5 ]] || fail "${current}: expected 5 result blocks"
}

test_jobs_zero() {
  new_tree zero r1
  # Zero jobs used to loop forever (GNU seq 0 prints nothing).
  run "${tree}" --jobs 0 -- status
  expect_rc 1
  expect_err "Invalid job count: 0"
  out="$(cd "${tree}" && GIT_PARALLEL_DEAULT_JOBS=x "${TEST_BASH}" "${GP}" -- status 2>&1)"; rc=$?
  expect_rc 1
  expect_out "Invalid job count: x"
}

test_silent_and_color() {
  new_tree silent r1
  run "${tree}" --silent -- status
  expect_rc 0
  expect_eq "${out}" ""
  run "${tree}" -q -- status
  expect_eq "${out}" ""
  run "${tree}" -q -v -- status
  expect_out "::: r1"
  run "${tree}" --color always -- status
  expect_out $'\033[1;33mr1\033[0m'
  run "${tree}" -c never -- status
  expect_no_out $'\033['
  # Not a terminal: auto means no color.
  run "${tree}" -c auto -- status
  expect_no_out $'\033['
}

test_freeze() {
  new_tree freeze hot cold
  run "${tree}" --freeze "${tree}/cold"
  expect_rc 1
  expect_out "${tree}/cold now frozen."
  [[ -f "${tree}/cold/.git-parallel.freeze" ]] || fail "${current}: freeze file missing"
  run "${tree}" -- ::: cat name.txt
  expect_out "${tree}/cold is frozen."
  expect_out "hot"
  # The command did not run in the frozen repository.
  ! grep -qx cold <<<"${out}" || fail "${current}: command ran in a frozen repository"
  run "${tree}" -F "${work}/nowhere"
  expect_err "is not git-repository."
}

test_empty_tree() {
  mkdir -p "${work}/empty"
  run "${work}/empty" --list
  expect_eq "${out}" ""
  run "${work}/empty" -- status
  expect_rc 0
  expect_out "start parallel: status"
}

test_git_subcommand() {
  # Installed on PATH, the script runs as `git parallel` through the bash
  # under test (the shebang uses /usr/bin/env bash).
  new_tree subcommand r1 r2
  local bin="${work}/bin"
  mkdir -p "${bin}"
  ln -sf "${GP}" "${bin}/git-parallel"
  ln -sf "${TEST_BASH}" "${bin}/bash"
  out="$(cd "${tree}" && PATH="${bin}:${PATH}" git parallel --jobs 2 -- log --format=%s 2>&1)"; rc=$?
  expect_rc 0
  expect_out "init r1"
  expect_out "init r2"
  out="$(PATH="${bin}:${PATH}" git parallel --version 2>&1)"; rc=$?
  expect_rc 1
  expect_out "git-parallel v"
}

test_no_temp_files_left() {
  new_tree tmpfiles r1 r2 r3
  local tmp="${work}/tmpdir"
  mkdir -p "${tmp}"
  out="$(cd "${tree}" && TMPDIR="${tmp}" "${TEST_BASH}" "${GP}" -j 2 -- status 2>&1)"; rc=$?
  expect_rc 0
  [[ -z "$(ls -A "${tmp}")" ]] || fail "${current}: temporary files left: $(ls -A "${tmp}")"
}

test_interrupt() {
  # TERM stops git-parallel and the commands it started, and removes its
  # temporary files.
  new_tree interrupt r1 r2
  local tmp="${work}/tmp-int" marker="git-parallel-test-sleep-$$" pattern
  mkdir -p "${tmp}"
  ln -sf "$(command -v sleep)" "${work}/${marker}"
  pattern="^${work}/${marker} 30"
  (cd "${tree}" && TMPDIR="${tmp}" exec "${TEST_BASH}" "${GP}" -j 2 -q -- ::: "${work}/${marker}" 30) 2>"${work}/interrupt.stderr" &
  local pid=$! i=0
  while [[ -z "$(pgrep -f "${pattern}" || true)" && ${i} -lt 50 ]]; do sleep 0.1; i=$((i + 1)); done
  [[ -n "$(pgrep -f "${pattern}" || true)" ]] || { fail "${current}: commands did not start"; kill "${pid}" 2>/dev/null; return; }
  kill -TERM "${pid}"
  wait "${pid}" 2>/dev/null
  i=0
  while [[ -n "$(pgrep -f "${pattern}" || true)" && ${i} -lt 50 ]]; do sleep 0.1; i=$((i + 1)); done
  if [[ -n "$(pgrep -f "${pattern}" || true)" ]]; then
    pkill -f "${pattern}" 2>/dev/null
    fail "${current}: commands still running after TERM"
  fi
  [[ -z "$(ls -A "${tmp}")" ]] || fail "${current}: temporary files left: $(ls -A "${tmp}")"
}

# --strict (opt-in): the exit status reports failures in the repositories.
# Every job is waited for by its PID and its status is collected.

# exit_code_tree NAME CODE...: repositories r1..rN whose `code` file holds the
# status that ${work}/exit-code.sh exits with there.
exit_code_tree() {
  local name="$1" i=1 c repos=()
  shift
  for c in "$@"; do repos+=("r${i}"); i=$((i + 1)); done
  new_tree "${name}" "${repos[@]}"
  i=1
  for c in "$@"; do echo "${c}" > "${tree}/r${i}/code"; i=$((i + 1)); done
  cat > "${work}/exit-code.sh" <<'SH'
#!/bin/sh
exit "$(cat code)"
SH
}

test_strict_success() {
  new_tree strict-ok r1 r2 r3
  run "${tree}" --strict -- ::: cat name.txt
  expect_rc 0
  expect_out "::: r1"
  expect_out "::: r3"
  expect_eq "${err}" ""
  run "${tree}" --strict -j 1 -- log --format=%s
  expect_rc 0
  expect_out "init r2"
}

test_strict_partial_failure() {
  new_tree strict-partial good1 bad good2
  rm -f "${tree}/bad/name.txt"
  local j
  # One batch (--jobs 3), batches of two (--jobs 2) and one job at a time:
  # the failure is found whichever batch and position it is in.
  for j in 3 2 1; do
    run "${tree}" --strict --jobs "${j}" -- ::: cat name.txt
    expect_rc 1
    # Every repository still ran; the output is the same as without --strict.
    expect_out "::: good1"
    expect_out "::: good2"
    expect_out "name.txt: No such file or directory"
    expect_err "git-parallel: the command failed in 1 of 3 repositories:"
    expect_err "  ${tree}/bad (exit 1)"
    [[ "${err}" != *good* ]] || fail "${current}: a succeeded repository is listed as failed (--jobs ${j})"
  done
  # Without --strict nothing changes: exit 0 and no summary.
  run "${tree}" --jobs 2 -- ::: cat name.txt
  expect_rc 0
  expect_eq "${err}" ""
}

test_strict_all_fail_and_statuses() {
  new_tree strict-all r1 r2
  run "${tree}" --strict -- rev-parse --verify no-such-ref
  expect_rc 1
  expect_out "fatal: Needed a single revision"
  expect_err "failed in 2 of 2 repositories:"
  expect_err "  ${tree}/r1 (exit 128)"
  expect_err "  ${tree}/r2 (exit 128)"
  # A command that is not found fails with 127.
  run "${tree}" --strict -- ::: git-parallel-no-such-command
  expect_rc 1
  expect_err "  ${tree}/r1 (exit 127)"
  # Each repository's own status is reported, not only the first or last.
  exit_code_tree strict-codes 0 3 0 42 0
  run "${tree}" --strict --jobs 2 -- ::: sh "${work}/exit-code.sh"
  expect_rc 1
  expect_err "failed in 2 of 5 repositories:"
  expect_err "  ${tree}/r2 (exit 3)"
  expect_err "  ${tree}/r4 (exit 42)"
  [[ "${err}" != *"/r1 "* && "${err}" != *"/r3 "* && "${err}" != *"/r5 "* ]] \
    || fail "${current}: a succeeded repository is listed as failed"
  # The last job of the last batch failing is not lost either.
  exit_code_tree strict-last 0 0 5
  run "${tree}" --strict --jobs 3 -- ::: sh "${work}/exit-code.sh"
  expect_rc 1
  expect_err "  ${tree}/r3 (exit 5)"
}

test_strict_frozen_and_silent() {
  new_tree strict-frozen hot cold
  rm -f "${tree}/hot/name.txt"
  run "${tree}" --freeze "${tree}/cold"
  # A frozen repository is skipped and counts as succeeded.
  run "${tree}" --strict -- ::: cat "${tree}/cold/name.txt"
  expect_rc 0
  expect_out "${tree}/cold is frozen."
  run "${tree}" --strict -- ::: cat name.txt
  expect_rc 1
  expect_err "failed in 1 of 2 repositories:"
  expect_err "  ${tree}/hot (exit 1)"
  [[ "${err}" != *"/cold "* ]] || fail "${current}: the frozen repository is listed as failed"
  # --silent hides the output of the repositories, not the failure summary.
  run "${tree}" --silent --strict -- ::: cat name.txt
  expect_rc 1
  expect_eq "${out}" ""
  expect_err "  ${tree}/hot (exit 1)"
  run "${tree}" -q --strict -- ::: cat "${tree}/cold/name.txt"
  expect_rc 0
  expect_eq "${out}" ""
  expect_eq "${err}" ""
}

test_strict_no_repositories() {
  mkdir -p "${work}/strict-empty"
  run "${work}/strict-empty" --strict -- status
  expect_rc 0
  expect_eq "${err}" ""
}

# strict_signal SIGNAL STATUS: --strict exits with STATUS (128 + the signal
# number) on SIGNAL, kills the running commands and removes its temporary
# files.
strict_signal() {
  local sig="$1" want="$2"
  new_tree "strict-${sig}" r1 r2
  local tmp="${work}/tmp-strict-${sig}" marker="git-parallel-test-strict-${sig}-$$" pattern
  mkdir -p "${tmp}"
  ln -sf "$(command -v sleep)" "${work}/${marker}"
  pattern="^${work}/${marker} 30"
  # Job control gives the background job its own process group and keeps
  # SIGINT from being ignored in it (a non-interactive shell starts
  # background commands with SIGINT ignored, and bash cannot trap a signal
  # that was ignored when it started).
  set -m
  (cd "${tree}" && TMPDIR="${tmp}" exec "${TEST_BASH}" "${GP}" --strict -j 2 -q -- ::: "${work}/${marker}" 30) 2>"${work}/strict-${sig}.stderr" &
  local pid=$! i=0 status
  set +m
  while [[ -z "$(pgrep -f "${pattern}" || true)" && ${i} -lt 50 ]]; do sleep 0.1; i=$((i + 1)); done
  [[ -n "$(pgrep -f "${pattern}" || true)" ]] || { fail "${current}: commands did not start"; kill "${pid}" 2>/dev/null; return; }
  kill "-${sig}" "${pid}"
  wait "${pid}" 2>/dev/null
  status=$?
  rc="${status}"
  expect_rc "${want}"
  err="$(cat "${work}/strict-${sig}.stderr")"
  expect_err "git-parallel: interrupted by SIG${sig}"
  i=0
  while [[ -n "$(pgrep -f "${pattern}" || true)" && ${i} -lt 50 ]]; do sleep 0.1; i=$((i + 1)); done
  if [[ -n "$(pgrep -f "${pattern}" || true)" ]]; then
    pkill -f "${pattern}" 2>/dev/null
    fail "${current}: commands still running after ${sig}"
  fi
  [[ -z "$(ls -A "${tmp}")" ]] || fail "${current}: temporary files left: $(ls -A "${tmp}")"
}

test_strict_sigterm() { strict_signal TERM 143; }
test_strict_sigint() { strict_signal INT 130; }

test_strict_help() {
  run "${work}" --help
  expect_err "--strict"
  expect_err "EXIT STATUS:"
}

# shellcheck disable=SC2016
echo "git-parallel tests with $("${TEST_BASH}" -c 'echo "bash ${BASH_VERSION}"') (${TEST_BASH}), $(git --version)"

t "--version / -V" test_version
t "--help / -h / no command" test_help
t "unknown options and invalid values" test_unknown_options
t "--list" test_list
t "--maxdepth" test_maxdepth
t "-d / --target / --targets" test_targets
t "git commands" test_git_command
t "::: bare commands" test_bare_command
t "output order" test_output_order
t "paths with spaces" test_paths_with_spaces
t "argument quoting" test_argument_quoting
t "error propagation and exit status" test_error_propagation
t "--jobs runs jobs in parallel" test_parallel_jobs
t "--jobs 0 is rejected" test_jobs_zero
t "--silent / --verbose / --color" test_silent_and_color
t "--freeze" test_freeze
t "no repositories" test_empty_tree
t "git parallel (git subcommand)" test_git_subcommand
t "temporary files are removed" test_no_temp_files_left
t "TERM stops running commands" test_interrupt
t "--strict: all succeed" test_strict_success
t "--strict: partial failure" test_strict_partial_failure
t "--strict: all fail, per-repository statuses" test_strict_all_fail_and_statuses
t "--strict: frozen repositories and --silent" test_strict_frozen_and_silent
t "--strict: no repositories" test_strict_no_repositories
t "--strict: SIGTERM" test_strict_sigterm
t "--strict: SIGINT" test_strict_sigint
t "--strict in --help" test_strict_help

echo
echo "${passed} passed, ${failed} failed"
[[ "${failed}" == 0 ]]
