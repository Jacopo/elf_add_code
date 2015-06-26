/* Finds the first NOTE program header and turns it into another LOAD header for code. Check what you are discarding with readelf --notes. */

#define NEW_CODE_ADDRESS 0x6660000u /* Code will be loaded at this address */

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


int main(int argc, char *argv[])
{
    if (argc != 3)
        errx(10, "Usage: %s program new_code > out_program", argv[0]);

    off_t original_size, new_code_size;
    uint8_t *elf = read_file(argv[1], &original_size);
    uint8_t *new_code = read_file(argv[2], &new_code_size);

    /* General checks */
    Ehdr *file_header = (Ehdr *) elf;
    check_elf_file_header(file_header);

    V(file_header->e_phoff == sizeof(Ehdr)); /* No surprises in the middle */

    /* Examines the first program header */
    /* Specifies the program headers themeselves */
    Phdr *phdr = (Phdr*) (elf + file_header->e_phoff);
    V(phdr->p_type == PT_PHDR);
    V((phdr->p_flags & PF_W) == 0);
    V(phdr->p_offset >= sizeof(Ehdr));
    V(phdr->p_filesz == (sizeof(Phdr) * file_header->e_phnum));
    V(phdr->p_filesz == phdr->p_memsz);

    /* Let's find the (first) NOTE */
    for (int i = 1; i < file_header->e_phnum; i++) {
        phdr++;
        V(phdr->p_type != PT_PHDR);
        if (phdr->p_type == PT_NOTE)
            break;
    }
    if (phdr->p_type != PT_NOTE)
        errx(1, "There was no NOTE program header!");


    phdr->p_type = PT_LOAD;
    phdr->p_flags = (PF_R | PF_X);
    phdr->p_vaddr = phdr->p_paddr = NEW_CODE_ADDRESS;
    phdr->p_filesz = phdr->p_memsz = new_code_size;
    phdr->p_align = 1; /* Not sure if it matters or not */

    /* Pads to make sure that the code is loaded right at NEW_CODE_ADDRESS */
    V(sysconf(_SC_PAGESIZE) == 4096u);
    unsigned int pad_len = 4096u - (original_size % 4096u) + (NEW_CODE_ADDRESS % 4096u);
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

