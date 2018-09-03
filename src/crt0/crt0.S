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
.global tranpoline
tranpoline:
    mov w0, #0xDEAD
    svc 0x7 // Exit
