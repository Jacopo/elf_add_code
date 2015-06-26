#define NEW_CODE_ADDRESS 0x6660000u /* Must match the one in add_code.c */

#include <err.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include "utils.h"

static inline void print_self_maps()
{
    // It seems /proc/self/maps can only be read character-by-character
    printf("/proc/self/maps:\n");
    int fd;
    VS(fd = open("/proc/self/maps", O_RDONLY));
    while (true) {
        unsigned char c;
        if (do_read_partial(fd, &c, 1) == 0)
            break;
        VE(putchar(c) != EOF);
    }
    VS(close(fd));
    printf("\n\n");
}

int main(int argc, char *argv[])
{
    if (argc != 1)
        errx(10, "Usage: %s", argv[0]);

    uint8_t* new_code = (uint8_t*) NEW_CODE_ADDRESS;


#define P(x) do { extern uint8_t x; printf(#x "\t= %p\n", &x); } while (0)
    P(__executable_start);
    P(_etext);
    P(_edata);
    P(_end);
    print_self_maps();


    printf("First four bites of new code (%p):\n", new_code);
    do_write(1, new_code, 4);


    printf("\nChecking it matches './test_new_code'...\n");

    off_t new_code_size;
    uint8_t *from_file = read_file("./test_new_code", &new_code_size);

    /*
    printf("i: actual from_file\n");
    printf("-------------------\n");
    for (int64_t i = 0; i < new_code_size; i++) {
        uint8_t b = new_code[i];
        printf("%1$"PRIi64": %2$02"PRIx8" %3$02"PRIx8"   %2$c %3$c", i, b, from_file[i]);
        if (b != from_file[i])
            printf("    differs");
        printf("\n");
    }
    */

    V(memcmp(new_code, from_file, new_code_size) == 0);


    printf("Jumping there...\n");

    typedef int (*pfunc)();
    return ((pfunc) new_code)();
}
