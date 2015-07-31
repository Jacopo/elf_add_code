
%if __BITS__ == 32

; printlen x  =>  write(1, x, x_end-x)
%macro print 1
    mov eax, 4 ; __NR_write
    mov ebx, 1
    mov ecx, %1
    mov edx, %1 %+ _end - %1
    int 0x80
    cmp eax, %1 %+ _end - %1
    je %%ok
    mov eax, 4
    mov ebx, 1
    mov ecx, write_errmsg
    mov edx, write_errmsg_end-write_errmsg
    int 0x80
%%ok:
%endmacro

%macro al_to_hex 1
    mov ah, al
    and al, 0x0f ; low nibble
    cmp al, 10
    jb %%oknum
    add al, byte 39 ; 'a'-'0'-10
    %%oknum: add al, byte '0'
    mov [%1+1], al
    shr ah, 4    ; high nibble
    cmp ah, 10
    jb %%oknumh
    add ah, byte 39 ; 'a'-'0'-10
    %%oknumh: add ah, byte '0'
    mov [%1], ah
%endmacro

%macro dword_to_hex 1
    mov ecx, [%1] ; ecx = dword
    mov eax, ecx
    shr eax, 24
    al_to_hex %1
    mov eax, ecx
    shr eax, 16
    al_to_hex %1+2
    mov eax, ecx
    shr eax, 8
    al_to_hex %1+4
    mov eax, ecx
    al_to_hex %1+6
%endmacro


%elif __BITS__ == 64

%macro print 1
    mov rax, 1 ; __NR_write
    mov rdi, 1
    mov rsi, %1
    mov rdx, %1 %+ _end - %1
    syscall
    cmp rax, %1 %+ _end - %1
    je %%ok
    mov rax, 1
    mov rdi, 1
    mov rsi, write_errmsg
    mov rdx, write_errmsg_end - write_errmsg
    syscall
%%ok:
%endmacro


%macro al_to_hex 1
    mov ah, al
    and al, 0x0f ; low nibble
    cmp al, 10
    jb %%oknum
    add al, byte 39 ; 'a'-'0'-10
    %%oknum: add al, byte '0'
    mov [%1+1], al
    shr ah, 4    ; high nibble
    cmp ah, 10
    jb %%oknumh
    add ah, byte 39 ; 'a'-'0'-10
    %%oknumh: add ah, byte '0'
    mov [%1], ah
%endmacro

%macro qword_to_hex 1
    mov rcx, [%1] ; rcx = dword
    mov rax, rcx
    shr rax, 56
    al_to_hex %1
    mov rax, rcx
    shr rax, 48
    al_to_hex %1+2
    mov rax, rcx
    shr rax, 40
    al_to_hex %1+4
    mov rax, rcx
    shr rax, 32
    al_to_hex %1+6
    mov rax, rcx
    shr rax, 24
    al_to_hex %1+8
    mov rax, rcx
    shr rax, 16
    al_to_hex %1+10
    mov rax, rcx
    shr rax, 8
    al_to_hex %1+12
    mov rax, rcx
    al_to_hex %1+14
%endmacro

%endif ; __BITS__
