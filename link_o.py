#!/usr/bin/env python2.7

LD = "ld"
OBJDUMP = "objdump"
NM = "nm"
ALIGN = 0x200000

import re
from collections import defaultdict
from subprocess import *

def get_syms(original_program):
    syms = {}
    t = check_output([NM,"--defined-only","-a","--synthetic",original_program])
    for l in t.splitlines():
        fields = l.split()
        if len(fields) == 2: continue # Nameless (filename) symbol
        val, t, name = fields

        if t == 'a': # Filename (repeated, useless)
            continue

        val = int(re.match(r'[0-9a-fA-F]+$',val).group(), 16)

        name = name.replace('.','_DOT_')
        name = name.replace('@','_AT_')
        name = name.replace('-','_DASH_')
        assert re.match('\w+$', name)

        name = "original_"+name
        if name in syms:
            # Omit duplicated symbols
            # TODO: What to do with them? What do they mean?
            del syms[name]
        else: syms[name] = val
    return syms

def get_section_sizes(obj):
    size = {}
    t = check_output([OBJDUMP,'-h',obj])
    for l in t.splitlines():
        m = re.match(r'\s*[0-9]+\s+(\S+)\s+([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+[0-9a-fA-F]+\s+', l)
        if not m: continue
        size[m.group(1)] = int(m.group(2),16)
    return size


def align_addr(addr):
    return (addr + ALIGN - 1) & ~(ALIGN - 1)


def link_o(objects, original_program, out, start_address):
    header = check_output([OBJDUMP,"-f",original_program])
    arch = re.search(r"architecture: ([^,]+)", header).group(1)

    emul = None
    if arch == 'i386': # TODO: necessary on other archs?
        emul = 'elf_i386'

    entry = int(re.search(r'start address 0x([0-9a-fA-F]+)', header).group(1), 16)

    syms = get_syms(original_program)
    syms["original_entrypoint"] = entry

    section_start = {}
    section_size = defaultdict(int)
    for o in objects:
        for name,size in get_section_sizes(o).iteritems():
            section_size[name] += size
    cur = start_address
    for name,size in section_size.iteritems():
        cur += size
        cur = align_addr(cur)
        section_start[name] = cur

 
    cmd = [ LD,"-nostdlib","--fatal-warnings","--gc-sections","-o",out ]
    if emul: cmd.extend(["-m",emul])
    for sym,val in syms.iteritems():
        cmd.append("--defsym={}={}".format(sym,hex(val)))
    for name,addr in section_start.iteritems():
        cmd.append("--section-start={}={}".format(name,hex(addr)))
    cmd.append("--start-group")
    cmd.extend(objects)
    cmd.append("--end-group")
    return cmd

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--original-program", required=True, help="Get the symbols from this guy")
    parser.add_argument("-o", "--out", required=True, help="Output file name")
    parser.add_argument("--start-address", default=0x16660000, help="Your sections will be loaded starting at that address (format: 0xaddr)")
    parser.add_argument("objects", nargs="+")
    args = parser.parse_args()

    assert args.start_address[:2] == '0x'
    args.start_address = int(args.start_address[2:], 16)
    
    cmd = link_o(**vars(args))
    check_call(cmd)
