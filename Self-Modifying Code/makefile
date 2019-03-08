CFLAGS:=-g -Wall

all: sic

root: sic.o
	gcc -g -Wall -o root sic.o

sic.o: sic.s
	nasm -g -f elf64 -w+all -o sic.o sic.s

.PHONY: clean
clean:
	rm -f *.o sic
