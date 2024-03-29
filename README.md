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

ex)

    git parallel --color auto --jobs 2 --silent -- pull --rebase

    git parallel --maxdepth 3 --jobs 4 -- ::: ls -lha
```


Author

Copyright (c) 2013 - 2021 Hiroshi IKEGAMI

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
