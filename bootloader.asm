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
    
    ;call cls                ; clear the screen
    
    ;mov si, start_text      ; put string position into SI
    ;call print              ; call print_string routine
    ;mov si, load_text
    ;call print
    
    mov [boot_device], dl   ; back up boot device number
    jmp .load_fat
    
;;;Start loading File Allocation Table (FAT)
.load_fat:
    mov ax, 0x07c0          ; address from start of programs
    mov es, ax
    mov al, [SectorsPerFAT] ; how many sectors to load
    mul byte [FATcount]     ; load both FATs
    mov dx, ax
    push dx
    xor dx, dx              ; blank dx for division
    mov ax, 32
    mul word [MaxDirEntries]
    div word [BytesPerSector] ; number of sectors for root directory
    pop dx
    add ax, dx              ; add root directory length and FATs length -- load all three at once
    xor dh,dh
    mov dl, [boot_device]
    
    xor ch, ch              ; cylinder 0
    mov cl, [ReservedSectors]  ; Load from after boot sector
    add cl, byte 1
    xor dh, dh              ; head 0
    mov bx, 0x0200          ; read data to 512B after start of code
    mov ah, 0x02            ; set to read
    int 13h
    cmp ah, 0
    je .find_OS
    mov si, error_text
    call print
    hlt

;;;Start loading OS from root directory
.find_OS:
    xor dx, dx              ; blank dx for division
    mov si, fat_loaded
    call print
    mov al, [SectorsPerFAT] ; calculate memory offset of root directory
    mul byte [FATcount]
    mul word [BytesPerSector]
    add ax, word 0x200
    mov bx, ax              ; bx contains start of root dir
    mov cx, filename
    xor dx, dx
    
.check_filename:
    inc dx
    pusha
    mov bx, ax
    mov ax, [bx]
    mov bx, cx
    mov cx, [bx]
    cmp ax, cx
    popa
    jne .no_match
    cmp dx, 10
    je .found
    inc ax
    inc cx
    jmp .check_filename

.no_match:
    xor dx, dx
    add bx, word 32
    mov cx, filename
    mov ax, bx
    jmp .check_filename
    
.found:
    mov [file_loc], bx
    jmp .load_OS
    
.jump_OS:
    mov ax, 0xbe0
    mov ds, ax
    push 0xbe00
    ret
    
.load_OS:
    mov ax, 0
    mov es, ax
    mov ax, ds
    mov fs, ax
    add bx, word 28
    cmp [fs:bx], word 512
    mov bx, [file_loc]
    add bx, 26
    xor cx, cx
    mov cl, [fs:bx]
    call .read_multi_segment
    ;call .read_segment
    jmp .jump_OS
    
.read_multi_segment:
    call .read_segment
    mov cl, [FAT_seg]
    add cl, byte 1
    mov bx, 0x200
    add bl, cl
    mov cl, byte [fs:bx]
    cmp cx, 0xFF
    jne .read_multi_segment
    ret
    
.read_segment:
    mov [FAT_seg], cl
    add cl, byte 31
    call LBA_to_CHS
    mov dl, [boot_device]
    mov bx, [read_addr]
    add [read_addr], word 0x200
    mov ah, 2
    mov al, 1
    int 13h
    cmp ah, 0
    je .return
    mov si, error_text
    call print
    jmp $
    .return: ret
    
;;DATA HERE
    boot_device: db 0
    ;start_text: db "Bootloader v1", 10,13,0
    ;load_text: db "Loading OS...",0
    error_text: db "Err",0
    fat_loaded: db 10,13,"FATs + root loaded.",0
    filename: db "OS      BIN"
    file_loc: dw 0
    FAT_seg: dw 0
    read_addr: dw 0xBE00
;;END OF DATA
    
LBA_to_CHS: ; store LBA in cl
    mov [lba], cl           ; store LBA value
    ;;Calculate cylinder
    ;C = LBA / (HPC*SPT)
    mov ax, [NumberOfHeads]
    mul word [SectorsPerTrack]
    mov [temp],ax
    xor ax, ax
    mov al, [lba]
    div word [temp]
    mov [cyl], al
    xor ax, ax
    xor dx, dx
    
    ;;Calculate head
    ;H = (LBA / SPT) mod HPC
    mov al, [lba]
    div word [SectorsPerTrack]
    xor dx, dx
    div word [NumberOfHeads]
    mov [head], dx
    xor ax, ax
    xor dx, dx
    
    ;;Calculate sector
    ;S = (LBA mod SPT) + 1
    mov al, [lba]
    div word [SectorsPerTrack]
    add dx, word 1
    
    ;;Store the values
    ;mov cl, al              ; sector
    ;mov ch, [cyl]           ; cylinder
    xor cx, cx
    mov cl, [cyl]
    shl cl, 6
    or cl, dl
    xor dx, dx
    mov dh, [head]          ; head
    
    mov dh, 1
    ;mov ch, 0
    ret
    
    
.data:
    lba: db 0
    cyl: db 0
    head: db 0
    temp: dw 0

    
;cls:
;    pusha                   ; back up registers
;    mov ah,00h              ; change graphics mode clears screen
;    mov al,03h              ; text mode -- 80x25, 16 colours
;    int 10h                 ; BIOS interrupt
;    popa                    ; restore registers
;    ret
        
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