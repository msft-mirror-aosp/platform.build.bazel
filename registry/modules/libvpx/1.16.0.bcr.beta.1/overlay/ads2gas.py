#!/usr/bin/env python3
"""Translates ARM Developer Suite (ADS) assembly syntax to GNU Assembler (GAS) format.

This script parses ARM assembly source files (.asm) written in ADS/RVDS style
and performs a series of regex transformations to rewrite them into GNU as (.S)
syntax. It replaces the original perl scripts (ads2gas.pl and thumb.pm) in the
libvpx Bazel build workflow.
"""

import sys
import re
import argparse
from typing import List


def fix_thumb_instructions(line: str) -> str:
    """Applies syntax adjustments specifically required for Thumb/Thumb-2 instructions.

    Replaces registers, instructions, writebacks, and address offsets to match
    GNU as expectations for Thumb-2 mode.
    """
    # Write additions with shifts, such as "add r10, r11, lsl #8",
    # in three operand form, "add r10, r10, r11, lsl #8".
    line = re.sub(r"(add\s+)(r\d+),\s*(r\d+),\s*(lsl #\d+)", r"\1\2, \2, \3, \4", line)

    # Convert additions with a non-constant shift into a sequence
    # with left shift, addition and a right shift (to restore the
    # register to the original value).
    # "add r12, r12, r5, lsl r4" -> "lsl r5, r4", "add r12, r12, r5", "lsr r5, r4"
    line = re.sub(
        r"^(\s*)(add)(\s+)(r\d+),\s*(r\d+),\s*(r\d+),\s*lsl (r\d+)",
        r"\1lsl\3\6, \7\n\1\2\3\4, \5, \6\n\1lsr\3\6, \7",
        line,
    )

    # Convert loads with right shifts in the indexing into a sequence of add, load and sub.
    # "ldrb r4, [r9, lr, asr #1]" -> "add r9, r9, lr, asr #1", "ldrb r4, [r9]", "sub r9, r9, lr, asr #1"
    line = re.sub(
        r"^(\s*)(ldrb)(\s+)(r\d+),\s*\[(\w+),\s*(\w+),\s*(asr #\d+)\]",
        r"\1add \3\5, \5, \6, \7\n\1\2\3\4, [\5]\n\1sub \3\5, \5, \6, \7",
        line,
    )

    # Convert register indexing with writeback into a separate add instruction.
    # "ldrb r12, [r1, r2]!" -> "ldrb r12, [r1, r2]", "add r1, r1, r2"
    line = re.sub(
        r"^(\s*)(ldrb)(\s+)(r\d+),\s*\[(\w+),\s*(\w+)\]!",
        r"\1\2\3\4, [\5, \6]\n\1add \3\5, \6",
        line,
    )

    # Convert negative register indexing into separate sub/add instructions.
    # "ldrne r4, [src, -pstep, lsl #1]" -> "subne src, src, pstep, lsl #1", "ldrne r4, [src]", "addne src, src, pstep, lsl #1"
    line = re.sub(
        r"^(\s*)((ldr|str|pld)(ne)?)(\s+)(r\d+,\s*)?\[(\w+), -([^\]]+)\]",
        r"\1sub\4\5\7, \7, \8\n\1\2\5\6[\7]\n\1add\4\5\7, \7, \8",
        line,
    )

    # Convert register post indexing to a separate add instruction.
    # "ldrneb r9, [r0], r2" -> "ldrneb r9, [r0]", "addne r0, r0, r2"
    line = re.sub(
        r"^(\s*)((ldr|str)(ne)?[bhd]?)(\s+)(\w+),(\s*\w+,)?\s*\[(\w+)\],\s*(\w+)",
        r"\1\2\5\6,\7 [\8]\n\1add\4\5\8, \8, \9",
        line,
    )

    # Convert "mov pc, lr" into "bx lr", since the former only works for switching
    # from ARM to Thumb in ARMv7, but "bx lr" is universally supported.
    line = re.sub(r"mov(\s*)pc\s*,\s*lr", r"bx\1lr", line)
    return line


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert ADS/ARM assembly syntax to GAS."
    )
    parser.add_argument("--out", required=True, help="Destination GAS output file (.S)")
    parser.add_argument(
        "--src", required=True, help="Source ADS input assembly file (.asm)"
    )
    parser.add_argument(
        "--config-include",
        required=True,
        help="Prefix relative path to rewrite vpx_config.asm include",
    )
    parser.add_argument(
        "--thumb", action="store_true", help="Compile for Thumb/Thumb-2 mode"
    )
    parser.add_argument(
        "--noelf",
        action="store_true",
        help="Disable ELF assembly directives (e.g. size/type)",
    )
    args, unknown = parser.parse_known_args()

    thumb = args.thumb
    elf = not args.noelf

    output_lines: List[str] = []
    output_lines.append("@ This file was created from a .asm file\n")
    output_lines.append("@  using the ads2gas.py script.\n")
    output_lines.append(".syntax unified\n")
    if thumb:
        output_lines.append("\t.thumb\n")

    proc_stack: List[str] = []

    with open(args.src, "r", encoding="utf-8") as f:
        stdin_iter = iter(f.readlines())

    for line in stdin_iter:
        line = line.rstrip("\r\n")

        # Load and store alignment: in ADS alignment uses @, in GAS it uses ,:
        # e.g., vld1.8 {d0}, [r0@64] -> vld1.8 {d0}, [r0,:64]
        line = line.replace("@", ",:")

        # Convert comments: in ADS comments start with ;, in GAS they start with @
        line = re.sub(r";", "@", line, count=1)

        # Convert ELSE -> .else
        line = re.sub(r"\bELSE\b", ".else", line)

        # Convert ENDIF -> .endif
        line = re.sub(r"\bENDIF\b", ".endif", line)

        # Convert IF -> .if, and convert single = to == for comparisons
        if re.search(r"\bIF\b", line):
            line = re.sub(r"\bIF\b", ".if", line)
            line = re.sub(r"=+", "==", line)

        # Convert INCLUDE -> .include "file"
        line = re.sub(r"INCLUDE\s*(.*)$", r'.include "\1"', line)

        # Convert AREA statements: replace AREA alignment with p2align
        line = re.sub(
            r"^(\s*)\bAREA\b.*ALIGN=([0-9])$", r"\1.text\n\1.p2align \2", line
        )
        # If no explicit alignment, default to aligning to 4 bytes
        line = re.sub(r"^(\s*)\bAREA\b.*$", r"\1.text\n\1.p2align 2", line)

        # Export/global functions: make function visible to the linker
        if elf:
            line = re.sub(
                r"(\s*)EXPORT\s+\|([\$\w]*)\|",
                r"\1.global \2\n\1.type \2, function",
                line,
            )
        else:
            line = re.sub(r"(\s*)EXPORT\s+\|([\$\w]*)\|", r"\1.global \2", line)

        # Remove vertical bars on function names
        line = re.sub(r"^\|(\$?\w+)\|", r"\1", line)

        # Append colons to labels at the start of lines, except EQU definitions
        if "EQU" not in line:
            line = re.sub(r"^([a-zA-Z_0-9\$]+)", r"\1:", line)

        # ALIGN directive -> .balign
        line = re.sub(r"\bALIGN\b", ".balign", line)

        # Set arm vs thumb mode
        if thumb:
            line = re.sub(r"\bARM\b", "", line)
        else:
            line = re.sub(r"\bARM\b", ".arm", line)

        # push/pop -> stmdb/ldmia block memory operations
        line = re.sub(r"(push\s+)(r\d+)", r"stmdb sp!, {\2}", line)
        line = re.sub(r"(pop\s+)(r\d+)", r"ldmia sp!, {\2}", line)

        if thumb:
            line = fix_thumb_instructions(line)

        if elf:
            # EABI attributes: require and preserve 8-byte stack alignment
            line = re.sub(
                r"\bREQUIRE8\b", ".eabi_attribute 24, 1 @Tag_ABI_align_needed", line
            )
            line = re.sub(
                r"\bPRESERVE8\b", ".eabi_attribute 25, 1 @Tag_ABI_align_preserved", line
            )
        else:
            line = re.sub(r"\bREQUIRE8\b", "", line)
            line = re.sub(r"\bPRESERVE8\b", "", line)

        # PROC/ENDP: Track function size to populate ELF debug symbols correctly
        if re.search(r"\bPROC\b", line):
            m = re.match(r"^([\.0-9A-Z_a-z]\w+)\b", line)
            proc = m.group(1) if m else None
            if proc:
                proc_stack.append(proc)
            line = re.sub(r"\bPROC\b", "@ PROC", line)

        if re.search(r"\bENDP\b", line):
            line = re.sub(r"\bENDP\b", "@ ENDP", line)
            if proc_stack:
                proc = proc_stack.pop()
                if elf:
                    line = f".size {proc}, .-{proc}\n" + line

        # EQU -> .equ
        line = re.sub(r"(\S+\s+)EQU(\s+\S+)", r".equ \1, \2", line)

        # Macros: replace MACRO header block with GNU .macro and parameters
        if re.search(r"\bMACRO\b", line):
            try:
                next_line = next(stdin_iter).rstrip("\r\n")
                line = next_line
                line = ".macro " + line
                line = line.replace("$", "")
            except StopIteration:
                pass

        # Variables: in GAS parameters are referenced using \param instead of $param
        line = line.replace("$", "\\")

        # End macro -> .endm
        line = re.sub(r"\bMEND\b", ".endm", line)

        if re.match(r"^\s*END\s*$", line):
            continue

        line = line.rstrip(" \t")
        output_lines.append(line + "\n")

    if elf:
        # Mark stack as non-executable for ELF binaries
        output_lines.append('    .section .note.GNU-stack,"",%%progbits\n')

    # Re-route the local vpx_config.asm include to the correct relative path prefix
    replacement = '.include "' + args.config_include + 'vpx_config.asm"'
    content = "".join(output_lines)
    content = re.sub(r'\.include "\./vpx_config\.asm"', replacement, content)

    with open(args.out, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    main()
