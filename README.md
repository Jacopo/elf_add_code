Astonishingly flexible code injection into an ELF executable. Helps you write as little as possible to intercept the entry point.

Use `add_code_32` to manipulate and ELF32 file, `add_code_64` for ELF64.


Adding raw assembly code
------------------------

    nasm -fbin -o new_code_bin new_code.nasm
    add_code_xx original_program new_code_bin [new_code_vaddr=0x06660000] > modified_program


Adding a full ELF executable
----------------------------

(Don't use this mode directly, it's mainly a helper for the next one.)

    gcc -nostdlib -static -Wl,-Ttext=0x066000000 -Wl,-Tdata=0x066200000 -Wl,-Tbss=0x066400000 -Wl,--build-id=none -o exec_to_add something.c
    add_code_xx program exec_to_add > out_program
    
The program's LOAD commands ("segments") will be merged into a single one. Its load address is determined by what is in `exec_to_add`, so make sure there is no overlap. Check with `readelf -l`.



Linking in an ELF object / replacing the entry point
----------------------------------------------------

    gcc -nostdlib -static -Wl,--build-id=none -o xxx.o -c xxx.c
    add_code_xx [--before-entry] program xxx.o [new_code_vaddr=0x06660000] > out_program

Will take care of linking xxx.o. You will be able to use `extern uintptr_t original_entrypoint` to refer to stuff in the main program.

**Entrypoint replacement helper:** Write a `before_entry` function and specify `--before-entry`.
A helper function will be linked in and will replace the program's entry point. It saves the initial registers (access them as `initial_eax`, `initial_ebx`, ...), calls your function, restores the initial registers, and jumps to `original_entrypoint`.



Limitations, TODOs
------------------

 - Replaces the NOTE program header. Should extend it to manipulate existing LOAD headers in case NOTE is missing or cannot be removed.
 - No PIE handling. Not very problematic, at the moment, since current PIEs are always dynamic at the moment due to limitations of libc loaders (musl is working on making static PIE possible, though).
 - Just exposes `original_entrypoint`. Should find a way to expose all original symbols.
 - Can handle a single object file. Use `ld -r` to combine multiple ones if necessary.
 - Tested on x86 and x64 only.


Note: Always `make check` :)
