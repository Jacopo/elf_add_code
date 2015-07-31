BITS 32

%include "utils.nasm"

section .data
s: db `XXXXXXXX\n`
s_end:

desc_ip: db 'in before_entry: IP: 0x'
desc_ip_end:
desc_argc: db 'in before_entry: argc: 0x'
desc_argc_end:
desc_argv: db 'in before_entry: argv: 0x'
desc_argv_end:
desc_argv0: db 'in before_entry: argv[0]: 0x'
desc_argv0_end:
desc_argv00: db 'in before_entry: argv[0][0:3]: '
desc_argv00_end:

write_errmsg: db `write error\n`
write_errmsg_end:
esp_errmsg: db `initial_esp does not match the actual esp\n`
esp_errmsg_end:



section .text
global before_entry:function
before_entry:

    ; Simple version that does not use initial_esp
    ;mov eax, dword [esp+8]
    ;mov [eax], byte 'Q'
    ;mov [eax+1], byte 0
    ;ret


    extern initial_esp

    ; Let's check that initial_esp matches the one
    ; that we can observe
    mov eax, [initial_esp]
    sub eax, 4 ; Account for our call
    cmp esp, eax
    je .esp_ok
    print esp_errmsg
    mov eax, 252 ; __NR_exit_group
    mov ebx, 20
    int 0x80
    .esp_ok:


    ; OK, let's print stuff from the original stack
    mov eax, [initial_esp]
    mov [s], eax
    dword_to_hex s
    print desc_argc
    print s
    mov eax, [initial_esp]
    add eax, 4
    mov [s], eax
    dword_to_hex s
    print desc_argv
    print s
    mov eax, [initial_esp]
    mov eax, [eax+4]
    mov [s], eax
    dword_to_hex s
    print desc_argv0
    print s
    mov eax, [initial_esp]
    mov eax, [eax+4]
    mov eax, [eax]
    mov [s], eax
    mov [s+4], dword '    '
    print desc_argv00
    print s

    ; Changing argv[0] to "Q"
    mov eax, [initial_esp]
    mov eax, [eax+4]
    mov [eax], byte 'Q'
    mov [eax+1], byte 0


    ; A generic print that uses the data section
    ;call n
    ;n: pop dword [s]
    ;dword_to_hex s
    ;print desc_ip
    ;print s


    ; The helper will take care of restoring registers and jumping to
    ; the original entrypoint
    ret
