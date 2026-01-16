/* link/rpi4.ld - minimal AArch64 kernel linker script */
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)
ENTRY(_start)

/* Load address: QEMU -kernel loads the raw image at 0x80000 for raspi boards in practice.
   This is a common convention for Pi bare-metal kernels. */
SECTIONS
{
  . = 0x0000000000080000;

  /* Code */
  .text : ALIGN(16)
  {
    KEEP(*(.text.boot))     /* if you place _start here */
    *(.text .text.*)
  }

  /* Read-only data */
  .rodata : ALIGN(16)
  {
    *(.rodata .rodata.*)
  }

  /* Initialized data */
  .data : ALIGN(16)
  {
    *(.data .data.*)
  }

  /* Zero-initialized data */
  .bss : ALIGN(16)
  {
    __bss_start = .;
    *(.bss .bss.*)
    *(COMMON)
    __bss_end = .;
  }

  /* Simple symbols you’ll use in boot.S */
  __kernel_end = .;

  /DISCARD/ :
  {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
    *(.eh_frame_hdr*)
  }
}
