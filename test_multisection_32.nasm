BITS 32

section .data
a: dd 'AAAA'
s: db `XXXXXXXX\n`
s_end:

desc_ip: db 'in new code: IP: 0x'
desc_ip_end:
desc_origentry: db 'in new code: original entry point: 0x'
desc_origentry_end:

errmsg: db `write error\n`
errmsg_end:

%macro PRINT 2
    mov eax, 4 ; __NR_write
    mov ebx, 1
    mov ecx, %1
    mov edx, %2
    int 0x80
    cmp eax, %2
    je %%ok
    mov eax, 4
    mov ebx, 1
    mov ecx, errmsg
    mov edx, errmsg_end-errmsg
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


section .text
global _start:function
_start:
; Note: it is called as a regular function in test.c
pusha

call n
n: pop dword [s]
dword_to_hex s
PRINT desc_ip, desc_ip_end-desc_ip
PRINT s, s_end-s

%ifdef PRINT_ORIGINAL_ENTRYPOINT
    extern original_entrypoint
    mov eax, original_entrypoint
    mov [s], eax
    dword_to_hex s
    PRINT desc_origentry, desc_origentry_end-desc_origentry
    PRINT s, s_end-s
%endif

popa
mov eax, [a]
ret
