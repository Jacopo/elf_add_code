BITS 64

global before_entry:function
before_entry:
    ; Simple version that does not use initial_rsp
    ;mov rax, qword [rsp+16] ; char *rax = argv[0]

    extern initial_rsp
    mov rax, [initial_rsp]
    mov rax, [rax+8]


    mov [rax], byte 'Q'
    mov [rax+1], byte 0
    ret
