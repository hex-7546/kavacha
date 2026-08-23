#include "dhry.h"
#include <stddef.h>
#include <stdint.h>

/* Minimal bare-metal support for Dhrystone */

/* 1. Malloc replacement (Dhrystone only allocates two structs at the beginning) */
Rec_Type rec1, rec2;
void* malloc(size_t size) {
    static int alloc_count = 0;
    if (alloc_count == 0) { alloc_count++; return &rec1; }
    if (alloc_count == 1) { alloc_count++; return &rec2; }
    return NULL;
}

/* 2. Timer functions using RISC-V CSRs */
long time(long* tloc) {
    uint32_t cycles;
#ifdef PICORV32
    __asm__ volatile ("csrr %0, cycle" : "=r" (cycles));
#else
    __asm__ volatile ("csrr %0, mcycle" : "=r" (cycles));
#endif
    if (tloc) *tloc = cycles;
    return cycles;
}

long insn(long* tloc) {
    uint32_t instret;
#ifdef PICORV32
    __asm__ volatile ("csrr %0, instret" : "=r" (instret));
#else
    __asm__ volatile ("csrr %0, minstret" : "=r" (instret));
#endif
    if (tloc) *tloc = instret;
    return instret;
}

