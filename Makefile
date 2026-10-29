CC = gcc
VULN_FLAGS = -g -O0 -fno-stack-protector -no-pie

.PHONY: all foundations reverse ret2win ret2libc clean

all: foundations reverse ret2win ret2libc

foundations:
	$(CC) -g -O0 -no-pie -fno-stack-protector -o 01-foundations/mem 01-foundations/mem.c

reverse:
	$(CC) -O0 -no-pie -o 02-reverse-engineering/crackme 02-reverse-engineering/crackme.c
	strip 02-reverse-engineering/crackme

ret2win:
	$(CC) $(VULN_FLAGS) -o 03-binexp-control-flow/ret2win/vuln 03-binexp-control-flow/ret2win/vuln.c

ret2libc:
	$(CC) $(VULN_FLAGS) -o 04-binexp-defeating-mitigations/ret2libc/vuln 04-binexp-defeating-mitigations/ret2libc/vuln.c

clean:
	rm -f 01-foundations/mem 02-reverse-engineering/crackme \
	      03-binexp-control-flow/ret2win/vuln \
	      04-binexp-defeating-mitigations/ret2libc/vuln
