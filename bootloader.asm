%define paragraphs(s,c,b) ((s+c)/b)
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
;: = Light Green    (A)
;; = Light Cyan     (B)
;< = Light Red      (C)
;= = Light Magenta  (D)
;> = Light Brown    (E)
;? = White          (F)

    mov ax, 07c0h           ; 4K stack space after the bootloader -- code is running at 0x07c0
    add ax, paragraphs(4096,512,16)             ; (4096 + 512)/16 bytes per paragraph (288 paragraphs)
    mov ss, ax              ; sets up the stack
    mov sp, 4096            ; moves the stack pointer
    
    mov ax, 07c0h           ; set data segment to where we're loaded
    mov ds, ax
    
    call cls                ; clear the screen
    
    mov si, start_text      ; put string position into SI
    call print              ; call print_string routine
    
    hlt
    
    start_text: db "Bum'd OS starting!", 10,10,13,"Loading bootloader v1...", 0
    
cls:
    pusha                   ; back up registers
    mov ah,00h              ; change graphics mode clears screen
    mov al,03h              ; text mode -- 80x25, 16 colours
    int 10h                 ; BIOS interrupt
    popa                    ; restore registers
    ret
        
;Old print subroutine using BIOS interrupts -- use fb_print in main OS
print:
    pusha                   ; back up registers
    mov ah, 0Eh             ; Put 0Eh in ah -- Tells BIOS to print character in AL at INT 10h
    
.repeat:
    lodsb                   ; load a byte from the string in SI to AL
    cmp al, 0               ; if AL == 0...
    je .done                ; jump to done...
    int 10h                 ; else call the BIOS interrupt to print AL...
    jmp .repeat             ; and repeat.
    
.done:
    popa                    ; restore register
    ret                     ; return from CALL
    

    times 510-($-$$) db 0   ; fill the rest of the boot sector with 0s
    dw 0xAA55               ; and add a boot sector signature.