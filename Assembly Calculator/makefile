CFLAGS:=-g -Wall

all: calc
	@echo "Build success"

calc: asm.o calc.o 
	gcc -g -Wall -o calc calc.o asm.o

asm.o: asm.s
	nasm -g -f elf64 -w+all -o asm.o asm.s

calc.o: calc.c
	gcc -g -Wall -c -o calc.o calc.c


.PHONY: clean
clean:
	rm -f *.o calc
