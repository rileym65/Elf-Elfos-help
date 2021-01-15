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
include    build.inc
           db      'Written by Michael H. Riley',0

start:     lda     ra                  ; read byte from command line
           smi     ' '                 ; see if it is a space
           bz      start               ; move past any spaces
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; retrieve byte
           lbz     listbase            ; if no argument, list base lib
           smi     '-'                 ; check for switch
           lbnz    start2              ; jump if not
           inc     ra                  ; point to next character
           ldn     ra                  ; retrieve it
           smi     'c'                 ; must be c
           lbz     listcat             ; list categories
           sep     scall               ; otherwise show error
           dw      o_inmsg
           db      'Invalid switch',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS
start2:    sep     scall               ; see if category is provided
           dw      hascat
           ldn     ra                  ; get next byte of input
           lbnz    nocat               ; jump if topic specified
           mov     rf,catdir           ; point to category
           sep     scall               ; open library
           dw      openlib
           lbnf    listlib             ; if opened, jumpt to list
           sep     scall               ; otherwise display error
           dw      o_inmsg
           db      'Category not found',10,13,0
           lbr     o_wrmboot           ; and return to Elf/OS
nocat:     mov     rf,hlpfile          ; where to copy filename            
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
           mov     r7,cat              ; see if category specified
           ldn     r7                  ; get flag
           lbz     nocat1              ; jump if no category
           mov     rf,catdir           ; point to category filename
           lbr     catyes              ; and process through library
nocat1:    mov     rf,hlpfile          ; point back to beginning of name
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
catyes:    sep     scall               ; open base library
           dw      openlib
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
           ldn     rf                  ; check also XMODEM eof
           smi     01ah
           lbz     nope
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
           dw      o_type
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    entrylp             ; loop back if more to display
           ghi     rc
           lbnz    entrylp             ; loop back if more to display
           lbr     o_wrmboot
nope:      sep     scall               ; display error
           dw      o_inmsg
           db      'Not found',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS

listbase:  mov     rf,library          ; lastly check in help library
           sep     scall               ; open library
           dw      openlib
           lbnf    listlib             ; if opened, jumpt to list
           sep     scall               ; otherwise display error
           dw      o_inmsg
           db      'Usage: help [category:]topic',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS

listlib:   sep     scall               ; display message
           dw      o_inmsg
           db      'Available topics:',10,13,0
lst_nmlp:  ldi     high buffer      ; point to buffer
           phi     rf
           ldi     low buffer 
           plo     rf
           ldi     0                   ; need to read 1 byte
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; read a byte
           dw      o_read
           lbdf    lst_done            ; jump if end of file
           glo     rc                  ; check read count
           lbz     lst_done            ; jump if end of file
           ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer 
           plo     rf
           ldn     rf                  ; check for XMODEM eof
           smi     01ah
           lbz     lst_done            ; jump if so
           ldn     rf                  ; get read byte
           lbz     lst_nmdn            ; jump if end of name found
           sep     scall               ; otherwise display it
           dw      o_type
           lbr     lst_nmlp            ; and keep going
lst_nmdn:  sep     scall               ; move to next screen line
           dw      crlf
           ldi     high buffer      ; point to buffer
           phi     rf
           ldi     low buffer 
           plo     rf
           ldi     0                   ; need to read 5 bytes
           phi     rc
           ldi     5
           plo     rc
           sep     scall               ; read a byte
           dw      o_read
           lbdf    lst_done            ; jump if end of file
           glo     rc
           smi     5
           lbnz    lst_done
           ldi     high buffer      ; point to buffer
           phi     rf
           ldi     low buffer 
           plo     rf
           inc     rf                  ; move past flags byte
           lda     rf                  ; retrieve element size
           phi     r8
           lda     rf
           plo     r8
           lda     rf
           phi     r7
           lda     rf
           plo     r7
           ldi     0                   ; select seek from current
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; seek file position
           dw      o_seek
           lbr     lst_nmlp            ; process next entry
lst_done:  sep     scall               ; display a final CR/LF
           dw      crlf
           lbr     o_wrmboot           ; then back to Elf/OS
crlf:      ldi     10                  ; send a LF
           sep     scall
           dw      o_type
           ldi     13                  ; send a CF
           sep     scall
           dw      o_type
           sep     sret                ; return to calelr



; ****************************************
; ***** Open library specified by RF *****
; ****************************************
openlib:   mov     rd,fildes           ; get file descriptor
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open
           dw      o_open
           sep     sret                ; return to caller

; ******************************************
; ***** Check if category is specified *****
; ******************************************
hascat:    mov     rf,ra               ; copy address
           mov     r7,catfile          ; point to cat file
hascatlp:  lda     rf                  ; get byte from argument
           str     r7                  ; store into cat file
           inc     r7
           plo     re                  ; save character
           smi     33                  ; check for space or less
           lbnf    hascatno            ; jump if space or terminator
           glo     re                  ; check for 
           smi     ':'                 ; check for colon
           lbnz    hascatlp            ; loop back to keep testing
           dec     r7                  ; need to overwrite : in catfile
           ldi     '.'                 ; replace with .lbr
           str     r7
           inc     r7
           ldi     'l'
           str     r7
           inc     r7
           ldi     'b'
           str     r7
           inc     r7
           ldi     'r'
           str     r7
           inc     r7
           ldi     0
           str     r7
           mov     r7,cat              ; need to mark category found
           ldi     0ffh
           str     r7
           mov     ra,rf               ; name now starts after colon
           sep     sret                ; return to caller
hascatno:  mov     r7,cat              ; mark no category found
           ldi     0                   ; signal no category
           str     r7
           sep     sret                ; and return

listcat:   mov     rf,catfile          ; terminate directory name
           ldi     0
           str     rf
           mov     rf,catdir           ; point to pathname
           mov     rd,fildes
           sep     scall               ; open the directory
           dw      o_opendir
           lbnf    listcatlp           ; jump if good
           sep     scall               ; otherwise display error
           dw      o_inmsg
           db      'Could not open /hlp/',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS
listcatlp: mov     rf,dskbuffer        ; point to input buffer
           mov     rc,32               ; need to read 32 bytes
           sep     scall               ; read them
           dw      o_read
           glo     rc                  ; see if all bytes read
           smi     32
           lbnz    listcatdn           ; done if eof
           mov     rf,dskbuffer        ; point back to buffer
           lda     rf                  ; see if valid entry
           lbnz    listcatgd
           lda     rf
           lbnz    listcatgd
           lda     rf
           lbnz    listcatgd
           lda     rf
           lbz     listcatlp           ; loop back if open entry
listcatgd: sep     scall               ; see if pointing at a .lbr
           dw      chklbr
           lbnf    listcatlp           ; loop back if not
           mov     rf,dskbuffer+12     ; point to filename
listcatg1: lda     rf                  ; get byte
           lbz     listcatg2           ; jump if done
           sep     scall               ; otherwise display it
           dw      o_type
           lbr     listcatg1           ; loop back for reset of name
listcatg2: sep     scall               ; display cr/lf
           dw      o_inmsg
           db      10,13,0
           lbr     listcatlp           ; loop back for more entries
listcatdn: sep     scall               ; close the directory
           dw      o_close
           lbr     o_wrmboot           ; and return to Elf/OS

chklbr:    mov     rf,dskbuffer+12     ; point to filename
chklbr1:   lda     rf                  ; retrieve byte from name
           lbz     chklbrno            ; not lbr if terminator found
           smi     '.'                 ; check for .
           lbnz    chklbr1             ; jump if not
           dec     rf                  ; change . to terminator
           ldi     0
           str     rf
           inc     rf
           lda     rf                  ; must have lbr extension
           smi     'l'
           lbnz    chklbrno
           lda     rf
           smi     'b'
           lbnz    chklbrno
           lda     rf
           smi     'r'
           lbnz    chklbrno
           ldi     1                   ; mark as being a library
           shr
           sep     sret                ; and return
chklbrno:  ldi     0                   ; mark as non-library
           shr 
           sep     sret                ; return to caller

library:   db      '/hlp/hlp.lbr',0
errmsg:    db      'File not found',10,13,0
cat:       dw      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
catdir:    db      '/hlp/'
catfile:   dw      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
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

