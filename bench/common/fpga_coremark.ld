OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

SECTIONS {
  .text : {
    KEEP(*(.text.init))
    *(.text*)
    *(.rodata*)
    *(.srodata*)
    . = ALIGN(4);
  } > RAM

  _data_lma = .; 

  .data : {
    _data_start = .;
    *(.data*)
    *(.sdata*)
    . = ALIGN(4);
    _data_end = .;
  } > RAM

  .bss (NOLOAD) : {
    _bss_start = .;
    *(.sbss*)
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > RAM

  _end = .;
  _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 16;

  /DISCARD/ : {
    *(.riscv.attributes)
    *(.comment)
    *(.eh_frame)
    *(.note*)
  }
}
