%define paragraphs(s,c,b) ((s+c)/b)
%define stack_size 0x76d0
%define os_size 1024
    BITS 16
    
;0x000b8000 -- framebuffer address

;;;Memory Map;;;
;00000 - 003ff   IVT
;00400 - 004ff   BDA
;00500 - 0052f   Dangerous Zone (Petch Zone)
;00530 - 07bff   Stack
;07c00 - 07dff   IPL

    mov ax, 0x0053          ; set ss to 0x0053 -- start of free space
    mov ss, ax              ; Interrupts are disabled for the next instruction.
    mov sp, stack_size      ; sets up the stack pointer in the free space
    
    mov ax, 07c0h           ; set data segment to where we're loaded
    mov ds, ax
    
    call cls                ; clear the screen
    
    mov si, start_text      ; put string position into SI
    call print              ; call print_string routine
    
    hlt
    
    start_text: db "Bum'd OS starting!", 10,10,13,"Bootloader v1 is loaded!", 0
    
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