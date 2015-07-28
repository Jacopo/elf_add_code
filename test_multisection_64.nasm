BITS 64

section .data
a: dq 'AAAA'
s: db `XXXXXXXXXXXXXXXX\n`
%define S_LEN 17

desc_ip: db 'in new code: IP: 0x'
desc_ip_end:
desc_origentry: db 'in new code: original entry point: 0x'
desc_origentry_end:

errmsg: db `write error\n`
%define ERRMSG_LEN 12


%macro PRINT 2
    mov rax, 1 ; __NR_write
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall
    cmp rax, %2
    je %%ok
    mov rax, 1
    mov rdi, 1
    mov rsi, errmsg
    mov rdx, ERRMSG_LEN
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


section .text
global _start:function
_start:
; Note: it is called as a regular function in test.c, so
; RBP, RBX, and R12-R15 would need to be saved
call n
n: pop qword [s]
qword_to_hex s
PRINT desc_ip, desc_ip_end-desc_ip
PRINT s, S_LEN

%ifdef PRINT_ORIGINAL_ENTRYPOINT
    extern original_entrypoint
    mov rax, original_entrypoint
    mov [s], rax
    qword_to_hex s
    PRINT desc_origentry, desc_origentry_end-desc_origentry
    PRINT s, S_LEN
%endif

mov rax, [a]
ret
