BITS 32

; Helps isolating your code from the original program, restoring the
; original stack, registers, and flags when before_entry returns.
;
; Your code is called with the same stack as on program start, (plus
; the saved instruction pointer) so you can read argv & co. It may not
; be 16-byte aligned, though, so SSE instructions may not like it.
;
; You can also access the initial registers as initial_xxx.
;
; Note: the used stack portion is not zeroed back, so the program
;       could detect changes based on that. One would need to know
;       how much before_entry used to properly clean it back.
;       (Also, CS is not checked.)


section .bss
%macro initial_reg 1
    global initial_ %+ %1:data
    initial_ %+ %1: resd 1
%endmacro
%macro initial_segment_selector 1
    global initial_ %+ %1:data
    initial_ %+ %1: resw 1
%endmacro

initial_reg esp
initial_reg ebp
initial_reg eax
initial_reg ebx
initial_reg ecx
initial_reg edx
initial_reg esi
initial_reg edi
initial_reg eflags
initial_segment_selector ss
initial_segment_selector ds
initial_segment_selector es
initial_segment_selector fs
initial_segment_selector gs



section .text
extern original_entrypoint
extern before_entry
global _start:function

_start:
    mov [initial_esp], esp
    mov [initial_ebp], ebp
    mov [initial_eax], eax
    mov [initial_ebx], ebx
    mov [initial_ecx], ecx
    mov [initial_edx], edx
    mov [initial_esi], esi
    mov [initial_edi], edi
    pushf
    pop dword [initial_eflags]
    mov word [initial_ss], ss
    mov word [initial_ds], ds
    mov word [initial_es], es
    mov word [initial_fs], fs
    mov word [initial_gs], gs

    call before_entry

    mov esp, [initial_esp]
    mov ebp, [initial_ebp]
    mov eax, [initial_eax]
    mov ebx, [initial_ebx]
    mov ecx, [initial_ecx]
    mov edx, [initial_edx]
    mov esi, [initial_esi]
    mov edi, [initial_edi]
    push dword [initial_eflags]
    popf
    mov ss, word [initial_ss]
    mov ds, word [initial_ds]
    mov es, word [initial_es]
    mov fs, word [initial_fs]
    mov gs, word [initial_gs]

    jmp original_entrypoint
