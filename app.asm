;;--------------------------------------------------------------
;;-- app.asm
;;-- Application level program, makes system calls.
;;--------------------------------------------------------------

.ORIG x1000     ;;-- loads to first page of user memory.

TRAP x23 ;;—- open window
TRAP x25 ;;—- HALT command

.END