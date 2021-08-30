git-parallel
============

NAME
----
git-parallel - Run the command in parallel much to multiple repositories

Synopsis
--------
* git-parallel [-h] [-n] [-j \<jobs\>] [-e \<command\>]

Usage
-----
    git-parallel commands are:  
        -h  show help  
        -c  put a color on the result  
        -j  max job count  
        -e  command to be executed  
ex)

    $ git parallel -c -j 4 -e "pull --rebase"


What's this?
------------
This command is executed in parallel to the git repository in the current directory directly under.

    $ tree -L 1
    .
    ├── git_repo1
    ├── git_repo2
    ├── git_repo3
    ├── git_repo4
    ├── not_git_repo -> command not execute!
    ├── git_repo5
    ├── git_repo6
    └── git_repo7

However repository to the presence of the file named .git-freeze is ignored.

    $ $(cd git_repo1 && touch .git-freeze)
    
    $ tree -L 1
    .
    ├── git_repo1 -> command not execute!
    ├── git_repo2
    ├── git_repo3
    └── git_repo4
	
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
