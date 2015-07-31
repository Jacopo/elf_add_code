BITS 64

; Helps isolating your code from the original program, restoring the
; original stack, registers, and flags when before_entry returns.
;
; Your code is called with the same stack as on program start, so you
; can read argv & co. It may not be 16-byte aligned, though, so SSE 
; instructions may not like it.
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
    initial_ %+ %1: resq 1
%endmacro
%macro initial_segment_selector 1
    global initial_ %+ %1:data
    initial_ %+ %1: resw 1
%endmacro

initial_reg rsp
initial_reg rbp
initial_reg rax
initial_reg rbx
initial_reg rcx
initial_reg rdx
initial_reg rsi
initial_reg rdi
initial_reg r8
initial_reg r9
initial_reg r10
initial_reg r11
initial_reg r12
initial_reg r13
initial_reg r14
initial_reg r15
initial_reg rflags
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
    mov [initial_rsp], rsp
    mov [initial_rbp], rbp
    mov [initial_rax], rax
    mov [initial_rbx], rbx
    mov [initial_rcx], rcx
    mov [initial_rdx], rdx
    mov [initial_rsi], rsi
    mov [initial_rdi], rdi
    mov [initial_r8 ], r8
    mov [initial_r9 ], r9
    mov [initial_r10], r10
    mov [initial_r11], r11
    mov [initial_r12], r12
    mov [initial_r13], r13
    mov [initial_r14], r14
    mov [initial_r15], r15
    pushf
    pop qword [initial_rflags]
    mov word [initial_ss], ss
    mov word [initial_ds], ds
    mov word [initial_es], es
    mov word [initial_fs], fs
    mov word [initial_gs], gs

    call before_entry

    mov rsp, [initial_rsp]
    mov rbp, [initial_rbp]
    mov rax, [initial_rax]
    mov rbx, [initial_rbx]
    mov rcx, [initial_rcx]
    mov rdx, [initial_rdx]
    mov rsi, [initial_rsi]
    mov rdi, [initial_rdi]
    mov r8 , [initial_r8 ]
    mov r9 , [initial_r9 ]
    mov r10, [initial_r10]
    mov r11, [initial_r11]
    mov r12, [initial_r12]
    mov r13, [initial_r13]
    mov r14, [initial_r14]
    mov r15, [initial_r15]
    push qword [initial_rflags]
    popf
    mov ss, word [initial_ss]
    mov ds, word [initial_ds]
    mov es, word [initial_es]
    mov fs, word [initial_fs]
    mov gs, word [initial_gs]

    jmp original_entrypoint
