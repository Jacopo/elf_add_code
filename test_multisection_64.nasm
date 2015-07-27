BITS 64

section .data
a: dq 'AAAA'

; Believe it or not, this code is "amphibious": same decoding in 32-bit and
; 64-bit mode, and the same behavior (well, uses the entire rcx, obviously)
section .text
global _start:function
_start:
mov rax, qword [a]
call n
n: pop rcx

ret
