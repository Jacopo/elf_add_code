#include <assert.h>
#include <err.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
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
    if (!(argc == 1 || argc == 2 || (argc == 3 && strcmp(argv[1], "nofilecheck") == 0)))
        errx(10, "Usage: %s [nofilecheck] [new_code_vaddr=0x06660000]", argv[0]);

    bool nofilecheck = false;
    if (argc >= 2 && strcmp(argv[1], "nofilecheck") == 0) {
        nofilecheck = true;
        argv[1] = argv[2];
        argc--;
    }


    unsigned long new_code_ul = 0x06660000u;
    static_assert(sizeof(unsigned long) == sizeof(void*), ""); /* Unclean, but good and simple */
    if (argc == 2)
        new_code_ul = explicit_hex_conv(argv[1]);
    uint8_t* new_code = (uint8_t*) new_code_ul;


#define P(x) do { extern uint8_t x; printf(#x "\t= %p\n", &x); } while (0)
    P(__executable_start);
    P(_etext);
    P(_edata);
    P(_end);
    print_self_maps();


    printf("First four bites of new code (%p):\n", new_code);
    do_write(1, new_code, 4);
    printf("\n");

    if (!nofilecheck) {
        printf("Checking it matches './test_new_code'...\n");
        size_t new_code_size;
        uint8_t *from_file = read_file("./test_new_code", &new_code_size);
        V(memcmp(new_code, from_file, new_code_size) == 0);
    }


    printf("Jumping there...\n");

    typedef int (*pfunc)();
    unsigned int ret = ((pfunc) new_code)();
    printf("new code returned 0x%x\n", ret);
    V(ret == 0x41414141u);
    return 0;
}
