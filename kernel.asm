;;-----------------------------------------------------------
;;-- kernel.asm
;;-- Kernel starts in main() and begins its initialization phase.
;;-- That phase calls each service's initialization routine,
;;-- then jumps to the user-level program.
;;-------------------------------------------------------------

.ORIG x8000					;;-- Load at start of kernel space.

;------- kernel main() ----------------
_main:
	JSR _init_getc           ;;—-   initialization phase.
	JSR _init_putc           ;;--   initialization phase.
	JSR _init_putc_graphic   ;;—-   initialization phase. 
	JSR _init_window         ;;—-   initialization phase. 
	LD  R7 USER_start        ;;--   prepare to jump to user.
	JMP R7                   ;;--   jump to USER space at x1000.

	USER_start: .FILL x1000  ;;--   pointer to USER space.

;;------ init_putc() --------------
_init_putc:
	LD  R1 putc_TVT          ;;--   R1 <=== TVT slot address.
	LD  R0 putc_ptr          ;;--   R0 <=== putc()'s address.
	STR R0 R1 #0             ;;--   write VT: R0 ===> MEM[R1].
	jmp R7                   ;;--   return to kernel main().

	putc_TVT:   .FILL x0007  ;;--   points to putc()'s TVT slot.
	putc_ptr:   .FILL _putc  ;;--   points to putc().

;;------ _putc( R0 ) ------------------
_putc:
	ST R1 saved_R1          ;;--   save caller's R1 register.
	poll:                   ;;--   Do
	LDI R1 DSR_ptr          ;;--     read the DSR, R1 <=== DSR;
	BRzp poll               ;;--   until ready, DSR[15] == 1.
	STI R0 DDR_ptr          ;;--   display char, DDR <=== R0.
	LD R1 saved_R1          ;;--   restore caller's R1.
	JMP R7                  ;;--   return to caller.

	DDR_ptr:  .FILL xFE06   ;;--   points to DDR.
	DSR_ptr:  .FILL xFE04   ;;--   points to DSR.
	saved_R1: .FILL x0000   ;;--   space for caller's R1.

;;------ init_getc() --------------
_init_getc:
	LD  R1 getc_TVT          ;;--   R1 <=== TVT slot address.
	LD  R0 getc_ptr          ;;--   R0 <=== getc()'s address.
	STR R0 R1 #0             ;;--   write VT: R0 ===> MEM[R1].
	jmp R7                   ;;--   return to kernel main().

	getc_TVT:   .FILL x0020  ;;--   points to getc()'s TVT slot.
	getc_ptr:   .FILL _getc  ;;--   points to getc().

;;------ _getc() ------------------
_getc:
	ST R1 saved_R1          ;;--   save caller's R1 register.
	inputPoll:              ;;--   Do
	LDI R1 KBSR_ptr         ;;--       read the KBSR, R1 <=== KBSR;
	BRzp inputPoll          ;;--   until ready, KBSR[15] == 1.
	LDI R0 KBDR_ptr         ;;--   get char, R0 <=== KBDR.
	LD R1 saved_R1          ;;--   restore caller's R1.
	JMP R7                  ;;--   return to caller.

	KBDR_ptr:  .FILL xFE02  ;;--   points to KBDR.
	KBSR_ptr:  .FILL xFE00  ;;--   points to KBSR.

;;------ init_putc_graphic() --------------
_init_putc_graphic:
	LD  R1 putc_graphic_TVT          		;;--   R1 <=== TVT slot address.
	LD  R0 putc_graphic_ptr          		;;--   R0 <=== putc_graphic()’s address.
	STR R0 R1 #0                     		;;--   write VT: R0 ===> MEM[R1].
	jmp R7                           		;;--   return to kernel main().

	putc_graphic_TVT:   .FILL x0021  		;;--   points to putc_graphic()’s TVT slot.
	putc_graphic_ptr:   .FILL _putc_graphic 	;;--   points to putc_graphic().

;;------ _putc_graphic( R0, R1 ) ------------------
;;R0:inputChar, R1:cursorLocation, R5:temporary storage of numbers
_putc_graphic:
	ST R0 putcg_saved_R0
	ST R1 putcg_saved_R1
	ST R2 putcg_saved_R2
	ST R3 putcg_saved_R3
	ST R4 putcg_saved_R4
	ST R5 putcg_saved_R5

	;;—- Identify char to display (R2).
	;;—- diff = R0 - x0020
	LD R5 start_char
	ADD R2 R0 R5 ;;—-  R2 <=== R0 - x0020.
	
	;;—- Identify memory location of graphic to display
	;;—- pixelToWrite = GraphicsTableBase + (diff*7*9)
	;;—- R3 = graphics_table_base + (R2 * 63)
	LD R3 graphics_table_base ;;—- R3 <=== graphics_table_base
	AND R4 R4 #0 ;;—- R4 <=== 0
	LD R5 pixelNum
	ADD R4 R4 R5 ;;—- R4 <=== 63

;;—- adds 63*diff to graphics_table_base (R4 starts at 63, R2 has diff, R3 starts at graphics_table_base)
MULT	
	ADD R3 R3 R2
	ADD R4 R4 #-1
	BRp MULT

	;;—- now R3 has the address of pixelToWrite
	AND R2 R2 #0
	ADD R2 R2 R3
	AND R3 R3 #0
	;;—- now R2 has the address of pixelToWrite, and R3 = 0

	;;-- R3 is the row (starting at 1)
	AND R3 R3 #0
	ADD R3 R3 #1 ;;—- R3 <=== 1
    
	;;—- R0 will now be used for temporary storage
TEST_ROW	
	ADD R0 R3 #-9
	BRp DONE ;;—- we are finished when row (R3) is at least 10

	;;—- R4 is the column (starting at 1)
	AND R4 R4 #0
	ADD R4 R4 #1 ;;—- R4 <=== 1

	;;— R0 used as temporary storage when testing column number (R4)
TEST_COL	
	ADD R0 R4 #-7
	BRnz CURSOR ;—-column less than or equal to 7 
	;—- column at least 8 (time to move down a row)
	LD R5 newRow
	ADD R1 R1 R5 ;—- cursorLocation += 121 (go to start of next pixel line)
	ADD R3 R3 #1   ;—- row++
	BRnzp TEST_ROW ;—- go check if row is less than or equal to 9

;—- R1 has cursorLocation
;—- R2 has pixelToWrite’s address
CURSOR	
	;—- M[R1] <=== M[R2], M[cursor] <=== M[pixelToWrite]
	LDR R0 R2 #0
	STR R0 R1 #0
	;—- col++
	ADD R4 R4 #1
	;—- cursor++
	ADD R1 R1 #1
	;— pixelToWrite address ++
	ADD R2 R2 #1
	BRnzp TEST_COL    

DONE	
	;;—- restore caller registers
	LD R0 putcg_saved_R0
	LD R1 putcg_saved_R1
	LD R2 putcg_saved_R2
	LD R3 putcg_saved_R3
	LD R4 putcg_saved_R4
	LD R5 putcg_saved_R5
	;;— go back to main
	JMP R7

;—-space for caller's registers.
putcg_saved_R0: .FILL x0000
putcg_saved_R1: .FILL x0000
putcg_saved_R2: .FILL x0000
putcg_saved_R3: .FILL x0000
putcg_saved_R4: .FILL x0000
putcg_saved_R5: .FILL x0000

start_char: .FILL #-32 ;;—- -x0020, negative of ASCII code for first character in graphics table
pixelNum: .FILL #63 ;;—- 7*9 = 63, number of pixels per letter
newRow: .FILL #121 ;;—- number of pixels to go in order to start at beginning of next row

graphics_table_base .FILL graphics_table ;;—- points to base of graphics table

;;------ init_window() --------------
_init_window:
	LD  R1 window_TVT          			;;--   R1 <=== TVT slot address.
	LD  R0 window_ptr          			;;--   R0 <=== window()’s address.
	STR R0 R1 #0                     	;;--   write VT: R0 ===> MEM[R1].
	jmp R7                           	;;--   return to kernel main().
		                     	     	;;--
	window_TVT:   .FILL x0023  			;;--   points to window()’s TVT slot.
	window_ptr:   .FILL _window  		;;--   points to window().

;;------ _window() ------------------
;;R0:inputChar, R1:cursorLocation, R5:temporary storage of numbers

_window:
	ST R0 w_saved_R0
	ST R1 w_saved_R1
	ST R2 w_saved_R2
	ST R3 w_saved_R3
	ST R5 w_saved_R5
	ST R7 w_saved_R7

	;;—- store beginning of printing window into R1 (cursorLocation = xCE93)
	AND R1 R1 #0 
	LD R5 start_window 
	ADD R1 R1 R5
	;;—- R1 (cursorLocation) now has xCE93

	;;—- R2 is the number of rows left, initialized to 4
	AND R2 R2 #0
	ADD R2 R2 #4

INSPECT_ROW	
		ADD R2 R2 #0 ;;—- make numRows branch condition
		BRz FINISH   ;;—- finished if no more rows available
		;;—- R3 is the number of spaces left in the row, initialized to 12
		AND R3 R3 #0
		ADD R3 R3 #12

INSPECT_COL	
		ADD R3 R3 #0 ;;—- make number of spaces left branch condition
		BRz NEW_LINE ;;—- new line if out of space in current line
		TRAP x20 ;;—- call getc
		TRAP x21 ;;—- call putc_graphic
		ADD R1 R1 #7 ;;—- cursor += 7
		ADD R3 R3 #-1 ;;—- numSpaces—-
		BRnzp INSPECT_COL

NEW_LINE	
		LD R5 next_line ;;—- R5 <=== ((128*8) + 44) = x042C
		ADD R1 R1 R5 ;;—- cursor += ((128*8) + 44)
		ADD R2 R2 #-1 ;;—- numRows—-
		BRnzp INSPECT_ROW

FINISH	
		;;—- restore caller registers
		LD R0 w_saved_R0
		LD R1 w_saved_R1
		LD R2 w_saved_R2
		LD R3 w_saved_R3
		LD R5 w_saved_R5
		LD R7 w_saved_R7
		;;— go back to main
		JMP R7

;;—-space for caller's registers.
w_saved_R0: .FILL x0000
w_saved_R1: .FILL x0000
w_saved_R2: .FILL x0000
w_saved_R3: .FILL x0000
w_saved_R5: .FILL x0000
w_saved_R7: .FILL x0000

start_window: .FILL xCE93 ;;—- (xC000 + (29*128) + 19), start of cursor
next_line: .FILL x042C ;;—- ((128*8) + 44), number of pixel positions to add to get to beginning of next line



;;------ graphics_table ------------------
graphics_table:

x20row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x20row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x21row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x21row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x22row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x22row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x22row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x22row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x22row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x22row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x22row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x22row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x22row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x23row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x23row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x23row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x23row3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x23row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x23row5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x23row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x23row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x23row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x24row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x24row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x24row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x24row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x24row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x24row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x24row6: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x24row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x24row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x25row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x25row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x25row2: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x25row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x25row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x25row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x25row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff

x25row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff

x25row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x26row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x26row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x26row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x26row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x26row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x26row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x26row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x26row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x26row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x27row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x27row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x28row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x28row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x28row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x28row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x29row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x29row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x29row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x29row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x29row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x29row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x29row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x29row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x29row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2arow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2arow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2arow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x2arow4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x2arow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x2arow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2arow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x2brow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x2drow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x2frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x2frow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x2frow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x2frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x30row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x30row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x30row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x30row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x30row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x30row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x30row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x30row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x30row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x31row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x31row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x31row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x32row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x32row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x32row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x32row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x32row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x32row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x32row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x32row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x32row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x33row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x33row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x33row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x33row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x33row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x33row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x33row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x33row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x33row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x34row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x34row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x34row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x34row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x35row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x35row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x35row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x35row3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x35row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x35row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x35row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x35row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x35row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x36row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x36row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x36row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x36row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x36row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x36row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x36row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x36row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x36row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x37row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x37row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x37row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x37row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x37row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x37row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x37row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x37row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x37row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x38row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x38row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x38row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x38row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x38row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x38row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x38row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x38row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x38row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x39row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x39row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x39row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x39row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x39row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x39row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x39row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x39row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x39row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3crow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3crow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x3drow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x3drow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3erow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3erow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3erow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3erow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x3erow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3erow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3erow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x3frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3frow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3frow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x3frow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x3frow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x3frow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3frow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3frow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x3frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x40row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x40row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x40row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x40row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x40row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x40row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x40row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x40row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x40row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x41row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x41row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x41row2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x41row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x41row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x41row5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x41row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x41row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x41row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x42row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x42row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x42row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x42row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x42row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x42row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x42row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x42row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x42row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x43row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x43row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x43row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x43row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x43row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x43row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x43row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x43row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x43row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x44row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x44row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x44row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x44row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x44row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x44row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x44row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x44row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x44row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x45row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x45row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x45row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x45row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x45row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x45row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x45row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x45row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x45row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x46row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x46row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x46row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x46row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x47row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x47row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x47row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x47row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x47row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x47row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x47row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x47row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x47row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x48row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x48row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x48row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x48row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x49row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x49row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x49row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x49row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4arow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x4arow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4arow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4arow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4arow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4arow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4arow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4brow1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4brow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4brow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4brow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4brow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4brow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4brow7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4crow7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x4crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4drow1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow2: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff

x4drow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4erow1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff

x4erow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x4frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x4frow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4frow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4frow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4frow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4frow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4frow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x4frow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x4frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x50row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x50row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x50row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x50row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x50row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x50row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x50row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x50row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x50row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x51row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x51row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x51row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x51row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x51row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x51row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x51row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x51row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x51row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x52row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x52row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x52row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x52row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x52row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x52row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x52row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x52row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x52row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x53row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x53row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x53row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x53row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x53row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x53row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x53row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x53row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x53row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x54row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x54row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x54row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x55row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x55row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x55row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x55row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x56row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x56row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x56row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x56row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x56row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x56row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x56row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x56row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x56row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x57row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x57row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x57row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x57row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x58row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x58row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x58row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x58row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x58row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x58row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x58row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x58row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x58row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x59row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x59row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x59row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x59row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x59row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x59row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x59row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x59row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x59row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5arow1: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x5arow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x5arow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5arow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5arow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5arow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5arow7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x5arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5brow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5brow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5crow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x5crow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5drow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x5erow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x5erow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x5frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x5frow7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x5frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x60row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x60row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x60row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x61row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x61row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x61row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x61row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x61row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x61row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x61row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x61row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x61row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x62row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x62row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x62row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x62row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x62row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x62row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x62row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x62row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x62row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x63row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x63row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x63row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x63row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x64row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x64row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x64row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x64row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x64row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x64row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x64row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x64row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x64row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x65row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x65row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x65row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x65row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x65row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x65row5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x65row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x65row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x65row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x66row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x66row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x66row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x66row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x66row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x66row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x66row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x66row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x66row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x67row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x67row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x67row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x67row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x67row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x67row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x67row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x67row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x67row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x68row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x68row1: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x68row2: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x68row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x68row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x68row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x68row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x68row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x68row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x69row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x69row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6arow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6arow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6arow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6arow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6arow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6arow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6arow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6brow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6brow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6brow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6brow4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6brow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6brow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6brow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6crow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6drow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6drow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6drow3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff

x6drow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6drow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6drow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6drow7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6erow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6erow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6erow3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6erow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6erow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6erow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6erow7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x6frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6frow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6frow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x6frow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6frow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6frow5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6frow6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x6frow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x6frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x70row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x70row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x70row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x70row3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x70row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x70row5: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x70row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x70row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x70row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x71row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x71row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x71row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x71row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x71row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x71row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x71row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x71row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x71row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x72row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x72row4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x72row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x72row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x73row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x73row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x73row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x73row3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x73row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x73row5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x73row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x73row7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x73row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x74row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x74row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x74row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x74row3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x74row4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x74row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x74row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x74row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x74row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x75row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x75row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x75row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x75row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x75row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x75row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x75row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x75row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x75row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x76row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x76row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x76row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x76row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x76row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x76row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x76row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x76row7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x76row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x77row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x77row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x77row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x77row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x77row4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x77row5: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x77row6: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff

x77row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x77row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x78row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x78row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x78row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x78row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x78row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x78row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x78row6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x78row7: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x78row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x79row0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row3: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x79row4: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x79row5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x79row8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7arow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7arow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7arow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7arow3: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x7arow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7arow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7arow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7arow7: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x7arow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7brow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7brow2: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow4: .FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow6: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7brow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7brow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7crow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7crow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7drow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7drow1: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7drow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7drow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7drow4: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff

x7drow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7drow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7drow7: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7drow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7erow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7erow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7erow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7erow3: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7erow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x7erow5: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff

x7erow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7erow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7erow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
x7frow0: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow1: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow2: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow3: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow4: .FILL x7fff
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7c00
.FILL x7fff

x7frow5: .FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow6: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7c00
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow7: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

x7frow8: .FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff
.FILL x7fff

.END