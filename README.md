git-parallel
============

NAME
----
git-parallel - Run the command in parallel much to multiple repositories

Usage
-----

```
USAGE:

  git-parallel [OPTIONS] -- [GITCMD|:::CMD] # Run the command in parallel much to multiple repositories.

OPTIONS:

  * [-h|--help]                             # Show this help.
  * [-j|--jobs] job-count                   # Execute in parallel with `job-count`
  * [-m|--maxdepth] depth-count             # Search target git-repositories in maxdepth.
  * [-V|--version]                          # Show git-parallel version info.
  * [-c|--color] auto|always|never          # Configure output color.
  * [-l|--list]                             # List up target git repositories.
  * [-q|--silent]                           # Execute silent. (no output)
  * [-v|--verbose]                          # Execute verbose. (default.)
  * [-d|--targets] target-derectory         # Specified target git-repositories
  * [-F|--freeze] repository-path           # Generate .git-parallel.freeze file.
  * [--strict]                              # Exit 1 if the command fails in any repository.

EXIT STATUS:

  Without --strict the exit status is 0 even when the command fails in some
  or all repositories (historical behavior).

  With --strict every repository still runs; then:
    0        the command succeeded in every repository (frozen ones count as
             succeeded)
    1        it failed in at least one repository; they are listed on stderr
             with their exit status, even with --silent
    129 130 131 143
             git-parallel was stopped by SIGHUP, SIGINT, SIGQUIT or SIGTERM
             (128 + signal number); running commands are killed

ex)

    git parallel --color auto --jobs 2 --silent -- pull --rebase

    git parallel --maxdepth 3 --jobs 4 -- ::: ls -lha

    git parallel --strict -- fetch --prune || echo "fetch failed somewhere"
```

Exit status and `--strict`
--------------------------

By default `git-parallel` exits with 0 even when the command fails in some or
all repositories. This is the historical behavior and it is kept unchanged.

`--strict` makes failures visible in the exit status:

- Every repository still runs (a failure does not cancel the others), and the
  output is the same as without `--strict`.
- Each job is waited for by its PID and its exit status is collected.
- Exit status 0: the command succeeded in every repository. A frozen
  repository (`.git-parallel.freeze`) is skipped and counts as succeeded; no
  repository at all is a success too.
- Exit status 1: the command failed in at least one repository (partial or
  total failure). The failed repositories are listed on stderr, in order,
  with their own exit status, also with `--silent`:

  ```
  git-parallel: the command failed in 2 of 5 repositories:
    /src/api (exit 1)
    /src/web (exit 128)
  ```

  Usage errors also exit with 1, but are reported before anything runs.
- SIGHUP, SIGINT, SIGQUIT and SIGTERM stop git-parallel: the running commands
  are killed, temporary files are removed, `git-parallel: interrupted by
  SIG<NAME>` is printed on stderr and the exit status is 128 + the signal
  number (129, 130, 131, 143). Without `--strict`, git-parallel kills itself
  with SIGKILL as before.

There is no JSON output.

Install
-------

```
make install            # copies git-parallel and git-parallel.1 under PREFIX (default: ~/local)
make uninstall
```

With Homebrew (from the first release published with Hephaestus on):

```
brew install magicdrive/tap/git-parallel
```

`git-parallel` runs with bash 3.2 (macOS) or later. Once it is on your `PATH`,
git runs it as `git parallel`.

Development
-----------

```
make check                    # shellcheck + tests + make publish wiring
make test TEST_BASH=/bin/bash # tests with a specific bash
```

Releases are made with [Hephaestus](https://github.com/magicdrive/hephaestus)
(`make publish vX.Y.Z`): see [docs/development/releasing.md](docs/development/releasing.md).


Author

Copyright (c) 2013 - 2024 Hiroshi IKEGAMI

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
