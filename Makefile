PREFIX=${HOME}
CURRENTDIR=$(shell pwd)

manpage:
	md2man-roff README.md > ./git-parallel.1

install:
	ln -sf $(CURRENTDIR)/git-parallel $(PREFIX)/bin/
	ln -sf $(CURRENTDIR)/git-parallel.1 $(PREFIX)/share/man/man1/

clean:
	rm $(CURRENTDIR)/git-parallel.1
