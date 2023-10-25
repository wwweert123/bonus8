.SILENT: test tidy
.PHONY: all clean compile test tidy

SHELL := /bin/bash
FILES=three
CC=clang
LDLIBS=-lm -lcs1010
CFLAGS=@compile_flags.txt

all: compile test

compile: $(FILES) 

test: $(FILES) tidy
	for question in $(FILES); do ./test.sh $$question; done

tidy:
	clang-tidy -quiet *.c 2> /dev/null

clean:
	rm $(FILES)
# vim:noexpandtab