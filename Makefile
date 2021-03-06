CFLAGS ?= -march=native -g3 -gdwarf-4 -Wall -Wextra $(EXTRA_CFLAGS)
CFLAGS += -std=gnu11

# Basic functionality
PGMS = add_code_32 add_code_64
PGMS += test test_static test_32 test_static_32
NEWCODES = test_new_code test_multisection_32 test_multisection_64 test_multisection_32.o test_multisection_64.o test_multisection_origentry_32.o test_multisection_origentry_64.o

# Entry-point replacement helpers
NEWCODES += entry_helper_64.o entry_helper_32.o
PGMS += test_dumb test_dumb_static test_dumb_32 test_dumb_static_32
NEWCODES += entry_test_32.o entry_test_64.o


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
test_dumb: test_dumb.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_dumb_static: test_dumb.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -static -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_dumb_32: test_dumb.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -m32 -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
test_dumb_static_32: test_dumb.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -m32 -static -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)


TEST_CODE_CFLAGS = -nostdlib -static -Wl,-Ttext=0x066000000 -Wl,-Tdata=0x066200000 -Wl,-Tbss=0x066400000 -Wl,--build-id=none

test_new_code: test_new_code.nasm
	# Make sure it's still valid 64-bit code!
	nasm -fbin -Wall -o $@ $<
test_multisection_32.o: test_multisection_32.nasm
	nasm -felf32 -Wall -o $@ $<
test_multisection_32: test_multisection_32.o
	$(CC) $(TEST_CODE_CFLAGS) -m32 -o $@ $<
test_multisection_64.o: test_multisection_64.nasm
	nasm -felf64 -Wall -o $@ $<
test_multisection_64: test_multisection_64.o
	$(CC) $(TEST_CODE_CFLAGS) -o $@ $<
test_multisection_origentry_64.o: test_multisection_64.nasm
	nasm -DPRINT_ORIGINAL_ENTRYPOINT -felf64 -Wall -o $@ $<
test_multisection_origentry_32.o: test_multisection_32.nasm
	nasm -DPRINT_ORIGINAL_ENTRYPOINT -felf32 -Wall -o $@ $<

entry_helper_64.o: entry_helper_64.nasm
	nasm -felf64 -Wall -o $@ $<
entry_helper_32.o: entry_helper_32.nasm
	nasm -felf32 -Wall -o $@ $<

entry_test_64.o: entry_test_64.nasm
	nasm -felf64 -Wall -o $@ $<
entry_test_32.o: entry_test_32.nasm
	nasm -felf32 -Wall -o $@ $<



check: all
	./test.sh ./add_code_64 test test_new_code
	./test.sh ./add_code_64 test_static test_new_code
	./test.sh ./add_code_64 test test_new_code 0x13330000
	./test.sh ./add_code_64 test_static test_new_code 0x13330000
	./test.sh ./add_code_32 test_32 test_new_code
	./test.sh ./add_code_32 test_static_32 test_new_code
	./test.sh ./add_code_32 test_32 test_new_code 0x13330000
	./test.sh ./add_code_32 test_static_32 test_new_code 0x13330000
	@echo "Basic tests passed, let's try injecting full ELF executables..."
	./test.sh ./add_code_64 test test_multisection_64
	./test.sh ./add_code_64 test_static test_multisection_64
	./test.sh ./add_code_32 test_32 test_multisection_32
	./test.sh ./add_code_32 test_static_32 test_multisection_32
	@echo "ELF executable tests passed, let's try linking in ELF objects..."
	./test.sh ./add_code_64 test test_multisection_origentry_64.o
	./test.sh ./add_code_64 test_static test_multisection_origentry_64.o
	./test.sh ./add_code_64 test test_multisection_origentry_64.o 0x13330000
	./test.sh ./add_code_64 test_static test_multisection_origentry_64.o 0x13330000
	./test.sh ./add_code_32 test_32 test_multisection_origentry_32.o
	./test.sh ./add_code_32 test_static_32 test_multisection_origentry_32.o
	./test.sh ./add_code_32 test_32 test_multisection_origentry_32.o 0x13330000
	./test.sh ./add_code_32 test_static_32 test_multisection_origentry_32.o 0x13330000
	@echo "Non-entry code injection tests passed, let's now test entry-point replacement helpers..."
	./test-entry.sh ./add_code_64 --before-entry test_dumb_static entry_test_64.o
	./test-entry.sh ./add_code_64 --before-entry test_dumb_static entry_test_64.o 0x13330000
	./test-entry.sh ./add_code_32 --before-entry test_dumb_static_32 entry_test_32.o
	./test-entry.sh ./add_code_32 --before-entry test_dumb_static_32 entry_test_32.o 0x13330000
	@echo "before-entry doesn't work on dynamic executables, not testing it"
	#./test-entry.sh ./add_code_64 --before-entry test_dumb entry_test_64.o
	#./test-entry.sh ./add_code_64 --before-entry test_dumb entry_test_64.o 0x13330000
	#./test-entry.sh ./add_code_32 --before-entry test_dumb_32 entry_test_32.o
	#./test-entry.sh ./add_code_32 --before-entry test_dumb_32 entry_test_32.o 0x13330000
	@echo "All tests passed :)"

.PHONY: clean all check
clean:
	rm -f $(PGMS) $(NEWCODES) ./modified_test
