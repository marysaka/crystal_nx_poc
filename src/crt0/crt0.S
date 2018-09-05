.global _start
.global _mod_header
.global rela_test
.global rela_test_size

.extern __crystal_nx_entrypoint
.extern svcExitProcess
.extern svcReturnFromException

.section .text.crt0, "ax"
_start:
    b tranpoline
    .word _mod_header - _start

.section .text, "x"
tranpoline:
    // prepare args
    adrp x2, _start
    add x2, x2, #:lo12:_start
    adrp x3, __dynamic_start
    add x3, x3, #:lo12:__dynamic_start
    adrp x4, __bss_start
    add x4, x4, #:lo12:__bss_start
    adrp x5, __bss_end
    add x5, x5, #:lo12:__bss_end

    // because I cannot use NoReturn directly in crystal code, let's cheat a bit and make it return to the exit directly
    adrp x30, svcExitProcess
    add x30, x30, #:lo12:svcExitProcess
    b __crystal_nx_entrypoint

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
    .word __eh_frame_start - _mod_header
    .word __eh_frame_end - _mod_header
    .word 0 // runtime-generated module object offset
