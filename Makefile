CFLAGS ?= -march=native -g3 -gdwarf-4 -Wall -Wextra $(EXTRA_CFLAGS)
CFLAGS += -std=gnu99

PGMS = add_code_32 add_code_64 test

all: $(PGMS)

add_code_32: add_code.c utils.h
	$(CC) -DADD_CODE_32 $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)
add_code_64: add_code.c utils.h
	$(CC) -DADD_CODE_64 $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LOADLIBES) $(LDLIBS)

check: all
	./add_code_64 test test_new_code > ./modified_test
	chmod a+x ./modified_test
	./modified_test

.PHONY: clean all check
clean:
	rm -f $(PGMS) ./modified_test
