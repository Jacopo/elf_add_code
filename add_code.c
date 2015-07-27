/* Finds the first NOTE program header and turns it into another LOAD header for code. Check what you are discarding with readelf --notes. */

#include <assert.h>
#include <err.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include "utils.h"

#include <elf.h>


#if defined(ADD_CODE_32)
# define Ehdr Elf32_Ehdr
# define Phdr Elf32_Phdr
# define Shdr Elf32_Shdr
static const int ELFCLASS = ELFCLASS32;
#elif defined(ADD_CODE_64)
# define Ehdr Elf64_Ehdr
# define Phdr Elf64_Phdr
# define Shdr Elf64_Shdr
static const int ELFCLASS = ELFCLASS64;
static_assert(sizeof(void*) == 8, "I mangle 64-bit ELFs only as a 64-bit program. This thing is already complicated enough.");
#else
#error "Do you want to mangle 32-bit or 64-bit ELF files?"
#endif


static void check_elf_file_header(const Ehdr *file_header)
{
    int i;
    V((file_header->e_ident[0] == 0x7f) && (file_header->e_ident[1] == 'E') && (file_header->e_ident[2] == 'L') && (file_header->e_ident[3] == 'F'));
    V(file_header->e_ident[EI_CLASS] == ELFCLASS);
    V(file_header->e_ident[EI_DATA] == ELFDATA2LSB);
    V(file_header->e_ident[EI_VERSION] == EV_CURRENT);
    for (i = EI_PAD; i < EI_NIDENT; ++i)
        V(file_header->e_ident[i] == 0);
    V((file_header->e_type == ET_EXEC) || (file_header->e_type == ET_DYN));
    V(file_header->e_version == 1); /* EV_CURRENT */
    V(file_header->e_ehsize == sizeof(Ehdr));
    V(file_header->e_phentsize == sizeof(Phdr));
    V(file_header->e_phnum >= 1);
    V(file_header->e_shentsize == sizeof(Shdr));

    /* These depend on the architecture / version / etc. */
    // V(file_header->e_ident[EI_OSABI] == ELFOSABI_NONE);
    // V(file_header->e_machine == EM_386);
    // V(file_header->e_flags == 0);
}


static void single_load_from_elf(uint8_t **p_new_code, size_t *p_new_code_size, unsigned long *p_new_code_vaddr)
{
    uint8_t *file_start = *p_new_code;
    Ehdr *file_header = (Ehdr *) file_start;
    check_elf_file_header(file_header);
    V(file_header->e_type == ET_EXEC); // TODO: PIE

    uint8_t *new_code = malloc(100); // So that we can realloc()
    size_t size = 0;
    unsigned long base = 0;

    Phdr *phdr = (Phdr*) (file_start + file_header->e_phoff);
    for (int i = 0; i < file_header->e_phnum; i++, phdr++) {
        if (phdr->p_type == PT_NOTE)
            continue; /* No need to warn */
        if (phdr->p_type != PT_LOAD) {
            fprintf(stderr, "WARNING: Ignoring non-load program header %d/%d, type %d\n",
                    i+1, file_header->e_phnum, phdr->p_type);
            continue;
        }

        V(phdr->p_vaddr == phdr->p_paddr);
        V(phdr->p_vaddr > (base + size));
        size_t misalignment = phdr->p_vaddr % 4096;
        V((phdr->p_offset % 4096) == misalignment);

        if (base == 0) {
            base = phdr->p_vaddr;
            V(misalignment == 0); // TODO: not sure how to behave in that case
        } else {
            size_t diff = phdr->p_vaddr - (base + size);
            fprintf(stderr, " Zero-padding from 0x%lx to 0x%lx\n",
                    (unsigned long) base + size, (unsigned long) phdr->p_vaddr);
            new_code = realloc(new_code, size + diff); VE(new_code != NULL);
            memset(new_code + size, 0, diff);
            size += diff;
        }

        fprintf(stderr, "Load from 0x%lx to 0x%lx (from file 0x%lx to 0x%lx)\n",
                base + size, base + size + phdr->p_memsz,
                (unsigned long) phdr->p_offset, (unsigned long) phdr->p_offset + phdr->p_filesz);
        new_code = realloc(new_code, size + phdr->p_memsz); VE(new_code != NULL);
        memcpy(new_code + size, file_start + phdr->p_offset, phdr->p_filesz);
        size_t extra_load_size = phdr->p_memsz - phdr->p_filesz;
        if (extra_load_size)
            memset(new_code + size + phdr->p_filesz, 0, extra_load_size);
        size += phdr->p_memsz;
    }

    fprintf(stderr, "New stuff will be loaded from 0x%lx to 0x%lx\n",
            base, base+size);
    fprintf(stderr, "Note: the entry point for the ELF we added was 0x%lx\n", (unsigned long) file_header->e_entry);

    *p_new_code = new_code;
    *p_new_code_size = size;
    *p_new_code_vaddr = base;
    free((void*) file_header);
}


int main(int argc, char *argv[])
{
    if (argc != 3 && argc != 4)
        errx(10, "Usage: %s program new_code [new_code_vaddr=0x06660000] > out_program", argv[0]);

    unsigned long new_code_vaddr = 0x06660000u;
    static_assert(sizeof(unsigned long) == sizeof(void*), ""); /* Unclean, but good and simple */
    if (argc == 4)
        new_code_vaddr = explicit_hex_conv(argv[3]);

    size_t original_size, new_code_size;
    uint8_t *elf = read_file(argv[1], &original_size);
    uint8_t *new_code = read_file(argv[2], &new_code_size);

    /* Can also add an elf file, if requested, attempting a segment merge. */
    if (*((uint32_t*) new_code) == 0x464C457f) // \x7fELF
        single_load_from_elf(&new_code, &new_code_size, &new_code_vaddr);

    /* General checks */
    Ehdr *file_header = (Ehdr *) elf;
    check_elf_file_header(file_header);

    V(file_header->e_phoff == sizeof(Ehdr)); /* No surprises in the middle */
    Phdr *phdr = (Phdr*) (elf + file_header->e_phoff);

    /* Let's find the (first) NOTE */
    Phdr* note_phdr = 0;
    for (int i = 0; i < file_header->e_phnum; i++, phdr++) {
        if (phdr->p_type == PT_NOTE)
            note_phdr = phdr;
        if (phdr->p_type == PT_PHDR) {
            /* This guy specifies the program headers themselves */
            /* I'm not sure why it exists, but let's do some consistency checks */
            V(i == 0);
            V((phdr->p_flags & PF_W) == 0);
            V(phdr->p_offset >= sizeof(Ehdr));
            V(phdr->p_filesz == (sizeof(Phdr) * file_header->e_phnum));
            V(phdr->p_filesz == phdr->p_memsz);
        }
        if (phdr->p_type == PT_LOAD)
            V(overlap(phdr->p_vaddr, phdr->p_vaddr+phdr->p_memsz, new_code_vaddr, new_code_vaddr+new_code_size) == false);
    }
    phdr = note_phdr;
    if (phdr->p_type != PT_NOTE)
        errx(1, "There was no NOTE program header!");


    phdr->p_type = PT_LOAD;
    phdr->p_flags = (PF_R | PF_W | PF_X);
    phdr->p_vaddr = phdr->p_paddr = new_code_vaddr;
    phdr->p_filesz = phdr->p_memsz = new_code_size;
    phdr->p_align = 1; /* Not sure if it matters or not */

    /* Pads to make sure that the code is loaded right at new_code_vaddr */
    V(sysconf(_SC_PAGESIZE) == 4096u);
    unsigned long pad_len = 4096u - (original_size % 4096u) + (new_code_vaddr % 4096u);
    phdr->p_offset = original_size + pad_len;

    do_write(1, elf, original_size);
    if (pad_len) {
        uint8_t *pad = (uint8_t*) calloc(1, pad_len);
        VE(pad != NULL);
        do_write(1, pad, pad_len);
    }
    do_write(1, new_code, new_code_size);
    return 0;
}

