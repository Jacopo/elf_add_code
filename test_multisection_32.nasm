BITS 32

section .data
a: dd 'AAAA'

section .text
global _start:function
_start:
mov eax, [a]
call n
n: pop ecx

ret
