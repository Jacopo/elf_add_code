BITS 64

; Believe it or not, this code is "amphibious": same decoding in 32-bit and
; 64-bit mode, and the same behavior (well, uses the entire rcx, obviously)

mov eax, 'AAAA'
xor eax, eax

call n
n: pop rcx

ret
