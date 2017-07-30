%define paragraphs(s,c,b) ((s+c)/b)
%define stack_size 0x76d0
%define sectors 2
%define os_size (sectors*512+512)
    BITS 16
    ORG 0
    
;0x000b8000 -- framebuffer address

;;;Memory Map;;;
;00000 - 003ff   IVT
;00400 - 004ff   BDA
;00500 - 0052f   Dangerous Zone (Petch Zone)
;00530 - 07bff   Stack
;07c00 - 07dff   IPL

    jmp short loader
    times 9 db 0
    
    BytesPerSector: dw 512
    SectorsPerCluster: db 1
    ReservedSectors: dw 1
    FATcount: db 2
    MaxDirEntries: dw 224
    TotalSectors: dw 2880
    db 0
    SectorsPerFAT: dw 9
    SectorsPerTrack: dw 18
    NumberOfHeads: dw 2
    dd 0
    dd 0
    dw 0
    BootSignature: db 0x29
    VolumeID: dd 77
    VolumeLabel: db "Bum'dOS   ",0
    FSType: db "FAT12   "

loader:
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
    
    mov [boot_device], dl   ; back up boot device number
    jmp .load_fat
    
;;;Start loading File Allocation Table (FAT)
.load_fat:
    mov ax, 0x07c0          ; address from start of programs
    mov es, ax
    mov ah, 0x02            ; set to read
    mov al, SectorsPerFAT   ; how many sectors to load
    xor ch, ch              ; cylinder 0
    mov cl, (1+ReservedSectors)  ; Load FAT1
    xor dh, dh              ; head 0
    mov bx, 0x0200          ; read data to 512B after start of code
    int 13h
    cmp ah, 0
    je .load_root
    mov si, error_text
    call print
    hlt

;;;Start loading root directory
.load_root:
    xor dx, dx              ; blank dx for division
    mov si, fat_loaded
    call print
    mov al, [FATcount]
    mul word [SectorsPerFAT]
    add al, [ReservedSectors]
    div byte [max_sectors]
    mov ch, ah
    mov cl, al              ; Load after FATs
    
    xor ax, ax
    mov al, ch
    mul byte [max_sectors]
    add ax, word 17
    mul word [BytesPerSector]
    mov bx,ax               ; Load to after BOTH FATs in memory
    
    xor dx, dx              ; blank dx for division
    mov ax, 32
    mul word [MaxDirEntries]
    div word [BytesPerSector] ; number of sectors
    
    xor dh, dh              ; head 0
    mov dl, [boot_device]   ; boot device
    
    mov ah, 0x02
    
    int 13h
    cmp ah, 0
    je .load_OS
    mov si, error_text
    call print
    jmp $
    
    ;start loading OS from disk
.load_OS:
    mov si, root_loaded
    call print
    jmp $
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
    jmp $
    
    boot_device: db 0
    start_text: db "Bum'd OS starting!", 10,10,13,"Bootloader v1 is loaded!", 10,13,0
    load_text: db "Loading OS from disk...",0
    error_text: db "Error loading from disk!",0
    fat_loaded: db 10,13,"FAT loaded.",0
    root_loaded: db 10,13,"Root loaded.",0
    max_sectors: db 17
    
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