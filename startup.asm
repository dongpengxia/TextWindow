;;--------------------------------------------------------------
;;-- startup.asm
;;-- Runs at power-on. Jumps to the kernel after initialization.
;;-- R6 is the Stack Pointer (SP).
;;--------------------------------------------------------------

.ORIG x0200                  ;;-- Load to boot area.

_boot:
    LD  R6 krnl_stack        ;;--   Set SP to operating system stack area.
    LD  R7 krnl_main         ;;--   R7 <=== kernel main() address.
    JMP R7                 	 ;;--   jump to kernel main().

    krnl_stack: .FILL xC000  ;;--   address operating system stack area.
    krnl_main: .FILL x8000   ;;--   points to kernel main().

.END