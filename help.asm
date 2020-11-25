; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

           org     8000h
           lbr     0ff00h
           db      'help',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0
 
           org     2000h
           br      start

include    date.inc

start:     mov     rf,hlpfile          ; where to copy filename            
loop1:     lda     ra                  ; look for first less <= space
           str     rf                  ; store for later
           inc     rf
           smi     33
           bdf     loop1
           dec     rf
           ldi     '.'                 ; add extension
           str     rf
           inc     rf
           ldi     'h'
           str     rf
           inc     rf
           ldi     'l'
           str     rf
           inc     rf
           ldi     'p'
           str     rf
           inc     rf
           ldi     0
           str     rf
           mov     rf,hlpfile          ; point back to beginning of name
           mov     rd,fildes           ; get file descriptor
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           bnf     opened              ; jump if file was opened
           mov     rf,hlpdir           ; try from /HLP/
           mov     rd,fildes
           ldi     0
           plo     r7
           sep     scall
           dw      o_open
           bnf     opened
           mov     rf,library          ; lastly check in help library
           mov     rd,fildes           ; get file descriptor
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open
           dw      o_open
           lbnf    chklib              ; jump to check library

           ldi     high errmsg         ; get error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           lbr     o_wrmboot           ; and return to os
opened:    mov     rb,rd               ; make copy of descriptor
           mov     rf,buffer           ; point to buffer

           ldi     0
           phi     r7
           plo     r7

mainlp:    ldi     0                   ; want to read 16 bytes
           phi     rc
           ldi     16
           plo     rc 
           mov     rf,buffer           ; buffer to retrieve data
           mov     rd,rb               ; get descriptor
           sep     scall               ; read bytes
           dw      o_read
           glo     rc                  ; check for zero bytes read
           lbz     done                ; jump if so
           mov     r8,buffer           ; point to read data
linelp:    lda     r8                  ; get next byte
           sep     scall 
           dw      o_type
           dec     rc                  ; decrement read count
           glo     rc                  ; see if done
           lbnz    linelp              ; loop back if not
           lbr     mainlp              ; and loop back til done

done:      sep     scall               ; close the file
           dw      o_close
           lbr     o_wrmboot           ; return to os

chklib:    mov     ra,hlpfile          ; point to desired helpfile name
chklib_1:  mov     rf,dskbuffer        ; point to disk buffer
           mov     rc,1                ; read 1 byte
           mov     rd,fildes           ; point to file descriptor
           sep     scall               ; read next byte
           dw      o_read
           lbdf    nope                ; jump on error
           glo     rc                  ; and if no bytes read
           lbz     nope
           mov     rf,dskbuffer        ; point back to disk buffer
           ldn     rf                  ; see if end of name
           lbz     chklib_2            ; jump if so
           str     r2                  ; store for comparison
           ldn     ra                  ; get byte from filename
           sm                          ; check for match
           lbnz    chklib_3            ; jump if no match
           inc     ra                  ; point to next byte
           lbr     chklib_1            ; check next byte
chklib_3:  mov     rf,dskbuffer        ; loop until a zero found
           mov     rc,1
           mov     rd,fildes
           sep     scall               ; read next byte
           dw      o_read
           lbdf    nope                ; jump on error
           glo     rc                  ; and if no bytes read
           lbz     nope
           mov     rf,dskbuffer
           ldn     rf                  ; check for zero
           lbnz    chklib_3            ; read more if not zero
chklib_4:  mov     rf,dskbuffer        ; read next 5 bytes
           mov     rc,5
           sep     scall
           dw      o_read
           lbdf    nope                ; jump on error
           glo     rc                  ; and if no bytes read
           lbz     nope
           mov     rf,dskbuffer+1      ; get size of entry
           lda     rf                  ; read into R8:R7
           phi     r8
           lda     rf
           plo     r8
           lda     rf
           phi     r7
           lda     rf
           plo     r7
           mov     rc,1                ; seek from current position
           mov     rd,fildes
           sep     scall               ; perform file seek
           dw      o_seek
           lbr     chklib              ; loop back to check next entry
chklib_2:  ldn     ra                  ; get byte from filename
           lbnz    chklib_4            ; not correct entry
           mov     rf,dskbuffer        ; read next 5 bytes
           mov     rc,5
           mov     rd,fildes
           sep     scall               ; read them
           dw      o_read
           lbdf    nope                ; jump on error
           glo     rc                  ; and if no bytes read
           lbz     nope
           mov     rf,dskbuffer+1      ; get size of entry
           lda     rf                  ; read into R8:R7
           phi     r8
           lda     rf
           plo     r8
           lda     rf
           phi     r7
           lda     rf
           plo     r7
           mov     rc,r7               ; size of entry
           mov     rf,dskbuffer        ; where to load it
           mov     rd,fildes           ; point to descriptor
           sep     scall               ; read entry
           dw      o_read
           lbdf    nope                ; jump on error
           glo     rc                  ; and if no bytes read
           lbz     nope
           mov     rf,dskbuffer        ; point to buffer
entrylp:   lda     rf                  ; get byte from data
           sep     scall               ; display it
           dw      f_type
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    entrylp             ; loop back if more to display
           ghi     rc
           lbnz    entrylp             ; loop back if more to display
           lbr     o_wrmboot
nope:      sep     scall               ; display error
           dw      f_inmsg
           db      'Not found',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS

           

library:   db      '/hlp/hlp.lbr',0
errmsg:    db      'File not found',10,13,0
fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0
hlpdir:    db      '/hlp/'
hlpfile:   db      0

endrom:    equ     $

           org     03000h
buffer:    equ     $
dta:       equ     buffer+20
dskbuffer: equ     dta+512

