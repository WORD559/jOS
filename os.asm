    BITS 16
    
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
;: = Light Green
;; = Light Cyan
;< = Light Red
;= = Light Magenta
;> = Light Brown
;? = White

start:
    mov ax, 07c0h           ; 4K stack space after the bootloader -- code is running at 0x07c0
    add ax, 288             ; (4098 + 512)/16 bytes per paragraph
    mov ss, ax              ; sets up the stack
    mov sp, 4096            ; moves the stack pointer
    
    mov ax, 07c0h           ; set data segment to where we're loaded
    mov ds, ax
    
    call cls                ; clear the screen
    
    mov si, splash_text     ; put string position into SI
    call fb_print           ; call print_string routine
    
    jmp $
    
    text db "w", 0
    splash_text: db "\B?Welcome to Bum'dOS v1\nThe only time you can truly say an OS is bumting.", 0
    cursor: dw 0x00
    colour: db 0x07
    
cls:
    pusha                   ; back up registers
    mov ah,00h              ; change graphics mode clears screen
    mov al,03h              ; text mode -- 80x25, 16 colours
    int 10h                 ; BIOS interrupt
    popa                    ; restore registers
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
    jmp .repeat             ; return to main loop
    
.chg_bgcl:
    push bx
    lodsb                   ; get next byte
    sub al, 0x30            ; turn ascii into number, from 0 to ? (0-F)
    mov bl, [colour]        ; load current colour
    and bl, 00001111b       ; blank background nibble
    shl al, 4               ; shift al up
    or bl, al               ; put the background nibble in
    mov [colour], bl        ; store it back in memory
    pop bx                  ; restore bx
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
    

    times 510-($-$$) db 0   ; fill the rest of the boot sector with 0s
    dw 0xAA55               ; and add a boot sector signature.