    BITS 16
start:
    mov ax, 07c0h           ; 4K stack space after the bootloader
    add ax, 288             ; (4098 + 512)/16 bytes per paragraph
    mov ss, ax
    mov sp, 4096
    
    mov ax, 07c0h           ; set data segment to where we're loaded
    mov ds, ax
    
    call cls                ; clear the screen
    
    mov si, text_string     ; put string position into SI
    call print_string       ; call print_string routine
    
    jmp $
    
    text_string db "Welcome to Bum'dOS v1", 0
    
cls:
    mov ah,00h              ; change graphics mode clears screen
    mov al,03h              ; text mode -- 80x25, 16 colours
    int 10h                 ; BIOS interrupt
    ret

print_string:
    mov ah, 0Eh             ; Put 0Eh in ah -- Tells BIOS to print character in AL at INT 10h
    
.repeat:
    lodsb                   ; load a byte from the string in SI to AL
    cmp al, 0               ; if AL == 0...
    je .done                ; jump to done...
    int 10h                 ; else call the BIOS interrupt to print AL...
    jmp .repeat             ; and repeat.
    
.done:
    ret                     ; return from CALL
    

    times 510-($-$$) db 0   ; fill the rest of the boot sector with 0s
    dw 0xAA55               ; and add a boot sector signature.