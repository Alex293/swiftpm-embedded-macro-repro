// Minimal Cortex-M7 startup residue: a vector table, a reset handler that
// copies .data and zeroes .bss before calling `main` (the Swift `@main`), a
// trapping default handler, a `putchar` with an observable side effect and
// an `_exit` stub for picolibc.
//
// Everything is guarded by the Armv7E-M architecture macro so that the file
// compiles to an empty translation unit for the host (`swift build` without
// a triple builds every target for the host).

#include "Support.h"

#if defined(__ARM_ARCH_7EM__)

#include <stdint.h>
#include <unistd.h>  // picolibc: declares _exit; found via the toolset's -I

// Provided by linkerscript.ld.
extern uint32_t __stack_end;

void IntDefaultHandlerISR(void) { __builtin_trap(); }

// Reset entry point. Naked: no stack frame until .data/.bss are valid.
// Both loops are word loops; the linker script word-aligns the bounds.
__attribute__((naked)) __attribute__((noreturn)) void ResetISR(void) {
    asm volatile(
        // Copy .data from flash to RAM.
        "ldr   r0, =__data_start        \n"
        "ldr   r1, =__flash_data_start  \n"
        "ldr   r2, =__flash_data_len    \n"
        "add   r2, r0, r2               \n"
        "1:                             \n"
        "cmp   r0, r2                   \n"
        "bhs   2f                       \n"
        "ldr   r3, [r1], #4             \n"
        "str   r3, [r0], #4             \n"
        "b     1b                       \n"
        "2:                             \n"
        // Zero .bss.
        "ldr   r0, =__bss_start         \n"
        "ldr   r1, =__bss_end           \n"
        "movs  r2, #0                   \n"
        "3:                             \n"
        "cmp   r0, r1                   \n"
        "bhs   4f                       \n"
        "str   r2, [r0], #4             \n"
        "b     3b                       \n"
        "4:                             \n"
        "bl    main                     \n"
        "b     .                        \n");
}

// The 16 architectural entries: initial SP, reset, and 14 system handlers.
__attribute__((section(".vectors"), used))
const void *const Vectors[16] = {
    (const void *)&__stack_end,  // 0  initial stack pointer
    ResetISR,                    // 1  Reset
    IntDefaultHandlerISR,        // 2  NMI
    IntDefaultHandlerISR,        // 3  HardFault
    IntDefaultHandlerISR,        // 4  MemManage
    IntDefaultHandlerISR,        // 5  BusFault
    IntDefaultHandlerISR,        // 6  UsageFault
    0, 0, 0, 0,                  // 7-10 reserved
    IntDefaultHandlerISR,        // 11 SVCall
    IntDefaultHandlerISR,        // 12 DebugMonitor
    0,                           // 13 reserved
    IntDefaultHandlerISR,        // 14 PendSV
    IntDefaultHandlerISR,        // 15 SysTick
};

// ELF entry point (`-e _start_elf`): never called, it is a GC root that
// keeps the vector table alive.
void *_start_elf(void) { return (void *)&Vectors; }

// A putchar with a side effect the optimizer cannot remove: a volatile
// store to a plausible MMIO address (a UART transmit data register).
int putchar(int c) {
    *(volatile uint32_t *)0x40011028u = (uint32_t)c;
    return c;
}

__attribute__((noreturn)) void _exit(int status) {
    (void)status;
    __builtin_trap();
}

#endif // __ARM_ARCH_7EM__
