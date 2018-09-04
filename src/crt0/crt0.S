.global _start
.global _mod_header
.global rela_test
.global rela_test_size

.extern __crystal_nx_init
.extern svcExitProcess
.extern svcReturnFromException

.section .text.crt0, "ax"
_start:
    b tranpoline
    .word _mod_header - _start

.section .text, "x"
tranpoline:

    // restore LR
    mov x30, x27

    // First clean the .bss
    adrp x5, __bss_start
    add x5, x5, #:lo12:__bss_start
    adrp x6, __bss_end
    add x6, x6, #:lo12:__bss_end

clean_bss:
    cmp x5, x6
    b.eq startup
    str xzr, [x5]
    add x5, x5, 0x8
    b clean_bss

startup:
    // init + relocation
    adrp x2, _start
    add x2, x2, #:lo12:_start
    adrp x3, __dynamic_start
    add x3, x3, #:lo12:__dynamic_start
    bl __crystal_nx_init
    cmp x0, 0
    b.ne svcReturnFromException

    adrp x30, svcExitProcess
    add x30, x30, #:lo12:svcExitProcess
    b main

.section .data.mod0
rela_test:
    .ascii "Hello from RELA"
rela_test_size:
    .word 15

_mod_header:
    .ascii "MOD0"
    .word __dynamic_start - _mod_header
    .word __bss_start - _mod_header
    .word __bss_end - _mod_header
    .word 0, 0 // eh_frame_hdr start/end
    .word 0 // runtime-generated module object offset
