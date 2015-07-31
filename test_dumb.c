#include <err.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[])
{
    if (argc == 0)
        errx(10, "argc == 0? WTF?");
    printf("main: I was called with argv[0]=%s\n", argv[0]);
    return strcmp(argv[0], "Q");
}
