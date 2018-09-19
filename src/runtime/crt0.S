.global _start
.global _mod_header
.global loader_return_address

.extern __crystal_nx_entrypoint

.section .text.crt0, "ax"
_start:
    b tranpoline
    .word _mod_header - _start

.section .text, "x"
tranpoline:

    // backup stack position
    mov  x2, sp
    adrp x3, previous_stack
    str  x2, [x3, #:lo12:previous_stack]

    // backup lr and set argument for loader_return_address
    mov x2, lr
    adrp x6, loader_return_address
    add x6, x6, #:lo12:loader_return_address
    str  x2, [x6]

    // prepare the others args
    adrp x2, _start
    add x2, x2, #:lo12:_start
    adrp x3, __dynamic_start
    add x3, x3, #:lo12:__dynamic_start
    adrp x4, __bss_start
    add x4, x4, #:lo12:__bss_start
    adrp x5, __bss_end
    add x5, x5, #:lo12:__bss_end

    // because I cannot use NoReturn directly in crystal code, let's cheat a bit and make it return to the exit directly
    adrp x30, exit_point
    add x30, x30, #:lo12:exit_point
    b __crystal_nx_entrypoint
exit_point:
    // restore stack position
    adrp x3, previous_stack
    ldr  x3, [x3, #:lo12:previous_stack]
    mov  sp, x3

    // get the return pointer
    adrp x1, loader_return_address
    ldr  x1, [x1, #:lo12:loader_return_address]

    // branch to it
    br x1

.section .data
previous_stack:
    .word 0
    .word 0
loader_return_address:
    .word 0
    .word 0

.section .data.mod0
_mod_header:
    .ascii "MOD0"
    .word __dynamic_start - _mod_header
    .word __bss_start - _mod_header
    .word __bss_end - _mod_header
    .word __eh_frame_start - _mod_header
    .word __eh_frame_end - _mod_header
    .word 0 // runtime-generated module object offset
