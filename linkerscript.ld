/* Minimal Cortex-M7 layout: flash at 0x08000000, one RAM region at
 * 0x20000000 holding .data, .bss, the heap (picolibc's sbrk reads
 * __heap_start/__heap_end) and the stack at the top. The image is only
 * linked, never flashed. */

MEMORY
{
  flash (rx) : ORIGIN = 0x08000000, LENGTH = 2048K
  ram (rwx)  : ORIGIN = 0x20000000, LENGTH = 512K
}

SECTIONS
{
  .vectors ORIGIN(flash) : { KEEP(*(.vectors*)) } > flash
  .text    : { *(.text*) . = ALIGN(16); } > flash
  .rodata  : { *(.rodata*) *(.got*) } > flash

  /* .data first, then .bss (ResetISR copies .data and zeroes .bss); an
   * explicit AT() so the linker cannot open a gap before .data's LMA. */
  .data    : AT(ADDR(.rodata) + SIZEOF(.rodata)) ALIGN(4) { *(.data*) } > ram

  __data_start       = ADDR(.data);
  __flash_data_start = LOADADDR(.data);
  __flash_data_len   = SIZEOF(.data);

  . = (. + 3) & ~ 3;
  __bss_start = .;
  .bss     : { *(.bss*) } > ram
  .tbss    : { *(.tbss*) } > ram
  __bss_end = (ADDR(.tbss) + SIZEOF(.tbss) + 3) & ~ 3;

  /DISCARD/ : { *(.swift_modhash*) }
  /DISCARD/ : { *(.ARM.attributes*) *(.ARM.exidx) *(.ARM.exidx.*) *(.ARM.extab*) }
  /DISCARD/ : { *(.eh_frame) *(.eh_frame_hdr) }

  .symtab   : { *(.symtab) }
  .strtab   : { *(.strtab) }
  .shstrtab : { *(.shstrtab) }
  .debug    : { *(.debug*) }
  .comment  : { *(.comment) }
}

__heap_start  = __bss_end;
__heap_end    = ORIGIN(ram) + LENGTH(ram) - 64K;
__stack_start = __heap_end;
__stack_end   = ORIGIN(ram) + LENGTH(ram);
