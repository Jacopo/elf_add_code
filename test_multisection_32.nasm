BITS 32

%include "utils.nasm"

section .data
a: dd 'AAAA'
s: db `XXXXXXXX\n`
s_end:

desc_ip: db 'in new code: IP: 0x'
desc_ip_end:
desc_origentry: db 'in new code: original entry point: 0x'
desc_origentry_end:
write_errmsg: db `write error\n`
write_errmsg_end:


section .text
global _start:function
_start:
; Note: it is called as a regular function in test.c
pusha

call n
n: pop dword [s]
dword_to_hex s
print desc_ip
print s

%ifdef PRINT_ORIGINAL_ENTRYPOINT
    extern original_entrypoint
    mov eax, original_entrypoint
    mov [s], eax
    dword_to_hex s
    print desc_origentry
    print s
%endif

popa
mov eax, [a]
ret
