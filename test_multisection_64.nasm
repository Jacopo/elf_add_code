BITS 64

%include "utils.nasm"

section .data
a: dq 'AAAA'
s: db `XXXXXXXXXXXXXXXX\n`
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
; Note: it is called as a regular function in test.c, so
; RBP, RBX, and R12-R15 would need to be saved
call n
n: pop qword [s]
qword_to_hex s
print desc_ip
print s

%ifdef PRINT_ORIGINAL_ENTRYPOINT
    extern original_entrypoint
    mov rax, original_entrypoint
    mov [s], rax
    qword_to_hex s
    print desc_origentry
    print s
%endif

mov rax, [a]
ret
