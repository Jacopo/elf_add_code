/* Finds the first NOTE program header and turns it into another LOAD header for code. Check what you are discarding with readelf --notes. */

#include <assert.h>
#include <err.h>
#include <inttypes.h>
#include <libgen.h>
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

#define info(args...) fprintf(stderr, "[INFO] " args)
#define warning(args...) fprintf(stderr, "\n*WARNING*: " args)

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


static unsigned long exec_to_bin(uint8_t **p_new_code, size_t *p_new_code_size, unsigned long *p_new_code_vaddr)
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
        if (phdr->p_type == PT_GNU_STACK) {
            info("Ignoring the PT_GNU_STACK program header, your code will inherit the original program's one\n");
            continue;
        }
        if (phdr->p_type != PT_LOAD) {
            warning("Ignoring non-load program header %d/%d, type 0x%x\n",
                    i+1, file_header->e_phnum, phdr->p_type);
            continue;
        }

        if (phdr->p_vaddr == 0)
            errx(1, "ERROR: your code is asking to be loaded starting from address 0. MOST LIKELY, THE BINARY WOULD NOT LOAD, due to vm.mmap_min_addr. Note that ld aligns segments, so your load address should be higher than the alignment mask used by ld. (Also, my code does not handle it :()\n");
        else if (phdr->p_vaddr <= (base + size))
            errx(1, "ERROR: The PT_LOAD headers are out of order: PT_LOAD header %d/%d has a smaller vaddr than last one's end (0x%lx <= 0x%lx).",
                    i+1, file_header->e_phnum, (unsigned long) phdr->p_vaddr, base + size);

        V(phdr->p_vaddr == phdr->p_paddr);
        size_t misalignment = phdr->p_vaddr % 4096;
        V((phdr->p_offset % 4096) == misalignment);

        if (base == 0) {
            base = phdr->p_vaddr;
            V(misalignment == 0); // TODO: not sure how to behave in that case
        } else {
            size_t diff = phdr->p_vaddr - (base + size);
            info("0x%lx -> 0x%lx Zero-padding\n",
                    (unsigned long) base + size, (unsigned long) phdr->p_vaddr);
            new_code = realloc(new_code, size + diff); VE(new_code != NULL);
            memset(new_code + size, 0, diff);
            size += diff;
        }

        info("0x%lx -> 0x%lx Load from file 0x%lx to 0x%lx\n",
                base + size, base + size + phdr->p_memsz,
                (unsigned long) phdr->p_offset, (unsigned long) phdr->p_offset + phdr->p_filesz);
        new_code = realloc(new_code, size + phdr->p_memsz); VE(new_code != NULL);
        memcpy(new_code + size, file_start + phdr->p_offset, phdr->p_filesz);
        size_t extra_load_size = phdr->p_memsz - phdr->p_filesz;
        if (extra_load_size)
            memset(new_code + size + phdr->p_filesz, 0, extra_load_size);
        size += phdr->p_memsz;
    }

    unsigned long added_code_entry = (unsigned long) file_header->e_entry;
    info("New stuff will be loaded from 0x%lx to 0x%lx\n",
            base, base+size);
    info("The entry point for the ELF we added was 0x%lx\n", added_code_entry);

    *p_new_code = new_code;
    *p_new_code_size = size;
    *p_new_code_vaddr = base;
    free((void*) file_header);
    return added_code_entry;
}

static char* link_obj(const char *objname, unsigned long original_entrypoint, unsigned long requested_vaddr, bool before_entry)
{
    unsigned long vtext = requested_vaddr;
    unsigned long vdata = vtext + 0x200000; // TODO: get these from the object file
    unsigned long vbss =  vdata + 0x200000;
    char exec_filename[255] = "/tmp/add_elf_code_XXXXXX";
    V(mkdtemp(exec_filename) != NULL);
    strcat(exec_filename, "/exec_to_add");

    const char *helperquotedname = "";
    if (before_entry) {
#if defined(ADD_CODE_32)
        helperquotedname = "\"entry_helper_32.o\"";
#elif defined(ADD_CODE_64)
        helperquotedname = "\"entry_helper_64.o\"";
#endif
    }

    char ld_cmdline[500];
    const char *m_opt = "";
#if defined(ADD_CODE_32) && (defined(__i386__) || defined(__x86_64__))
    m_opt = "-m elf_i386";
#endif
    info("Symbol original_entrypoint=0x%lx should be available to the new code.\n", original_entrypoint);
    int cmdlen = snprintf(ld_cmdline, sizeof(ld_cmdline),
            "ld -nostdlib -Ttext=0x%lx -Tdata=0x%lx -Tbss=0x%lx --gc-sections %s "
            "--defsym=original_entrypoint=0x%lx --fatal-warnings -o \"%s\" "
            "--start-group \"%s\" %s --end-group 1>&2",
            vtext, vdata, vbss, m_opt, original_entrypoint, exec_filename, objname, helperquotedname);
    VS(cmdlen); V(cmdlen < ((int) sizeof(ld_cmdline)));
    info("Running: %s\n", ld_cmdline);
    V(system(ld_cmdline) == 0);

    return strdup(exec_filename);
}

int main(int argc, char *argv[])
{
    if (argc != 3 && argc != 4 && argc != 5)
        errx(10, "Usage: %s [--before-entry] program new_code [new_code_vaddr=0x06660000] > out_program", argv[0]);

    int argbase = 0; // XXX: yeah, yeah

    bool before_entry = false;
    if (strcmp(argv[1], "--before-entry") == 0) {
        before_entry = true;
        argbase++;
    }

    unsigned long new_code_vaddr = 0x06660000u;
    static_assert(sizeof(unsigned long) == sizeof(void*), ""); /* Unclean, but good and simple */
    if (argc == (4+argbase))
        new_code_vaddr = explicit_hex_conv(argv[3+argbase]);

    size_t original_size, new_code_size;
    uint8_t *elf = read_file(argv[1+argbase], &original_size);
    uint8_t *new_code = read_file(argv[2+argbase], &new_code_size);

    if (before_entry && ((Ehdr*) new_code)->e_type != ET_REL)
        errx(1, "You need to pass an object file to take advantage of the entry point replacement helper.");

    /* Can also add an elf file, if requested, attempting a segment merge.
     * If using an object file, it will link it, also making original_entrypoint available to it as a symbol. */
    unsigned long new_code_entry = 0;
    if (*((uint32_t*) new_code) == 0x464C457f) { // \x7fELF
        if (((Ehdr*) new_code)->e_type == ET_EXEC) {
            exec_to_bin(&new_code, &new_code_size, &new_code_vaddr);
        } else if (((Ehdr*) new_code)->e_type == ET_REL) {
            char *execname = link_obj(argv[2+argbase], ((const Ehdr*) elf)->e_entry, new_code_vaddr, before_entry);
            free(new_code);
            new_code = read_file(execname, &new_code_size);
            char *tmpdir = dirname(execname);
            char rm_cmdline[500];
            int cmdlen = snprintf(rm_cmdline, sizeof(rm_cmdline), "rm -rf \"%s\"", tmpdir);
            VS(cmdlen); V(cmdlen < ((int) sizeof(rm_cmdline)));
            system(rm_cmdline);
            new_code_entry = exec_to_bin(&new_code, &new_code_size, &new_code_vaddr);
        } else errx(1, "Can't handle PIE (or whatever that was)");
    }

    /* General checks */
    Ehdr *file_header = (Ehdr *) elf;
    check_elf_file_header(file_header);

    V(file_header->e_phoff == sizeof(Ehdr)); /* No surprises in the middle */
    Phdr *phdr = (Phdr*) (elf + file_header->e_phoff);

    /* Let's find the (first) NOTE */
    Phdr* note_phdr = NULL;
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
        if (phdr->p_type == PT_LOAD) {
            V(overlap(phdr->p_vaddr, phdr->p_vaddr+phdr->p_memsz, new_code_vaddr, new_code_vaddr+new_code_size) == false);

            /* PT_LOAD headers should be ordered by vaddr */
            if ((note_phdr == NULL) && (phdr->p_vaddr > new_code_vaddr)) /* PT_LOAD before ours, but larger vaddr */
                warning("PT_LOAD header %d/%d comes before the NOTE one, but has a larger vaddr than your code's (0x%lx > 0x%lx). With PT_LOAD headers out of order THE NEW FILE MAY NOT LOAD.\n", i+1, file_header->e_phnum, (unsigned long) phdr->p_vaddr, new_code_vaddr);
            if ((note_phdr != NULL) && (phdr->p_vaddr < new_code_vaddr)) /* PT_LOAD after ours, but smaller vaddr */
                warning("PT_LOAD header %d/%d comes after the NOTE one, but has a smaller vaddr than your code's (0x%lx < 0x%lx). With PT_LOAD headers out of order THE NEW FILE MAY NOT LOAD.\n", i+1, file_header->e_phnum, (unsigned long) phdr->p_vaddr, new_code_vaddr);
        }
    }
    phdr = note_phdr;
    if (phdr->p_type != PT_NOTE)
        errx(1, "There was no NOTE program header!");


    phdr->p_type = PT_LOAD;
    phdr->p_flags = (PF_R | PF_W | PF_X);
    phdr->p_vaddr = phdr->p_paddr = new_code_vaddr;
    phdr->p_filesz = phdr->p_memsz = new_code_size;
    phdr->p_align = 1; /* Not sure if it matters or not */

    /* If requested, change the entry point */
    if (before_entry)
        file_header->e_entry = new_code_entry;

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

