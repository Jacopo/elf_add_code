#pragma once

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

#define VAL_TO_STR(x) __STRING(x)
#define V(x) if (unlikely(!(x)))   errx(-9, __FILE__ ":" VAL_TO_STR(__LINE__) " %s, it's not %s", __PRETTY_FUNCTION__, #x)
#define VE(x) if (unlikely(!(x))) err(-9, __FILE__ ":" VAL_TO_STR(__LINE__) " %s, it's not %s", __PRETTY_FUNCTION__, #x)
#define VS(x) if (unlikely((x) == -1)) err(-9, __FILE__ ":" VAL_TO_STR(__LINE__) " %s, %s failed (returned -1)", __PRETTY_FUNCTION__, #x)


// It's in unistd.h, but for some reason it is not always included
#ifndef TEMP_FAILURE_RETRY
# define TEMP_FAILURE_RETRY(expression) \
  (__extension__                                                              \
    ({ long int __result;                                                     \
       do __result = (long int) (expression);                                 \
       while (__result == -1L && errno == EINTR);                             \
       __result; }))
#endif


static inline void do_sleep(unsigned int seconds)
{
    // Note: libc takes care of the madness, and does not use SIGALRM
    while (seconds > 0)
        seconds = sleep(seconds);
}

__attribute__ ((__warn_unused_result__))  __attribute__ ((__nonnull__))
static inline ssize_t do_read_partial(int fd, uint8_t* buf, size_t len)
{
    V(len <= SSIZE_MAX);
    ssize_t r;
    uint8_t *rbuf = buf;
    do {
        VS(r = TEMP_FAILURE_RETRY(read(fd, rbuf, len)));
        if (r == 0)
            break;
        len -= r;
        rbuf += r;
    } while (len != 0);
    return rbuf - buf;
}

__attribute__ ((__warn_unused_result__))  __attribute__ ((__nonnull__))
static inline ssize_t do_write_partial(int fd, const uint8_t* buf, size_t len)
{
    V(len <= SSIZE_MAX);
    ssize_t w;
    const uint8_t *wbuf = buf;
    do {
        VS(w = TEMP_FAILURE_RETRY(write(fd, wbuf, len)));
        if (w == 0)
            break;
        len -= w;
        wbuf += w;
    } while (len != 0);
    return wbuf - buf;
}


__attribute__((__nonnull__)) 
static inline void do_read(int fd, uint8_t *buf, size_t len)
{
    V(do_read_partial(fd, buf, len) == (ssize_t) len);
}

__attribute__((__nonnull__)) 
static inline void do_write(int fd, const uint8_t *buf, size_t len)
{
    V(do_write_partial(fd, buf, len) == (ssize_t) len);
}



__attribute__((__nonnull__))
static inline uint8_t* read_file(const char *filename, off_t *size)
{
    int fd;
    VS(fd = open(filename, O_RDONLY));

    struct stat st;
    VS(fstat(fd, &st));
    *size = st.st_size;

    uint8_t *buf = (uint8_t*) malloc(*size);
    VE(buf != NULL);
    do_read(fd, buf, *size);
    VS(close(fd));
    return buf;
}
