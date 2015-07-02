CFLAGS ?= -march=native -g3 -gdwarf-4 -Wall -Wextra $(EXTRA_CFLAGS)
CFLAGS += -std=gnu11

PGMS = add_code_32 add_code_64 test test_static test_32 test_static_32

all: $(PGMS)

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


check: all
	./test.sh ./add_code_64 test test_new_code
	./test.sh ./add_code_64 test_static test_new_code
	./test.sh ./add_code_64 test test_new_code 0x03330000
	./test.sh ./add_code_64 test_static test_new_code 0x03330000
	./test.sh ./add_code_32 test_32 test_new_code
	./test.sh ./add_code_32 test_static_32 test_new_code
	./test.sh ./add_code_32 test_32 test_new_code 0x03330000
	./test.sh ./add_code_32 test_static_32 test_new_code 0x03330000

.PHONY: clean all check
clean:
	rm -f $(PGMS) ./modified_test
