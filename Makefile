DEFAULT:

backup:
	cp git-parallel git-parallel.BAK
clean:
	rm -f git-parallel.BAK
test1:
	sh test/case1
