.section .crt0, "ax"
NORELOC__filestart:
.global _start

_start:
    b tranpoline
    .word _mod_header - _start

.section .data.mod0
.global _mod_header

_mod_header:
    .ascii "MOD0"
    .word __dynamic_start - _mod_header
    .word __bss_start - _mod_header
    .word __bss_end - _mod_header
    .word 0, 0 // eh_frame_hdr start/end
    .word 0 // runtime-generated module object offset

.section .text, "x"
.extern svcExitProcess
tranpoline:

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

// After that we need to relocate
startup:
    adrp x0, _start
    bl main
    svc 0xFF // Exit
