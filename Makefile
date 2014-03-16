PREFIX=${HOME}/local
CURRENTDIR=$(shell pwd -L | perl -p -e 's/ /\\ /g')

all:
	@echo "make [intall|uninstall]"

man:
	[ -e $(shell which md2man-roff) ] && md2man-roff $(CURRENTDIR)/README.md > $(CURRENTDIR)/git-parallel.1

install:
	mkdir -p $(PREFIX)/bin/ $(PREFIX)/share/man/man1/
	cp -af $(CURRENTDIR)/git-parallel $(PREFIX)/bin/
	cp -af $(CURRENTDIR)/git-parallel.1 $(PREFIX)/share/man/man1/

uninstall:
	rm -f $(PREFIX)/bin/git-parallel
	rm -f  $(PREFIX)/share/man/man1/git-parallel.1

