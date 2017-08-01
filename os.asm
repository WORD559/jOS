;;%include "bootloader.asm"
;This, when compiled, goes onto the floppy disk. The bootloader must be installed into the boot sector.
    BITS 16    
    ORG 0
;0x000b8000 -- framebuffer address

;;;Colour Codes;;;
;0 = Black
;1 = Blue
;2 = Green
;3 = Cyan
;4 = Red
;5 = Magenta
;6 = Brown
;7 = Light Grey
;8 = Dark Grey
;9 = Light Blue
;: = Light Green    (A)
;; = Light Cyan     (B)
;< = Light Red      (C)
;= = Light Magenta  (D)
;> = Light Brown    (E)
;? = White          (F)

start:
    mov [colour], byte 0x7B
    call cl_cls                ; clear the screen
    
    mov [cursor], word 210
    mov si, splash_text     ; put string position into SI
    call fb_print           ; call print_string routine
    
    jmp $
    
    splash_text: db "==Welcome to Bum'dOS v3.2!==\n\n\F0The only OS you can truly call \F6b\F<u\F>m\F:t\F9i\F1n\F5g\F0.\n\nNow with FAT12 support for files greater than 512 bytes!", 0
    cursor: dw 0x00
    colour: db 0x07
    
cl_cls:; set colour to 0x<B><F>
    pusha                   ; back up registers
    mov bx, 0               ; set cursor to 0
    mov cx, 0xb800          ; set es
    mov es, cx
    mov cl, [colour]
    
.loop:
    mov [es:bx], byte 0x20  ; overwrite character with space
    inc bx                  ; move forward one byte
    mov [es:bx], cl         ; set colour
    inc bx
    cmp bx, 0xFA0           ; if at the end of the framebuffer, end
    je .done                ; otherwise, loop
    jmp .loop
    
.done:
    mov [cursor], word 0
    popa
    ret
    
fb_print:
    pusha                   ; back up registers
    mov cx, 0xb800          ; set es to 0xb800, so 0x000b8000 can be accessed via [es:bx]
    mov es, cx              
    mov bx, [cursor]        ; set bx to the current cursor position
    
.repeat:
    lodsb                   ; get byte from string in SI to AL
    cmp al, 0               ; if it is equal to 0...
    je .done                ; jump to .done
    cmp al, 5ch             ; see if "\" -- escape character
    je .escape
    mov ah, [colour]            ; colour code
    mov [es:bx], ax         ; move ax into framebuffer
    add [cursor], word 2    ; increment cursor to next column
    mov bx, [cursor]        ; move the new cursor value into bx
    jmp .repeat             ; loop
    
.escape:
    lodsb                   ; get next byte
    cmp al, 6Eh             ; see if equal to "n" for newline
    je .newln
    cmp al, 42h             ; see if equal to "B" for background colour
    je .chg_bgcl
    cmp al, 46h             ; see if equal to "F" for foreground colour
    je .chg_fgcl
    jmp .repeat             ; return to main loop
    
.chg_cl:
    push bx
    lodsb                   ; get next byte
    sub al, 0x30            ; turn ascii into number, from 0 to ? (0-F)
    mov bl, [colour]        ; load current colour
    and bl, ch              ; blank selected nibble
    shl al, cl              ; shift al up
    or bl, al               ; put the nibble in
    mov [colour], bl        ; store it back in memory
    pop bx                  ; restore bx
    ret
    
.chg_bgcl:
    push cx                 ; back up cx
    mov cl, 4               ; set shift amount
    mov ch, 00001111b       ; set OR mask
    call .chg_cl            ; change the colours
    pop cx                  ; restore cx
    jmp .repeat
    
.chg_fgcl:
    push cx                 ; back up cx
    mov cl, 0               ; set left shift amount (0, no left shift)
    mov ch, 11110000b       ; set OR mask
    call .chg_cl            ; change the colours
    pop cx                  ; restore cx
    jmp .repeat
    
.newln:
    push ax                 ; back up ax, cx, and dx
    push cx
    push dx
    mov ax, [cursor]        ; move cursor to al
    add ax, word 160        ; go to next line
    mov cx, ax              ; new value of cursor in cx
    
    mov dx, 0               ; clear dx for division
    mov bx, word 160        ; divide by 160
    div bx
    sub cx, dx              ; subtract remainder

    mov [cursor], cx        ; write cursor back to memory
    mov bx, cx              ; put cursor back in bx
    pop dx
    pop cx  
    pop ax
    jmp .repeat             ; return to main loop
    
.done:
    popa                    ; restore registers
    ret                     ; return from call
    
times 2048-($-$$) db 1       ; make bigger than 512 for FAT testing
;times os_size-($-$$) db 0           ; fill the rest of the sector
    

;Old print subroutine using BIOS interrupts -- not really needed anymore
;print:
;    pusha                   ; back up registers
;    mov ah, 0Eh             ; Put 0Eh in ah -- Tells BIOS to print character in AL at INT 10h
;    
;.repeat:
;    lodsb                   ; load a byte from the string in SI to AL
;    cmp al, 0               ; if AL == 0...
;    je .done                ; jump to done...
;    int 10h                 ; else call the BIOS interrupt to print AL...
;    jmp .repeat             ; and repeat.
;    
;.done:
;    popa                    ; restore register
;    ret                     ; return from CALL