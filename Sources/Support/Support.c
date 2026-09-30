#include <unistd.h>  // picolibc header: only found through the toolset's -I

int putchar(int c) { return c; }

__attribute__((noreturn)) void _exit(int status) { for (;;) {} }
