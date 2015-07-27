CFLAGS ?= -march=native -g3 -gdwarf-4 -Wall -Wextra $(EXTRA_CFLAGS)
CFLAGS += -std=gnu11

PGMS = add_code_32 add_code_64 test test_static test_32 test_static_32
NEWCODES = test_new_code test_multisection_32 test_multisection_64

all: $(PGMS) $(NEWCODES)

add_code_32: add_code.c utils.h
	$(CC) -DADD_CODE_32 $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
add_code_64: add_code.c utils.h
	$(CC) -DADD_CODE_64 $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)


test: test.c utils.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_static: test.c utils.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -static -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_32: test.c utils.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -m32 -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_static_32: test.c utils.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -m32 -static -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)


TEST_CODE_CFLAGS = -nostdlib -static -Wl,-Ttext=0x066000000 -Wl,-Tdata=0x066200000 -Wl,-Tbss=0x066400000 -Wl,--build-id=none

test_new_code: test_new_code.nasm
	# Make sure it's still valid 64-bit code!
	nasm -fbin -Wall -o $@ $<
test_multisection_32: test_multisection_32.nasm
	nasm -felf32 -Wall -o $@.o $<
	$(CC) $(TEST_CODE_CFLAGS) -m32 -o $@ $@.o
	rm -f $@.o
test_multisection_64: test_multisection_64.nasm
	nasm -felf64 -Wall -o $@.o $<
	$(CC) $(TEST_CODE_CFLAGS) -o $@ $@.o
	rm -f $@.o

check: all
	./test.sh ./add_code_64 test test_new_code
	./test.sh ./add_code_64 test_static test_new_code
	./test.sh ./add_code_64 test test_new_code 0x03330000
	./test.sh ./add_code_64 test_static test_new_code 0x03330000
	./test.sh ./add_code_32 test_32 test_new_code
	./test.sh ./add_code_32 test_static_32 test_new_code
	./test.sh ./add_code_32 test_32 test_new_code 0x03330000
	./test.sh ./add_code_32 test_static_32 test_new_code 0x03330000
	./test.sh ./add_code_64 test test_multisection_64
	./test.sh ./add_code_64 test_static test_multisection_64
	./test.sh ./add_code_32 test_32 test_multisection_32
	./test.sh ./add_code_32 test_static_32 test_multisection_32

.PHONY: clean all check
clean:
	rm -f $(PGMS) $(NEWCODES) ./modified_test
