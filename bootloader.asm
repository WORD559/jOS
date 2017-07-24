%define paragraphs(s,c,b) ((s+c)/b)
%define stack_size 0x76d0
%define sectors 2
%define os_size (sectors*512+512)
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
    mov si, load_text
    call print
    ;start loading OS from disk
    mov [boot_device], dl   ; back up boot device number
    
    mov ax, 0x07c0          ; address from start of programs
    mov es, ax
    mov ah, 0x02            ; set to read
    mov al, sectors         ; how many sectors to load
    xor ch, ch              ; set cylinder to 0
    mov cl, 2               ; load from sector 2
    xor dh, dh              ; head 0 (dh) and boot device
    mov bx, 0x0200          ; where to read data to
    int 13h                 ; BIOS interrupt to read data
    
    ;Error checking
    cmp ah, 0
    je 0x0200
    mov si, error_text
    call print
    cmp ah, 0x20
    jne stop
    mov si, ctrl_error
    call print
    
    stop: hlt
    
    boot_device: db 0
    start_text: db "Bum'd OS starting!", 10,10,13,"Bootloader v1 is loaded!", 10,13,0
    load_text: db "Loading OS from disk...",0
    error_text: db "Error loading from disk!",0
    ctrl_error: db 10,13,"Controller error!",0
    
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