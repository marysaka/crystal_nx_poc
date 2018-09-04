OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)
ENTRY(_start)

PHDRS
{
  text PT_LOAD FLAGS(5);
  rodata PT_LOAD FLAGS(4);
  data PT_LOAD FLAGS(6);
  bss PT_LOAD FLAGS(6);
  dynamic PT_DYNAMIC;
}

SECTIONS
{
  . = 0;

  .crt0 : {
    KEEP(*(.crt0))
  } :text

  . = 0x80;
  .text : {
    HIDDEN(__text_start = .);

    *(.text .text.*)
    *(.plt .plt.*)
    HIDDEN(__text_end = .);
  } :text

  /* Read-only sections */

  . = ALIGN(0x1000);

  .rodata : { *(.rodata .rodata.*) } :rodata
  .hash : { *(.hash) }
  .dynsym : { *(.dynsym .dynsym.*) }
  .dynstr : { *(.dynstr .dynstr.*) }
  .rela.dyn : { *(.rela.dyn) }

  .eh_frame : ONLY_IF_RO {
    HIDDEN(__eh_frame_start = .);
    KEEP (*(.eh_frame)) *(.eh_frame.*)
    HIDDEN(__eh_frame_end = .);
  }

  .eh_frame_hdr : {
    HIDDEN(__eh_frame_hdr_start = .);
    *(.eh_frame_hdr) *(.eh_frame_entry .eh_frame_entry.*)
    HIDDEN(__eh_frame_hdr_end = .);
  }
  .gcc_except_table : ONLY_IF_RO { *(.gcc_except_table .gcc_except_table.*) }
  .gnu_extab : ONLY_IF_RO { *(.gnu_extab*) }

  /* Read-write sections */

   . = ALIGN(0x1000);

  .mod0 : {
    KEEP(crt0.o(.data.mod0))
  } :data

  .data : {
    *(.data .data.*)
    *(.got .got.*)
    *(.got.plt .got.plt.*)
  } :data

  .eh_frame : ONLY_IF_RW {
    HIDDEN(__eh_frame_start = .);
    KEEP (*(.eh_frame)) *(.eh_frame.*)
    HIDDEN(__eh_frame_end = .);
  }
  .gnu_extab : ONLY_IF_RW { *(.gnu_extab*) }
  .gcc_except_table : ONLY_IF_RW { *(.gcc_except_table .gcc_except_table.*) }

  .dynamic : {
    HIDDEN(__dynamic_start = .);
    *(.dynamic)
  } :dynamic :data

  /* BSS section */

  . = ALIGN(0x1000);

  .bss : {
    HIDDEN(__bss_start = .);
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(8);
    HIDDEN(__bss_end = .);
  } :bss
}
